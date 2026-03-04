import Foundation

@Observable
final class ChoresViewModel {
    let firestoreService: FirestoreService
    let claudeService: ClaudeAPIService
    let familyId: String
    let displayName: String

    var selectedDayIndex: Int?
    var showingCategoryForm = false
    var briefingHeadline = "Your chores week"
    var briefingSummary = ""
    var isLoadingBriefing = false
    var errorMessage: String?
    var expandedCategoryId: String?

    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var hasLoadedInitially = false
    @ObservationIgnored private let debounceDuration: UInt64 = 3_000_000_000

    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2
        return cal
    }()

    init(firestoreService: FirestoreService, claudeService: ClaudeAPIService, familyId: String, displayName: String) {
        self.firestoreService = firestoreService
        self.claudeService = claudeService
        self.familyId = familyId
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
        return "\(startDay)\u{2013}\(Self.endDateFormatter.string(from: endDate))"
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

    var categories: [ChoreCategory] {
        firestoreService.choreCategories
    }

    var currentPlan: ChoresPlan? {
        firestoreService.currentChoresPlan
    }

    var slots: [String: ChoreSlotAssignment] {
        currentPlan?.slots ?? [:]
    }

    /// Dynamic assignees from actual family members + dependents (excluding pets) + "Family".
    var availableAssignees: [ChoreAssignee] {
        var result: [ChoreAssignee] = []
        let palette = ChoreAssignee.palette

        // App users (e.g. Tony, Alex)
        for (i, member) in firestoreService.familyMembers.enumerated() {
            let color = palette[i % palette.count]
            result.append(ChoreAssignee(
                id: member.id ?? member.displayName,
                displayName: member.displayName,
                emoji: "\u{1F464}",
                colorHex: color
            ))
        }

        // Dependents (kids, not pets)
        let nonPets = firestoreService.dependents.filter { $0.type == .person }
        for (j, dep) in nonPets.enumerated() {
            let color = palette[(result.count + j) % palette.count]
            result.append(ChoreAssignee(
                id: dep.id ?? dep.displayName,
                displayName: dep.displayName,
                emoji: dep.emoji ?? "\u{1F9D2}",
                colorHex: color
            ))
        }

        // "Family" catch-all
        result.append(.family)
        return result
    }

    /// Look up an assignee by ID (for display purposes).
    func assignee(for id: String) -> ChoreAssignee? {
        availableAssignees.first(where: { $0.id == id })
    }

    func choresForDay(_ dayIndex: Int) -> [ChoreSlotAssignment] {
        slots.filter { key, _ in
            key.hasPrefix("\(dayIndex)_")
        }
        .map(\.value)
    }

    var choreCount: Int {
        slots.count
    }

    var completedCount: Int {
        slots.values.filter(\.isCompleted).count
    }

    var categoryCount: Int {
        categories.count
    }

    var totalDurationMinutes: Int {
        slots.values.compactMap(\.durationMinutes).reduce(0, +)
    }

    func slotKey(day: Int, choreTypeId: String) -> String {
        "\(day)_\(choreTypeId)"
    }

    // MARK: - Today Hero

    var todayChores: [ChoreSlotAssignment] {
        guard let idx = todayIndex else { return [] }
        return choresForDay(idx)
    }

    var todayNextChore: ChoreSlotAssignment? {
        todayChores.first(where: { !$0.isCompleted }) ?? todayChores.first
    }

    // MARK: - Load

    func load() async {
        guard !hasLoadedInitially else { return }
        firestoreService.listenToChoreCategories(familyId: familyId)
        firestoreService.listenToChoresPlan(familyId: familyId, weekStart: weekStart)

        do {
            try await firestoreService.seedDefaultChoreCategories(familyId: familyId)
        } catch {
            errorMessage = error.localizedDescription
        }

        if expandedCategoryId == nil, let first = categories.first {
            expandedCategoryId = first.id
        }

        await generateBriefing()
        hasLoadedInitially = true
    }

    // MARK: - Plan Mutations

    func assignChore(dayIndex: Int, choreType: ChoreType, category: ChoreCategory, assignedTo: ChoreAssignee) async {
        var updatedSlots = slots
        let key = slotKey(day: dayIndex, choreTypeId: choreType.id)
        updatedSlots[key] = ChoreSlotAssignment(
            choreTypeId: choreType.id,
            choreTypeName: choreType.name,
            categoryName: category.name,
            categoryEmoji: category.emoji,
            categoryColorHex: category.colorHex,
            durationMinutes: choreType.durationMinutes,
            assignedTo: assignedTo.id,
            isCompleted: false
        )

        let plan = ChoresPlan(
            familyId: familyId,
            weekStart: weekStart,
            slots: updatedSlots
        )

        do {
            try await firestoreService.saveChoresPlan(familyId: familyId, plan: plan)
            debounceBriefingRegeneration()
        } catch {
            errorMessage = error.localizedDescription
        }

        selectedDayIndex = nil
    }

    func clearChore(dayIndex: Int, choreTypeId: String) async {
        var updatedSlots = slots
        let key = slotKey(day: dayIndex, choreTypeId: choreTypeId)
        updatedSlots.removeValue(forKey: key)

        let plan = ChoresPlan(
            familyId: familyId,
            weekStart: weekStart,
            slots: updatedSlots
        )

        do {
            try await firestoreService.saveChoresPlan(familyId: familyId, plan: plan)
            debounceBriefingRegeneration()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleCompletion(dayIndex: Int, choreTypeId: String) async {
        var updatedSlots = slots
        let key = slotKey(day: dayIndex, choreTypeId: choreTypeId)
        guard var assignment = updatedSlots[key] else { return }
        assignment.isCompleted.toggle()
        updatedSlots[key] = assignment

        let plan = ChoresPlan(
            familyId: familyId,
            weekStart: weekStart,
            slots: updatedSlots
        )

        do {
            try await firestoreService.saveChoresPlan(familyId: familyId, plan: plan)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Category CRUD

    func addCategory(name: String, emoji: String, colorHex: String) async {
        let nextOrder = (categories.map(\.sortOrder).max() ?? -1) + 1
        let category = ChoreCategory(
            name: name,
            emoji: emoji,
            colorHex: colorHex,
            sortOrder: nextOrder,
            isDefault: false,
            choreTypes: []
        )

        do {
            try await firestoreService.saveChoreCategory(familyId: familyId, category: category)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteCategory(_ category: ChoreCategory) async {
        guard let catId = category.id else { return }
        do {
            try await firestoreService.deleteChoreCategory(familyId: familyId, categoryId: catId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addChoreType(to category: ChoreCategory, name: String, description: String, durationMinutes: Int? = nil) async {
        var updated = category
        let newType = ChoreType(id: UUID().uuidString, name: name, description: description, durationMinutes: durationMinutes)
        updated.choreTypes.append(newType)

        do {
            try await firestoreService.saveChoreCategory(familyId: familyId, category: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateChoreType(in category: ChoreCategory, typeId: String, name: String, description: String, durationMinutes: Int? = nil) async {
        var updated = category
        guard let idx = updated.choreTypes.firstIndex(where: { $0.id == typeId }) else { return }
        updated.choreTypes[idx].name = name
        updated.choreTypes[idx].description = description
        updated.choreTypes[idx].durationMinutes = durationMinutes

        do {
            try await firestoreService.saveChoreCategory(familyId: familyId, category: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteChoreType(from category: ChoreCategory, typeId: String) async {
        var updated = category
        updated.choreTypes.removeAll { $0.id == typeId }

        do {
            try await firestoreService.saveChoreCategory(familyId: familyId, category: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Schedule count

    func scheduledCount(for category: ChoreCategory) -> Int {
        slots.values.filter { $0.categoryName == category.name }.count
    }

    func scheduledCount(for choreType: ChoreType) -> Int {
        slots.values.filter { $0.choreTypeId == choreType.id }.count
    }

    // MARK: - AI Briefing

    private func generateBriefing() async {
        let weekString = Self.weekFormatter.string(from: weekStart)
        let dayString = Self.dayFormatter.string(from: Date())
        let cacheKey = "ChoresBriefing.\(familyId).\(weekString)_\(dayString)"

        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(ChoresBriefing.self, from: data) {
            briefingHeadline = cached.headline
            briefingSummary = cached.summary
            return
        }

        isLoadingBriefing = true
        defer { isLoadingBriefing = false }

        let choreList = buildChoreListForPrompt()
        let totalChores = choreCount
        let totalCompleted = completedCount

        let prompt = """
        You are a friendly, practical household companion — like a helpful family member who keeps the home running smoothly. Given this week's chore schedule, write:

        1. HEADLINE: A short, warm headline (4-8 words) capturing the week's chore vibe. Use a line break (\\n) to split into two short lines. No quotes. Be genuine and practical.
           Examples:
           - "Lawn and pool week \u{2014}\\nsolid plan"
           - "Light week ahead\\nenjoy the break"
           - "Big clean incoming\\nall hands on deck"

        2. SUMMARY: One short sentence referencing actual chore names. Be practical and supportive. Under 120 characters.
           - If workload is balanced across people: affirm the fair split.
           - If one person has most chores: gently note it. "Tony\u{2019}s carrying a lot \u{2014} maybe Cleo can grab a couple?"
           - If nothing is planned yet: be gentle. "No chores yet \u{2014} a quiet week or still planning?"
           - Reference the actual chore names, not generic terms.

        Important tone notes:
        - Be warm and practical, like a family member helping organise
        - It\u{2019}s OK to gently suggest rebalancing workload
        - Never use corporate speak or motivational clich\u{00E9}s
        - Notice person distribution (who has most chores, who has fewest)

        Respond in exactly this format:
        HEADLINE: <headline>
        SUMMARY: <summary>

        This week\u{2019}s chore plan (\(totalChores) chores, \(totalCompleted) completed):
        \(choreList.isEmpty ? "No chores planned yet." : choreList)
        """

        do {
            let text = try await claudeService.callClaudeRaw(prompt: prompt, maxTokens: 200)
            var parsedHeadline = "Your chores week"
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

            let briefing = ChoresBriefing(weekStart: weekStart, headline: parsedHeadline, summary: parsedSummary)
            if let encoded = try? JSONEncoder().encode(briefing) {
                UserDefaults.standard.set(encoded, forKey: cacheKey)
            }
        } catch {
            briefingHeadline = "Your chores week"
            briefingSummary = choreCount > 0 ? "\(choreCount) chore\(choreCount == 1 ? "" : "s") planned this week." : "No chores planned yet."
        }
    }

    private func debounceBriefingRegeneration() {
        guard hasLoadedInitially else { return }
        debounceTask?.cancel()
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: debounceDuration)
                guard !Task.isCancelled else { return }
                let weekString = Self.weekFormatter.string(from: weekStart)
                let dayString = Self.dayFormatter.string(from: Date())
                let cacheKey = "ChoresBriefing.\(familyId).\(weekString)_\(dayString)"
                UserDefaults.standard.removeObject(forKey: cacheKey)
                await generateBriefing()
            } catch {
                // Cancelled
            }
        }
    }

    private func buildChoreListForPrompt() -> String {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        var lines: [String] = []

        for dayIndex in 0..<7 {
            let dayChores = choresForDay(dayIndex)
            if dayChores.isEmpty { continue }
            let choreDescs = dayChores.map { chore -> String in
                let assignee = self.assignee(for: chore.assignedTo)?.displayName ?? chore.assignedTo
                var desc = "\(chore.choreTypeName) (\(chore.categoryName), \(assignee)"
                if let dur = chore.durationMinutes { desc += ", \(dur)min" }
                if chore.isCompleted { desc += ", DONE" }
                desc += ")"
                return desc
            }
            lines.append("\u{2022} \(dayNames[dayIndex]): \(choreDescs.joined(separator: ", "))")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Cache

    private func loadCachedBriefing() {
        let weekString = Self.weekFormatter.string(from: weekStart)
        let dayString = Self.dayFormatter.string(from: Date())
        let cacheKey = "ChoresBriefing.\(familyId).\(weekString)_\(dayString)"

        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(ChoresBriefing.self, from: data) else { return }
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
