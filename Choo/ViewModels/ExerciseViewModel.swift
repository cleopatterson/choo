import Foundation

enum ExercisePersona: String, CaseIterable, Identifiable {
    case routine   // "I have a set routine"
    case guided    // "I exercise sometimes, want more structure"
    case coaching  // "I want to start moving more"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .routine: "I have a set routine"
        case .guided: "I exercise sometimes, want more structure"
        case .coaching: "I want to start moving more"
        }
    }

    var emoji: String {
        switch self {
        case .routine: "💪"
        case .guided: "🎯"
        case .coaching: "🌱"
        }
    }

    var subtitle: String {
        switch self {
        case .routine: "The AI learns your fixed schedule and only varies the flexible parts."
        case .guided: "The AI suggests a balanced week based on what you've been doing."
        case .coaching: "The AI builds you up gradually based on what you actually complete."
        }
    }

    private static let key = "exercisePersona"

    static var current: ExercisePersona? {
        guard let raw = UserDefaults.standard.string(forKey: key) else { return nil }
        return ExercisePersona(rawValue: raw)
    }

    static func save(_ persona: ExercisePersona) {
        UserDefaults.standard.set(persona.rawValue, forKey: key)
        // Seed default routine template for routine mode
        if persona == .routine && RoutineTemplate.current == nil {
            RoutineTemplate.save(.tonyDefault)
        }
    }
}

// MARK: - Fixed Routine Template

/// Describes the user's fixed weekly exercise structure for routine mode.
/// The AI replicates this pattern each week, varying only the specific session
/// within each category (e.g. which yoga type) for freshness.
struct RoutineTemplate: Codable {
    var slots: [RoutineSlot]

    struct RoutineSlot: Codable {
        var day: Int           // 0=Mon ... 6=Sun
        var timeSlot: String   // "morning", "lunch", "arvo"
        var category: String   // e.g. "Yoga", "Weights", "Run"
        var fixedSession: String?  // If set, always use this specific session (e.g. "VO2 Max")
    }

    private static let key = "exerciseRoutineTemplate"

    static var current: RoutineTemplate? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(RoutineTemplate.self, from: data)
    }

    static func save(_ template: RoutineTemplate) {
        if let data = try? JSONEncoder().encode(template) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    /// Tony's default routine
    static let tonyDefault = RoutineTemplate(slots: [
        // Mon: yoga morning, weights lunch
        .init(day: 0, timeSlot: "morning", category: "Yoga"),
        .init(day: 0, timeSlot: "lunch", category: "Weights"),
        // Tue: yoga morning, run
        .init(day: 1, timeSlot: "morning", category: "Yoga"),
        .init(day: 1, timeSlot: "lunch", category: "Run"),
        // Wed: yoga morning, weights lunch
        .init(day: 2, timeSlot: "morning", category: "Yoga"),
        .init(day: 2, timeSlot: "lunch", category: "Weights"),
        // Thu: yoga morning, cardio VO2 max
        .init(day: 3, timeSlot: "morning", category: "Yoga"),
        .init(day: 3, timeSlot: "lunch", category: "Cardio", fixedSession: "VO2 Max"),
        // Fri: yoga morning, weights lunch
        .init(day: 4, timeSlot: "morning", category: "Yoga"),
        .init(day: 4, timeSlot: "lunch", category: "Weights"),
        // Sat: run
        .init(day: 5, timeSlot: "morning", category: "Run"),
        // Sun: easy ride
        .init(day: 6, timeSlot: "morning", category: "Cycling", fixedSession: "Easy Ride"),
    ])
}

@MainActor
@Observable
final class ExerciseViewModel {
    let firestoreService: FirestoreService
    let claudeService: ClaudeAPIService
    let healthKitService: HealthKitService
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

    init(firestoreService: FirestoreService, claudeService: ClaudeAPIService, healthKitService: HealthKitService = .shared, familyId: String, userId: String, displayName: String) {
        self.firestoreService = firestoreService
        self.claudeService = claudeService
        self.healthKitService = healthKitService
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

    /// Total planned minutes for future days this week (not yet completed)
    var weekPlannedMinutes: Int {
        guard let todayIdx = todayIndex else {
            return slots.values.compactMap(\.durationMinutes).reduce(0, +)
        }
        // Only count sessions on today or future days
        var total = 0
        for dayIndex in todayIdx..<7 {
            let sessions = sessionsForDay(dayIndex)
            total += sessions.compactMap(\.assignment.durationMinutes).reduce(0, +)
        }
        return total
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

        // HealthKit
        await healthKitService.requestAuthorization()
        healthKitService.fetchIfNeeded()

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

    func updateCategory(_ category: ExerciseCategory, name: String, emoji: String) async {
        var updated = category
        updated.name = name
        updated.emoji = emoji
        do {
            try await firestoreService.saveExerciseCategory(familyId: familyId, userId: userId, category: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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

    func reorderCategories(fromOffsets: IndexSet, toOffset: Int) {
        var reordered = categories
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        let orderedIds = reordered.compactMap(\.id)
        // Optimistic local update
        for (i, id) in orderedIds.enumerated() {
            if let idx = firestoreService.exerciseCategories.firstIndex(where: { $0.id == id }) {
                firestoreService.exerciseCategories[idx].sortOrder = i
            }
        }
        firestoreService.exerciseCategories.sort { $0.sortOrder < $1.sortOrder }
        Task {
            do {
                try await firestoreService.reorderExerciseCategories(familyId: familyId, userId: userId, orderedIds: orderedIds)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteCategory(_ category: ExerciseCategory) async {
        guard let catId = category.id else { return }
        // Clean up any plan slots referencing this category
        let slotsToRemove = slots.filter { $0.value.categoryName == category.name }
        if !slotsToRemove.isEmpty {
            var updatedSlots = slots
            for key in slotsToRemove.keys {
                updatedSlots.removeValue(forKey: key)
            }
            let plan = ExercisePlan(
                userId: userId,
                weekStart: weekStart,
                slots: updatedSlots,
                restDays: restDays
            )
            try? await firestoreService.saveExercisePlan(familyId: familyId, userId: userId, plan: plan)
        }
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

    // MARK: - Auto-Plan

    var persona: ExercisePersona? {
        ExercisePersona.current
    }

    func autoPlanWeek() async throws {
        guard let persona = ExercisePersona.current else { return }

        // Ensure routine template exists for routine mode
        if persona == .routine && RoutineTemplate.current == nil {
            RoutineTemplate.save(.tonyDefault)
        }

        let context: ExercisePlanContext
        let system: String

        switch persona {
        case .routine:
            context = buildRoutineContext()
            system = Self.routineSystemPrompt
        case .guided:
            context = buildGuidedContext()
            system = Self.guidedSystemPrompt
        case .coaching:
            context = buildCoachingContext()
            system = Self.coachingSystemPrompt
        }

        let contextJSON = try JSONEncoder().encode(context)
        let contextString = String(data: contextJSON, encoding: .utf8) ?? "{}"

        let response: ExerciseAutoPlanResponse = try await claudeService.callClaudeJSON(
            system: system,
            prompt: contextString,
            maxTokens: 800
        )

        // Map response to ExerciseSlotAssignment
        var newSlots: [String: ExerciseSlotAssignment] = [:]
        var newRestDays: [Int] = []

        // Build lookup: sessionTypeId -> (SessionType, ExerciseCategory)
        let allSessions: [(SessionType, ExerciseCategory)] = categories.flatMap { cat in
            cat.sessionTypes.map { ($0, cat) }
        }
        let sessionLookup = Dictionary(uniqueKeysWithValues: allSessions.compactMap { session, cat -> (String, (SessionType, ExerciseCategory))? in
            return (session.id, (session, cat))
        })
        // Also build name lookup as fallback
        let nameLookup = Dictionary(allSessions.map { session, cat in (session.name.lowercased(), (session, cat)) }, uniquingKeysWith: { first, _ in first })

        for dayPlan in response.plan {
            if dayPlan.rest == true {
                newRestDays.append(dayPlan.day)
                continue
            }
            for slotPlan in dayPlan.slots ?? [] {
                guard let timeSlot = TimeSlot(rawValue: slotPlan.slot.lowercased()) else { continue }

                // Find session by ID first, then by name
                let match = sessionLookup[slotPlan.session_id ?? ""]
                    ?? nameLookup[slotPlan.session_name?.lowercased() ?? ""]

                guard let (sessionType, category) = match else { continue }

                let key = slotKey(day: dayPlan.day, timeSlot: timeSlot)
                newSlots[key] = ExerciseSlotAssignment(
                    sessionTypeId: sessionType.id,
                    sessionTypeName: sessionType.name,
                    categoryName: category.name,
                    categoryEmoji: category.emoji,
                    categoryColorHex: category.colorHex,
                    durationMinutes: sessionType.durationMinutes,
                    estimatedCalories: sessionType.estimatedCalories,
                    intensity: sessionType.intensity
                )
            }
        }

        guard !newSlots.isEmpty || !newRestDays.isEmpty else { return }

        let plan = ExercisePlan(
            userId: userId,
            weekStart: weekStart,
            slots: newSlots,
            restDays: newRestDays
        )

        try await firestoreService.saveExercisePlan(familyId: familyId, userId: userId, plan: plan)
        debounceBriefingRegeneration()
    }

    // MARK: - Context Builders

    private func buildRoutineContext() -> ExercisePlanContext {
        var extra: [String: String] = [
            "last_week_plan": buildLastWeekPlanDescription()
        ]
        // Include fixed routine template if available
        if let template = RoutineTemplate.current,
           let data = try? JSONEncoder().encode(template.slots),
           let json = String(data: data, encoding: .utf8) {
            extra["fixed_schedule"] = json
        }
        return buildBaseContext(persona: "routine", extraFields: extra)
    }

    private func buildGuidedContext() -> ExercisePlanContext {
        buildBaseContext(persona: "guided", extraFields: [
            "recent_activity_summary": "Exercise minutes this week: \(healthKitService.weekExerciseMinutes), workouts: \(healthKitService.weekWorkouts.count)"
        ])
    }

    private func buildCoachingContext() -> ExercisePlanContext {
        buildBaseContext(persona: "coaching", extraFields: [
            "weekly_exercise_minutes": "\(healthKitService.weekExerciseMinutes)",
            "weekly_workouts": "\(healthKitService.weekWorkouts.count)"
        ])
    }

    private func buildBaseContext(persona: String, extraFields: [String: String] = [:]) -> ExercisePlanContext {
        let library = categories.map { cat in
            ExercisePlanContext.CategoryInfo(
                name: cat.name,
                emoji: cat.emoji,
                sessions: cat.sessionTypes.map { st in
                    ExercisePlanContext.SessionInfo(
                        id: st.id,
                        name: st.name,
                        duration_minutes: st.durationMinutes ?? 30,
                        intensity: st.intensity ?? "moderate",
                        estimated_calories: st.estimatedCalories
                    )
                }
            )
        }

        // Calendar conflicts for morning/lunch slots
        let events = firestoreService.events
        let conflicts: [ExercisePlanContext.ConflictInfo] = (0..<7).flatMap { dayIndex -> [ExercisePlanContext.ConflictInfo] in
            let date = weekDays[dayIndex]
            let dayEvents = events.filter { calendar.isDate($0.startDate, inSameDayAs: date) }
            return dayEvents.compactMap { event in
                let hour = calendar.component(.hour, from: event.startDate)
                let slot: String?
                if hour >= 5 && hour < 10 { slot = "morning" }
                else if hour >= 11 && hour < 14 { slot = "lunch" }
                else { slot = nil }
                guard let slot else { return nil }
                return ExercisePlanContext.ConflictInfo(day: dayIndex, slot: slot, event: event.title)
            }
        }

        return ExercisePlanContext(
            persona: persona,
            week_start: Self.dayFormatter.string(from: weekStart),
            workout_library: library,
            calendar_conflicts: conflicts,
            extra: extraFields
        )
    }

    private func buildLastWeekPlanDescription() -> String {
        // Read last week's slots from current plan context (if we had last week's plan listener)
        // For now, describe current plan as the "pattern" since routine mode replicates structure
        let dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        var lines: [String] = []
        for dayIndex in 0..<7 {
            if restDays.contains(dayIndex) {
                lines.append("\(dayNames[dayIndex]): Rest")
                continue
            }
            let sessions = sessionsForDay(dayIndex)
            if sessions.isEmpty { continue }
            let descs = sessions.map { "\($0.timeSlot.rawValue): \($0.assignment.sessionTypeName) (\($0.assignment.categoryName))" }
            lines.append("\(dayNames[dayIndex]): \(descs.joined(separator: ", "))")
        }
        return lines.isEmpty ? "No previous plan" : lines.joined(separator: "; ")
    }

    // MARK: - System Prompts

    private static let routineSystemPrompt = """
    You are generating this week's exercise plan for someone with a \
    fixed weekly routine. Their schedule structure is locked — your job is \
    to follow it exactly, choosing specific sessions from the workout library \
    for each slot.

    You receive JSON with:
    - workout_library: available session types per category
    - calendar_conflicts: events that clash with exercise slots
    - extra.fixed_schedule: the user's fixed weekly structure (array of {day, timeSlot, category, fixedSession?})
    - extra.last_week_plan: what was planned last week (for variety)

    The fixed_schedule is the source of truth for WHICH categories go WHERE. \
    Follow it exactly. For each slot:
    - If fixedSession is set, use that exact session name (find it in the library by name)
    - If fixedSession is null, pick a session from that category's library, \
      varying from last week's choice for freshness
    - For yoga specifically: spread different session types across the week \
      (e.g. Yin, Power, Flow — don't repeat the same one on consecutive days)

    Respond with JSON only:
    {
      "plan": [
        {"day": 0, "slots": [
          {"slot": "morning", "session_id": "abc", "session_name": "Yin Yoga"},
          {"slot": "lunch", "session_id": "def", "session_name": "Upper Body"}
        ]},
        {"day": 2, "rest": true},
        ...
      ]
    }

    Rules:
    1. day is 0-6 (Monday=0 through Sunday=6)
    2. slot must be "morning", "lunch", or "arvo"
    3. Follow fixed_schedule exactly — same categories on same days, same slots
    4. For flexible slots (no fixedSession), vary the session type from last week
    5. Spread yoga sessions: don't repeat the same yoga type on consecutive days
    6. Prefer gentler yoga (Yin) after heavy training days, stronger yoga (Power) on lighter days
    7. If a slot has a calendar conflict, move to the next available slot that day
    8. Days with no slots in fixed_schedule are rest days — mark with "rest": true
    9. Use session_name to match sessions — include both session_id and session_name
    """

    private static let guidedSystemPrompt = """
    You are a balanced exercise planner helping someone who exercises sometimes \
    and wants more structure. Suggest a good, varied week.

    You receive JSON with workout_library and calendar_conflicts.

    Respond with JSON only:
    {
      "plan": [
        {"day": 0, "slots": [
          {"slot": "morning", "session_id": "abc", "session_name": "Flow"}
        ]},
        {"day": 2, "rest": true},
        ...
      ]
    }

    Rules:
    1. day is 0-6 (Monday=0 through Sunday=6), slot is "morning", "lunch", or "arvo"
    2. Aim for 4-5 sessions per week with 2-3 rest days
    3. Mix categories for variety (cardio, strength, flexibility)
    4. If recent activity shows gaps (e.g. no flexibility), fill them
    5. Don't schedule two high-intensity sessions back-to-back
    6. Respect calendar conflicts
    7. Keep total weekly minutes around 150-200 (WHO guideline)
    """

    private static let coachingSystemPrompt = """
    You are a personal fitness coach helping someone build an exercise habit. \
    Celebrate consistency over intensity. Never guilt or pressure.

    You receive JSON with workout_library, calendar_conflicts, and recent activity data.

    Respond with JSON only:
    {
      "plan": [
        {"day": 0, "slots": [
          {"slot": "morning", "session_id": "abc", "session_name": "Gentle Yoga"}
        ]},
        {"day": 2, "rest": true},
        ...
      ]
    }

    Rules:
    1. day is 0-6 (Monday=0 through Sunday=6), slot is "morning", "lunch", or "arvo"
    2. Start with 2-3 sessions for beginners, build up gradually
    3. Never increase by more than 1 session week-over-week
    4. At least 1 rest day between high-impact sessions
    5. Favour variety and lighter intensities for beginners
    6. Place workouts in available calendar slots
    7. Build on emerging patterns — if they consistently do certain days, keep those
    """

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
        let totalPlannedMins = weekPlannedMinutes
        let actualMins = healthKitService.weekExerciseMinutes
        let combinedMins = actualMins + totalPlannedMins
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
        - The WHO guideline is 150 min/week. Current total: \(combinedMins) min (\(actualMins) done + \(totalPlannedMins) planned). Reference this naturally if relevant (e.g. "You're at 95 of 150 min this week" or "On track for 150 min").
        - If \(totalSessions) sessions are planned with only \(totalRest) rest day(s), note the load
        - Notice day load patterns (Peak days should have recovery nearby, multiple Peak days in a row is a flag)
        - Notice category balance (all cardio = suggest flexibility, all flexibility = suggest some intensity)
        - If nothing is planned yet, be gentle and encouraging about starting

        Respond in exactly this format:
        HEADLINE: <headline>
        SUMMARY: <summary>

        This week's HealthKit actuals:
        - Average daily steps: \(healthKitService.weekAverageSteps)
        - Total calories burned: \(healthKitService.weekTotalCalories)
        - Total exercise minutes: \(healthKitService.weekExerciseMinutes)
        - Completed workouts: \(healthKitService.weekWorkouts.count)

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

// MARK: - Auto-Plan Models

struct ExercisePlanContext: Encodable {
    var persona: String
    var week_start: String
    var workout_library: [CategoryInfo]
    var calendar_conflicts: [ConflictInfo]
    var extra: [String: String]

    struct CategoryInfo: Encodable {
        var name: String
        var emoji: String
        var sessions: [SessionInfo]
    }

    struct SessionInfo: Encodable {
        var id: String
        var name: String
        var duration_minutes: Int
        var intensity: String
        var estimated_calories: Int?
    }

    struct ConflictInfo: Encodable {
        var day: Int
        var slot: String
        var event: String
    }
}

struct ExerciseAutoPlanResponse: Decodable {
    var plan: [ExerciseDayPlan]

    struct ExerciseDayPlan: Decodable {
        var day: Int
        var rest: Bool?
        var slots: [SlotPlan]?

        struct SlotPlan: Decodable {
            var slot: String
            var session_id: String?
            var session_name: String?
        }
    }
}
