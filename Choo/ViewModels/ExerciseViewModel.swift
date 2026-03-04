import Foundation

@Observable
final class ExerciseViewModel {
    let firestoreService: FirestoreService
    let claudeService: ClaudeAPIService
    let familyId: String
    let userId: String
    let displayName: String

    var selectedDayIndex: Int?
    var showingCategoryForm = false
    var briefingHeadline = "Your exercise week"
    var briefingSummary = ""
    var isLoadingBriefing = false
    var errorMessage: String?
    var expandedCategoryId: String?

    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var lastSlotHash: Int = 0
    @ObservationIgnored private var hasLoadedInitially = false
    @ObservationIgnored private let debounceDuration: UInt64 = 3_000_000_000

    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }()

    init(firestoreService: FirestoreService, claudeService: ClaudeAPIService, familyId: String, userId: String, displayName: String) {
        self.firestoreService = firestoreService
        self.claudeService = claudeService
        self.familyId = familyId
        self.userId = userId
        self.displayName = displayName
        loadCachedBriefing()
    }

    // MARK: - Week Computation

    var weekStart: Date {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: Date()) else {
            return Date()
        }
        return calendar.startOfDay(for: interval.start)
    }

    var weekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: weekStart) }
    }

    var todayIndex: Int? {
        weekDays.firstIndex(where: { calendar.isDateInToday($0) })
    }

    var weekDateRange: String {
        let startDay = calendar.component(.day, from: weekStart)
        let endDate = weekDays.last ?? weekStart
        return "\(startDay)–\(Self.endDateFormatter.string(from: endDate))"
    }

    func dayAbbreviation(for date: Date) -> String {
        Self.abbrevFormatter.string(from: date)
    }

    func dayNumber(for date: Date) -> String {
        Self.dayNumFormatter.string(from: date)
    }

    func isToday(_ date: Date) -> Bool {
        calendar.isDateInToday(date)
    }

    func isPast(_ date: Date) -> Bool {
        calendar.startOfDay(for: date) < calendar.startOfDay(for: Date())
    }

    // MARK: - Data Access

    var categories: [ExerciseCategory] {
        firestoreService.exerciseCategories
    }

    var currentPlan: ExercisePlan? {
        firestoreService.currentExercisePlan
    }

    var slots: [String: ExerciseSlotAssignment] {
        currentPlan?.slots ?? [:]
    }

    var restDays: [Int] {
        currentPlan?.restDays ?? []
    }

    func sessionsForDay(_ dayIndex: Int) -> [(timeSlot: TimeSlot, assignment: ExerciseSlotAssignment)] {
        TimeSlot.allCases.compactMap { slot in
            let key = slotKey(day: dayIndex, timeSlot: slot)
            guard let assignment = slots[key] else { return nil }
            return (timeSlot: slot, assignment: assignment)
        }
    }

    var sessionCount: Int {
        slots.count
    }

    var categoryCount: Int {
        categories.count
    }

    var restDayCount: Int {
        restDays.count
    }

    func slotKey(day: Int, timeSlot: TimeSlot) -> String {
        "\(day)_\(timeSlot.rawValue)"
    }

    // MARK: - Today Hero

    var todayNextSession: (timeSlot: TimeSlot, assignment: ExerciseSlotAssignment)? {
        guard let idx = todayIndex else { return nil }
        let sessions = sessionsForDay(idx)
        guard !sessions.isEmpty else { return nil }

        let hour = calendar.component(.hour, from: Date())
        if hour < 12 {
            return sessions.first
        } else if hour < 15 {
            return sessions.first(where: { $0.timeSlot == .lunch || $0.timeSlot == .arvo }) ?? sessions.last
        } else {
            return sessions.first(where: { $0.timeSlot == .arvo }) ?? sessions.last
        }
    }

    var isTodayRestDay: Bool {
        guard let idx = todayIndex else { return false }
        return restDays.contains(idx)
    }

    // MARK: - Load

    func load() async {
        guard !hasLoadedInitially else { return }
        firestoreService.listenToExerciseCategories(familyId: familyId, userId: userId)
        firestoreService.listenToExercisePlan(familyId: familyId, userId: userId, weekStart: weekStart)

        do {
            try await firestoreService.seedDefaultExerciseCategories(familyId: familyId, userId: userId)
        } catch {
            errorMessage = error.localizedDescription
        }

        // Set first category expanded once categories arrive
        if expandedCategoryId == nil, let first = categories.first {
            expandedCategoryId = first.id
        }

        await generateBriefing()
        lastSlotHash = slots.hashValue
        hasLoadedInitially = true
    }

    // MARK: - Plan Mutations

    func assignSession(dayIndex: Int, timeSlot: TimeSlot, sessionType: SessionType, category: ExerciseCategory) async {
        var updatedSlots = slots
        let key = slotKey(day: dayIndex, timeSlot: timeSlot)
        updatedSlots[key] = ExerciseSlotAssignment(
            sessionTypeId: sessionType.id,
            sessionTypeName: sessionType.name,
            categoryName: category.name,
            categoryEmoji: category.emoji,
            categoryColorHex: category.colorHex,
            durationMinutes: sessionType.durationMinutes,
            estimatedCalories: sessionType.estimatedCalories,
            intensity: sessionType.intensity
        )

        var updatedRestDays = restDays
        updatedRestDays.removeAll { $0 == dayIndex }

        let plan = ExercisePlan(
            userId: userId,
            weekStart: weekStart,
            slots: updatedSlots,
            restDays: updatedRestDays
        )

        do {
            try await firestoreService.saveExercisePlan(familyId: familyId, userId: userId, plan: plan)
            debounceBriefingRegeneration()
        } catch {
            errorMessage = error.localizedDescription
        }

        selectedDayIndex = nil
    }

    func clearSlot(dayIndex: Int, timeSlot: TimeSlot) async {
        var updatedSlots = slots
        let key = slotKey(day: dayIndex, timeSlot: timeSlot)
        updatedSlots.removeValue(forKey: key)

        let plan = ExercisePlan(
            userId: userId,
            weekStart: weekStart,
            slots: updatedSlots,
            restDays: restDays
        )

        do {
            try await firestoreService.saveExercisePlan(familyId: familyId, userId: userId, plan: plan)
            debounceBriefingRegeneration()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleRestDay(_ dayIndex: Int) async {
        var updatedRestDays = restDays
        var updatedSlots = slots

        if updatedRestDays.contains(dayIndex) {
            updatedRestDays.removeAll { $0 == dayIndex }
        } else {
            updatedRestDays.append(dayIndex)
            // Clear that day's slots
            for timeSlot in TimeSlot.allCases {
                let key = slotKey(day: dayIndex, timeSlot: timeSlot)
                updatedSlots.removeValue(forKey: key)
            }
        }

        let plan = ExercisePlan(
            userId: userId,
            weekStart: weekStart,
            slots: updatedSlots,
            restDays: updatedRestDays
        )

        do {
            try await firestoreService.saveExercisePlan(familyId: familyId, userId: userId, plan: plan)
            debounceBriefingRegeneration()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Category CRUD

    func addCategory(name: String, emoji: String, colorHex: String) async {
        let nextOrder = (categories.map(\.sortOrder).max() ?? -1) + 1
        let category = ExerciseCategory(
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            sortOrder: nextOrder,
            isDefault: false,
            sessionTypes: []
        )

        do {
            try await firestoreService.saveExerciseCategory(familyId: familyId, userId: userId, category: category)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCategory(_ category: ExerciseCategory) async {
        guard let catId = category.id else { return }
        do {
            try await firestoreService.deleteExerciseCategory(familyId: familyId, userId: userId, categoryId: catId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addSessionType(to category: ExerciseCategory, name: String, description: String, durationMinutes: Int? = nil, estimatedCalories: Int? = nil, intensity: String? = nil) async {
        var updated = category
        let newType = SessionType(id: UUID().uuidString, name: name, description: description, durationMinutes: durationMinutes, estimatedCalories: estimatedCalories, intensity: intensity)
        updated.sessionTypes.append(newType)

        do {
            try await firestoreService.saveExerciseCategory(familyId: familyId, userId: userId, category: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateSessionType(in category: ExerciseCategory, typeId: String, name: String, description: String, durationMinutes: Int? = nil, estimatedCalories: Int? = nil, intensity: String? = nil) async {
        var updated = category
        guard let idx = updated.sessionTypes.firstIndex(where: { $0.id == typeId }) else { return }
        updated.sessionTypes[idx].name = name
        updated.sessionTypes[idx].description = description
        updated.sessionTypes[idx].durationMinutes = durationMinutes
        updated.sessionTypes[idx].estimatedCalories = estimatedCalories
        updated.sessionTypes[idx].intensity = intensity

        do {
            try await firestoreService.saveExerciseCategory(familyId: familyId, userId: userId, category: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteSessionType(from category: ExerciseCategory, typeId: String) async {
        var updated = category
        updated.sessionTypes.removeAll { $0.id == typeId }

        do {
            try await firestoreService.saveExerciseCategory(familyId: familyId, userId: userId, category: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Schedule count for category

    func scheduledCount(for category: ExerciseCategory) -> Int {
        slots.values.filter { $0.categoryName == category.name }.count
    }

    func scheduledCount(for sessionType: SessionType) -> Int {
        slots.values.filter { $0.sessionTypeId == sessionType.id }.count
    }

    // MARK: - AI Briefing

    private func generateBriefing() async {
        // Check cache
        let weekString = Self.weekFormatter.string(from: weekStart)
        let dayString = Self.dayFormatter.string(from: Date())
        let cacheKey = "ExerciseBriefing.\(userId).\(weekString)_\(dayString)"

        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(ExerciseBriefing.self, from: data) {
            briefingHeadline = cached.headline
            briefingSummary = cached.summary
            return
        }

        isLoadingBriefing = true
        defer { isLoadingBriefing = false }

        let sessionList = buildSessionListForPrompt()

        let totalSessions = sessionCount
        let totalRest = restDayCount
        let prompt = """
        You are a supportive, thoughtful exercise companion — like a kind friend who genuinely cares about someone's wellbeing, not a drill sergeant. Given this week's exercise schedule, write:

        1. HEADLINE: A short, warm headline (4-8 words) capturing the week's feel. Use a line break (\\n) to split into two short lines. No quotes. Be genuine, not rah-rah motivational.
           Examples:
           - "Swim and stretch —\\na balanced week"
           - "Easy does it\\nrecovery week"
           - "Building strength —\\none day at a time"
           - "Rest is training too —\\ngood call"

        2. SUMMARY: One short sentence referencing actual session names. Be supportive and honest. Under 120 characters.
           - If well balanced (mix of cardio, strength, flexibility, rest): affirm the variety. "Yoga and weights — your body will thank you for the mix."
           - If heavy/intense (6-7 sessions, lots of high intensity): gently flag it. "That's a big week — make sure you're listening to your body."
           - If rest-heavy or light: be encouraging, not judgmental. "Sometimes less is more. A solid foundation to build from."
           - If one-dimensional (all the same type): suggest variety warmly. "All running — maybe a stretch session could balance things out?"
           - Reference the actual session names, not generic terms.

        Important tone notes:
        - Be warm and real, like a friend checking in
        - It's OK to gently suggest more rest or variety — caring honesty, not toxic positivity
        - Never use clichés like "crush it", "beast mode", "let's go", "you've got this"
        - If \(totalSessions) sessions are planned with only \(totalRest) rest day(s), note the load
        - Notice day load patterns (Peak days should have recovery nearby, multiple Peak days in a row is a flag)
        - Notice category balance (all cardio = suggest flexibility, all flexibility = suggest some intensity)
        - If nothing is planned yet, be gentle and encouraging about starting

        Respond in exactly this format:
        HEADLINE: <headline>
        SUMMARY: <summary>

        This week's exercise plan (\(totalSessions) sessions, \(totalRest) rest days):
        \(sessionList.isEmpty ? "No sessions planned yet." : sessionList)
        """

        do {
            let text = try await claudeService.callClaudeRaw(prompt: prompt, maxTokens: 200)
            var parsedHeadline = "Your exercise week"
            var parsedSummary = ""

            for line in text.components(separatedBy: "\n") {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("HEADLINE:") {
                    parsedHeadline = String(trimmed.dropFirst(9)).trimmingCharacters(in: .whitespaces)
                    parsedHeadline = parsedHeadline.replacingOccurrences(of: "\\n", with: "\n")
                } else if trimmed.hasPrefix("SUMMARY:") {
                    parsedSummary = String(trimmed.dropFirst(8)).trimmingCharacters(in: .whitespaces)
                }
            }

            briefingHeadline = parsedHeadline
            briefingSummary = parsedSummary

            // Cache
            let briefing = ExerciseBriefing(weekStart: weekStart, headline: parsedHeadline, summary: parsedSummary)
            if let encoded = try? JSONEncoder().encode(briefing) {
                UserDefaults.standard.set(encoded, forKey: cacheKey)
            }
        } catch {
            briefingHeadline = "Your exercise week"
            briefingSummary = sessionCount > 0 ? "\(sessionCount) session\(sessionCount == 1 ? "" : "s") planned this week." : "No sessions planned yet."
        }
    }

    private func debounceBriefingRegeneration() {
        guard hasLoadedInitially else { return }
        debounceTask?.cancel()
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: debounceDuration)
                guard !Task.isCancelled else { return }
                // Invalidate cache for this week
                let weekString = Self.weekFormatter.string(from: weekStart)
                let dayString = Self.dayFormatter.string(from: Date())
                let cacheKey = "ExerciseBriefing.\(userId).\(weekString)_\(dayString)"
                UserDefaults.standard.removeObject(forKey: cacheKey)
                await generateBriefing()
            } catch {
                // Cancelled
            }
        }
    }

    private func buildSessionListForPrompt() -> String {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        var lines: [String] = []

        for dayIndex in 0..<7 {
            if restDays.contains(dayIndex) {
                lines.append("• \(dayNames[dayIndex]): Rest day")
                continue
            }
            let sessions = sessionsForDay(dayIndex)
            if sessions.isEmpty { continue }
            let sessionDescs = sessions.map { s -> String in
                var desc = "\(s.assignment.sessionTypeName) (\(s.assignment.categoryName), \(s.timeSlot.label)"
                if let dur = s.assignment.durationMinutes { desc += ", \(dur)min" }
                if let cal = s.assignment.estimatedCalories { desc += ", ~\(cal)cal" }
                desc += ")"
                return desc
            }
            let totalCal = sessions.compactMap(\.assignment.estimatedCalories).reduce(0, +)
            let loadStr = totalCal > 0 ? " [Day load: \(DayLoad.from(totalCalories: totalCal).displayName), ~\(totalCal) cal]" : ""
            lines.append("• \(dayNames[dayIndex]): \(sessionDescs.joined(separator: ", "))\(loadStr)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Cache

    private func loadCachedBriefing() {
        let weekString = Self.weekFormatter.string(from: weekStart)
        let dayString = Self.dayFormatter.string(from: Date())
        let cacheKey = "ExerciseBriefing.\(userId).\(weekString)_\(dayString)"

        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(ExerciseBriefing.self, from: data) else { return }
        briefingHeadline = cached.headline
        briefingSummary = cached.summary
    }

    // MARK: - Formatters

    @ObservationIgnored
    private static let weekFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-'W'ww"
        return f
    }()

    @ObservationIgnored
    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    @ObservationIgnored
    private static let endDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d MMM"
        return f
    }()

    @ObservationIgnored
    private static let abbrevFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    @ObservationIgnored
    private static let dayNumFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "d"
        return f
    }()
}
