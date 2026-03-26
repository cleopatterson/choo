import Foundation

@MainActor
@Observable
final class HouseViewModel {
    let firestoreService: FirestoreService
    let claudeService: ClaudeAPIService
    let familyId: String
    let displayName: String

    var showingCategoryForm = false
    var briefingHeadline = "Your house this week"
    var briefingSummary = ""
    var isLoadingBriefing = false
    var errorMessage: String?
    var expandedCategoryId: String?
    var expandedFrequency: ChoreFrequency? = .weekly
    var expandedJobCategory: String?
    var selectedChoreForAction: HouseDueItem?
    var selectedChoreForEdit: HouseDueItem?
    var selectedDayIndex: Int?

    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var hasLoadedInitially = false
    @ObservationIgnored private let debounceDuration: UInt64 = 3_000_000_000
    @ObservationIgnored private let graceDays = 3
    @ObservationIgnored private var _cachedAllItems: [HouseDueItem] = []
    @ObservationIgnored private var _allItemsCacheKey = ""

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

    // MARK: - Data Access

    var categories: [ChoreCategory] {
        firestoreService.choreCategories
    }

    private var completions: [ChoreCompletion] {
        firestoreService.choreCompletions
    }

    private var assignments: [String: String] {
        firestoreService.choreAssignments
    }

    private var dayPlan: [String: Int] {
        firestoreService.choreDayPlan
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

    func choresForDay(_ dayIndex: Int) -> [HouseDueItem] {
        allItems.filter { dayPlan[$0.id] == dayIndex }
    }

    func planChoreToDay(_ choreTypeId: String, dayIndex: Int) async {
        var updatedDayPlan = dayPlan
        updatedDayPlan[choreTypeId] = dayIndex

        do {
            try await firestoreService.saveChoreAssignments(
                familyId: familyId,
                assignments: assignments,
                dayPlan: updatedDayPlan
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unplanChore(_ choreTypeId: String) async {
        var updatedDayPlan = dayPlan
        updatedDayPlan.removeValue(forKey: choreTypeId)

        do {
            try await firestoreService.saveChoreAssignments(
                familyId: familyId,
                assignments: assignments,
                dayPlan: updatedDayPlan
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Due System

    struct HouseDueItem: Identifiable {
        let id: String
        let choreType: ChoreType
        let categoryName: String
        let categoryEmoji: String
        let categoryColorHex: String
        let lastCompleted: Date?
        let assignedTo: String?
        let plannedDay: Int?
        let isDue: Bool
        let isOverdue: Bool
    }

    var allItems: [HouseDueItem] {
        let key = "\(categories.count)-\(completions.count)-\(assignments.count)-\(dayPlan.count)"
        if key == _allItemsCacheKey && !_cachedAllItems.isEmpty {
            return _cachedAllItems
        }

        let now = Date()
        // Pre-compute latest completion per chore type to avoid O(n) scan per chore
        let latestByType = Dictionary(grouping: completions, by: \.choreTypeId)
            .mapValues { $0.map(\.completedDate).max() }

        var items: [HouseDueItem] = []
        for category in categories {
            for choreType in category.choreTypes {
                let lastCompleted = latestByType[choreType.id] ?? nil
                let due = isDue(choreType: choreType, lastCompleted: lastCompleted, now: now)
                let overdue = isOverdue(choreType: choreType, lastCompleted: lastCompleted, now: now)
                items.append(HouseDueItem(
                    id: choreType.id,
                    choreType: choreType,
                    categoryName: category.name,
                    categoryEmoji: category.emoji,
                    categoryColorHex: category.colorHex,
                    lastCompleted: lastCompleted,
                    assignedTo: assignments[choreType.id],
                    plannedDay: dayPlan[choreType.id],
                    isDue: due,
                    isOverdue: overdue
                ))
            }
        }
        _cachedAllItems = items
        _allItemsCacheKey = key
        return items
    }

    var dueItems: [HouseDueItem] {
        allItems.filter { $0.isDue }
    }

    var itemsByFrequency: [(frequency: ChoreFrequency, items: [HouseDueItem])] {
        let all = allItems
        return ChoreFrequency.allCases.compactMap { freq in
            let matching = all.filter { $0.choreType.effectiveFrequency == freq }
            return matching.isEmpty ? nil : (frequency: freq, items: matching)
        }
    }

    var itemsByCategory: [(name: String, emoji: String, colorHex: String, items: [HouseDueItem])] {
        let all = allItems
        return categories.compactMap { category in
            let matching = all.filter { $0.categoryName == category.name }
            return matching.isEmpty ? nil : (name: category.name, emoji: category.emoji, colorHex: category.colorHex, items: matching)
        }
    }

    private func isDue(choreType: ChoreType, lastCompleted: Date?, now: Date) -> Bool {
        guard let last = lastCompleted else { return true }
        let calendar = Calendar.current
        let daysSince = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
        return daysSince >= choreType.effectiveFrequency.days
    }

    private func isOverdue(choreType: ChoreType, lastCompleted: Date?, now: Date) -> Bool {
        // Never-completed chores are "due" but not "overdue" — avoids alarming new users
        guard let last = lastCompleted else { return false }
        let calendar = Calendar.current
        let daysSince = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 0
        return daysSince >= (choreType.effectiveFrequency.days + graceDays)
    }

    // MARK: - Stats

    var dueCount: Int { dueItems.count }

    var overdueCount: Int { allItems.filter(\.isOverdue).count }

    var completedThisMonthCount: Int {
        let calendar = Calendar.current
        let now = Date()
        return completions.filter {
            calendar.isDate($0.completedDate, equalTo: now, toGranularity: .month)
        }.count
    }

    // MARK: - Assignees

    var availableAssignees: [ChoreAssignee] {
        var result: [ChoreAssignee] = []
        let palette = ChoreAssignee.palette

        for (i, member) in firestoreService.familyMembers.enumerated() {
            let color = palette[i % palette.count]
            let initial = String(member.displayName.prefix(1)).uppercased()
            result.append(ChoreAssignee(
                id: member.id ?? member.displayName,
                displayName: member.displayName,
                emoji: initial,
                colorHex: color
            ))
        }

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

        result.append(.family)
        return result
    }

    func assignee(for id: String) -> ChoreAssignee? {
        availableAssignees.first(where: { $0.id == id })
    }

    // MARK: - Load

    func load() async {
        guard !hasLoadedInitially else { return }
        firestoreService.listenToChoreCategories(familyId: familyId)
        firestoreService.listenToChoreCompletions(familyId: familyId)
        firestoreService.listenToChoreAssignments(familyId: familyId)

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

    // MARK: - Actions

    func completeChore(_ choreTypeId: String, choreTypeName: String, categoryName: String) async {
        let completion = ChoreCompletion(
            choreTypeId: choreTypeId,
            choreTypeName: choreTypeName,
            categoryName: categoryName,
            completedBy: displayName,
            completedDate: Date(),
            familyId: familyId
        )

        do {
            try await firestoreService.saveChoreCompletion(familyId: familyId, completion: completion)
            var updatedAssignments = assignments
            updatedAssignments.removeValue(forKey: choreTypeId)
            var updatedDayPlan = dayPlan
            updatedDayPlan.removeValue(forKey: choreTypeId)
            try await firestoreService.saveChoreAssignments(
                familyId: familyId,
                assignments: updatedAssignments,
                dayPlan: updatedDayPlan
            )
            debounceBriefingRegeneration()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func assignChore(_ choreTypeId: String, to assigneeId: String) async {
        var updated = assignments
        updated[choreTypeId] = assigneeId

        do {
            try await firestoreService.saveChoreAssignments(familyId: familyId, assignments: updated, dayPlan: dayPlan)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func unassignChore(_ choreTypeId: String) async {
        var updated = assignments
        updated.removeValue(forKey: choreTypeId)

        do {
            try await firestoreService.saveChoreAssignments(familyId: familyId, assignments: updated, dayPlan: dayPlan)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Category CRUD

    func updateCategory(_ category: ChoreCategory, name: String, emoji: String) async {
        var updated = category
        updated.name = name
        updated.emoji = emoji
        do {
            try await firestoreService.saveChoreCategory(familyId: familyId, category: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

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

    func reorderCategories(fromOffsets: IndexSet, toOffset: Int) {
        var reordered = categories
        reordered.move(fromOffsets: fromOffsets, toOffset: toOffset)
        let orderedIds = reordered.compactMap(\.id)
        // Optimistic local update
        for (i, id) in orderedIds.enumerated() {
            if let idx = firestoreService.choreCategories.firstIndex(where: { $0.id == id }) {
                firestoreService.choreCategories[idx].sortOrder = i
            }
        }
        firestoreService.choreCategories.sort { $0.sortOrder < $1.sortOrder }
        Task {
            do {
                try await firestoreService.reorderChoreCategories(familyId: familyId, orderedIds: orderedIds)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func deleteCategory(_ category: ChoreCategory) async {
        guard let catId = category.id else { return }
        // Clean up assignments and day-plan entries for chore types in this category
        let typeIds = Set(category.choreTypes.map(\.id))
        var updatedAssignments = assignments
        var updatedDayPlan = dayPlan
        for typeId in typeIds {
            updatedAssignments.removeValue(forKey: typeId)
            updatedDayPlan.removeValue(forKey: typeId)
        }
        if updatedAssignments != assignments || updatedDayPlan != dayPlan {
            try? await firestoreService.saveChoreAssignments(
                familyId: familyId,
                assignments: updatedAssignments,
                dayPlan: updatedDayPlan
            )
        }
        do {
            try await firestoreService.deleteChoreCategory(familyId: familyId, categoryId: catId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addChoreType(to category: ChoreCategory, name: String, description: String, durationMinutes: Int? = nil, frequency: ChoreFrequency = .weekly) async {
        var updated = category
        let newType = ChoreType(id: UUID().uuidString, name: name, description: description, durationMinutes: durationMinutes, frequency: frequency)
        updated.choreTypes.append(newType)

        do {
            try await firestoreService.saveChoreCategory(familyId: familyId, category: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateChoreType(in category: ChoreCategory, typeId: String, name: String, description: String, durationMinutes: Int? = nil, frequency: ChoreFrequency = .weekly) async {
        var updated = category
        guard let idx = updated.choreTypes.firstIndex(where: { $0.id == typeId }) else { return }
        updated.choreTypes[idx].name = name
        updated.choreTypes[idx].description = description
        updated.choreTypes[idx].durationMinutes = durationMinutes
        updated.choreTypes[idx].frequency = frequency

        do {
            try await firestoreService.saveChoreCategory(familyId: familyId, category: updated)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateChoreFrequency(_ choreTypeId: String, frequency: ChoreFrequency) async {
        guard let category = categories.first(where: { $0.choreTypes.contains(where: { $0.id == choreTypeId }) }),
              let idx = category.choreTypes.firstIndex(where: { $0.id == choreTypeId }) else { return }
        var updated = category
        updated.choreTypes[idx].frequency = frequency

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

    // MARK: - Auto-Plan

    func autoPlanWeek() async throws {
        let context = buildAutoPlanContext()
        let contextJSON = try JSONEncoder().encode(context)
        let contextString = String(data: contextJSON, encoding: .utf8) ?? "{}"

        let system = """
        You are a pragmatic household project manager. You prioritise honestly \
        and defer what can wait. You never over-commit.

        You receive a JSON context with:
        - chores: each with id, name, cadence_days, last_done_days_ago, \
        estimated_minutes, category, default_person, importance
        - free_time_per_day: minutes available for chores per day
        - season: current season (Southern Hemisphere)
        - assignees: available people

        Respond with JSON only, no other text:
        {
          "plan": [
            {"day": 0, "chore_id": "bins", "person": "Tony"},
            {"day": 5, "chore_id": "mow", "person": "Tony"}
          ]
        }

        Rules:
        1. day is 0-6 (Monday=0 through Sunday=6)
        2. Use chore_id and person from the provided lists
        3. Health/safety items (pool chemicals) are never skipped
        4. Fixed-day items (bins) always placed on collection day (Monday=0)
        5. Seasonal adjustment: lawns in winter = relaxed, summer = urgent
        6. Total assigned minutes per day must not exceed that day's free_time
        7. Balance fairly between household members
        8. Score by: urgency (days_overdue / cadence_days) × importance — highest first
        9. Only schedule chores that are due or overdue (last_done_days_ago >= cadence_days or never done)
        10. It's OK to schedule fewer chores if time is tight — quality over quantity
        """

        let response: ChoresAutoPlanResponse = try await claudeService.callClaudeJSON(
            system: system,
            prompt: contextString,
            maxTokens: 800
        )

        // Apply the plan: build dayPlan and assignments dicts
        var newDayPlan: [String: Int] = [:]
        var newAssignments: [String: String] = [:]

        let validChoreIds = Set(allItems.map(\.id))
        let validAssigneeIds = Set(availableAssignees.map(\.id))

        for entry in response.plan {
            guard validChoreIds.contains(entry.chore_id) else { continue }
            guard entry.day >= 0 && entry.day <= 6 else { continue }

            newDayPlan[entry.chore_id] = entry.day

            if let person = entry.person,
               let assignee = availableAssignees.first(where: { $0.displayName == person || $0.id == person }) {
                newAssignments[entry.chore_id] = assignee.id
            }
        }

        guard !newDayPlan.isEmpty else { return }

        try await firestoreService.saveChoreAssignments(
            familyId: familyId,
            assignments: newAssignments,
            dayPlan: newDayPlan
        )
        debounceBriefingRegeneration()
    }

    private func buildAutoPlanContext() -> ChoresPlanContext {
        let now = Date()
        let month = calendar.component(.month, from: now)
        // Southern Hemisphere seasons
        let season: String
        switch month {
        case 12, 1, 2: season = "summer"
        case 3, 4, 5: season = "autumn"
        case 6, 7, 8: season = "winter"
        default: season = "spring"
        }

        let items = allItems
        let choreInfos: [ChoresPlanContext.ChoreInfo] = items.map { item in
            let daysSinceLast: Int
            if let last = item.lastCompleted {
                daysSinceLast = calendar.dateComponents([.day], from: calendar.startOfDay(for: last), to: calendar.startOfDay(for: now)).day ?? 999
            } else {
                daysSinceLast = 999  // Never done
            }

            let importance: String
            // Pool chemicals = health, weekly cleaning = core, monthly+ = maintenance
            if item.categoryName == "Swimming Pool" { importance = "health" }
            else if item.choreType.effectiveFrequency == .weekly { importance = "core" }
            else if item.choreType.effectiveFrequency == .monthly { importance = "maintenance" }
            else { importance = "nice-to-have" }

            return ChoresPlanContext.ChoreInfo(
                id: item.id,
                name: item.choreType.name,
                category: item.categoryName,
                cadence_days: item.choreType.effectiveFrequency.days,
                last_done_days_ago: daysSinceLast,
                estimated_minutes: item.choreType.durationMinutes ?? 30,
                default_person: item.assignedTo,
                importance: importance,
                is_due: item.isDue,
                is_overdue: item.isOverdue
            )
        }

        // Estimate free time per day from calendar events
        let events = firestoreService.events
        let dayInfos: [ChoresPlanContext.DayInfo] = (0..<7).map { dayIndex in
            let date = weekDays[dayIndex]
            let isWeekend = dayIndex >= 5
            let baseFreeMinutes = isWeekend ? 180 : 30  // Weekends have more chore time

            let dayEvents = events.filter { event in
                calendar.isDate(event.startDate, inSameDayAs: date)
            }
            let busyMinutes = dayEvents.reduce(0) { total, event in
                Int(event.endDate.timeIntervalSince(event.startDate) / 60)
            }
            let freeMinutes = max(0, baseFreeMinutes - min(busyMinutes, baseFreeMinutes))

            return ChoresPlanContext.DayInfo(day: dayIndex, free_minutes: freeMinutes)
        }

        let assigneeNames = availableAssignees.map(\.displayName)

        return ChoresPlanContext(
            season: season,
            chores: choreInfos,
            days: dayInfos,
            assignees: assigneeNames
        )
    }

    // MARK: - AI Briefing

    private func generateBriefing() async {
        let dayString = Self.dayFormatter.string(from: Date())
        let cacheKey = "HouseBriefing.\(familyId).\(dayString)"

        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(HouseBriefing.self, from: data) {
            briefingHeadline = cached.headline
            briefingSummary = cached.summary
            return
        }

        isLoadingBriefing = true
        defer { isLoadingBriefing = false }

        let dueList = buildDueListForPrompt()
        let totalDue = dueCount
        let totalOverdue = overdueCount

        let prompt = """
        You are a friendly, practical household companion. Given the current house chore status, write:

        1. HEADLINE: A short, warm headline (4-8 words) about what needs doing around the house. Use a line break (\\n) to split into two short lines. No quotes.
           Examples:
           - "Pool and lawns due\\nweekend sorted"
           - "Gutters overdue\\ntime to get up there"
           - "House is ticking along\\nnice work"

        2. SUMMARY: One short sentence referencing actual chore names. Under 120 characters. Be practical and warm.

        Important:
        - Be warm and practical, like a family member helping organise
        - Reference actual chore names
        - Never use corporate speak or motivational cliches
        - If lots overdue, gently note it

        Respond in exactly this format:
        HEADLINE: <headline>
        SUMMARY: <summary>

        House status (\(totalDue) due, \(totalOverdue) overdue):
        \(dueList.isEmpty ? "Everything is up to date!" : dueList)
        """

        do {
            let text = try await claudeService.callClaudeRaw(prompt: prompt, maxTokens: 200)
            var parsedHeadline = "Your house this week"
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

            let briefing = HouseBriefing(date: Date(), headline: parsedHeadline, summary: parsedSummary)
            if let encoded = try? JSONEncoder().encode(briefing) {
                UserDefaults.standard.set(encoded, forKey: cacheKey)
            }
        } catch {
            briefingHeadline = "Your house this week"
            briefingSummary = dueCount > 0 ? "\(dueCount) chore\(dueCount == 1 ? "" : "s") due." : "Everything is up to date!"
        }
    }

    private func debounceBriefingRegeneration() {
        guard hasLoadedInitially else { return }
        debounceTask?.cancel()
        debounceTask = Task {
            do {
                try await Task.sleep(nanoseconds: debounceDuration)
                guard !Task.isCancelled else { return }
                let dayString = Self.dayFormatter.string(from: Date())
                let cacheKey = "HouseBriefing.\(familyId).\(dayString)"
                UserDefaults.standard.removeObject(forKey: cacheKey)
                await generateBriefing()
            } catch {}
        }
    }

    private func buildDueListForPrompt() -> String {
        let due = dueItems
        guard !due.isEmpty else { return "" }
        return due.map { item in
            var desc = "\(item.choreType.name) (\(item.categoryName), \(item.choreType.effectiveFrequency.displayName)"
            if let assignee = item.assignedTo, let person = self.assignee(for: assignee) {
                desc += ", assigned to \(person.displayName)"
            }
            if item.isOverdue { desc += ", OVERDUE" }
            desc += ")"
            return "\u{2022} \(desc)"
        }.joined(separator: "\n")
    }

    // MARK: - Cache

    private func loadCachedBriefing() {
        let dayString = Self.dayFormatter.string(from: Date())
        let cacheKey = "HouseBriefing.\(familyId).\(dayString)"

        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(HouseBriefing.self, from: data) else { return }
        briefingHeadline = cached.headline
        briefingSummary = cached.summary
    }

    // MARK: - Formatters

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

struct ChoresPlanContext: Encodable {
    var season: String
    var chores: [ChoreInfo]
    var days: [DayInfo]
    var assignees: [String]

    struct ChoreInfo: Encodable {
        var id: String
        var name: String
        var category: String
        var cadence_days: Int
        var last_done_days_ago: Int
        var estimated_minutes: Int
        var default_person: String?
        var importance: String
        var is_due: Bool
        var is_overdue: Bool
    }

    struct DayInfo: Encodable {
        var day: Int
        var free_minutes: Int
    }
}

struct ChoresAutoPlanResponse: Decodable {
    var plan: [ChoresDayPlan]

    struct ChoresDayPlan: Decodable {
        var day: Int
        var chore_id: String
        var person: String?
    }
}
