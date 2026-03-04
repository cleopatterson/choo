import Foundation

@Observable
final class DinnerPlannerViewModel {
    let firestoreService: FirestoreService
    let claudeService: ClaudeAPIService
    let familyId: String
    let displayName: String

    var selectedDayIndex: Int?    // 0-6, triggers recipe picker
    var errorMessage: String?
    var briefingHeadline = "Dinners this week"
    var briefingSummary = ""
    var isLoadingBriefing = false

    @ObservationIgnored private var debounceTask: Task<Void, Never>?
    @ObservationIgnored private var hasLoadedInitially = false
    @ObservationIgnored private let debounceDuration: UInt64 = 3_000_000_000

    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
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

    var lastWeekStart: Date {
        calendar.date(byAdding: .day, value: -7, to: weekStart) ?? weekStart
    }

    var lastWeekDays: [Date] {
        (0..<7).compactMap { calendar.date(byAdding: .day, value: $0, to: lastWeekStart) }
    }

    var weekDateRange: String {
        let startDay = calendar.component(.day, from: weekStart)
        let endDate = weekDays.last ?? weekStart
        return "\(startDay)–\(Self.endDateFormatter.string(from: endDate))"
    }

    // MARK: - Assignments (from Firestore listener)

    var assignments: [String: MealAssignment] {
        firestoreService.currentMealPlan?.assignments ?? [:]
    }

    var lastWeekAssignments: [String: MealAssignment] {
        firestoreService.lastWeekMealPlan?.assignments ?? [:]
    }

    var lastWeekRecipeIds: Set<String> {
        Set(lastWeekAssignments.values.map(\.recipeId))
    }

    var plannedCount: Int {
        assignments.count
    }

    var ingredientCount: Int {
        let assignedRecipeIds = Set(assignments.values.map(\.recipeId))
        let ingredients = firestoreService.recipes
            .filter { assignedRecipeIds.contains($0.id ?? "") }
            .flatMap(\.ingredients)

        // Deduplicate by lowercased name
        var seen = Set<String>()
        var count = 0
        for ingredient in ingredients {
            let key = ingredient.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.insert(key).inserted {
                count += 1
            }
        }
        return count
    }

    // MARK: - Load

    func load() async {
        guard !hasLoadedInitially else { return }
        firestoreService.listenToMealPlan(familyId: familyId, weekStart: weekStart)
        firestoreService.listenToLastWeekMealPlan(familyId: familyId, weekStart: lastWeekStart)
        firestoreService.listenToRecipes(familyId: familyId)

        do {
            try await firestoreService.seedDefaultRecipes(familyId: familyId)
        } catch {
            errorMessage = error.localizedDescription
        }

        await generateBriefing()
        hasLoadedInitially = true
    }

    // MARK: - Assign / Clear

    func assignRecipe(_ recipe: Recipe, toDayIndex: Int) async {
        guard let recipeId = recipe.id else { return }

        var updated = assignments
        updated[String(toDayIndex)] = MealAssignment(
            recipeId: recipeId,
            recipeName: recipe.name,
            recipeIcon: recipe.icon
        )

        let plan = MealPlan(
            familyId: familyId,
            weekStart: weekStart,
            assignments: updated
        )

        do {
            try await firestoreService.saveMealPlan(familyId: familyId, mealPlan: plan)
            await addRecipeToShoppingList(recipe)
            debounceBriefingRegeneration()
        } catch {
            errorMessage = error.localizedDescription
        }

        selectedDayIndex = nil
    }

    func clearDay(_ dayIndex: Int) async {
        let key = String(dayIndex)
        guard let assignment = assignments[key] else { return }
        let recipeId = assignment.recipeId

        var updated = assignments
        updated.removeValue(forKey: key)

        let plan = MealPlan(
            familyId: familyId,
            weekStart: weekStart,
            assignments: updated
        )

        do {
            try await firestoreService.saveMealPlan(familyId: familyId, mealPlan: plan)

            // Only remove shopping items if this recipe isn't assigned to another day
            let stillAssigned = updated.values.contains { $0.recipeId == recipeId }
            if !stillAssigned {
                await removeRecipeFromShoppingList(recipeId: recipeId)
            }
            debounceBriefingRegeneration()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Shopping List Sync

    private func addRecipeToShoppingList(_ recipe: Recipe) async {
        guard let recipeId = recipe.id,
              let listId = firestoreService.shoppingLists.first?.id else { return }

        // Skip if this recipe's items are already in the list
        let existingRecipeItems = firestoreService.shoppingItems
            .filter { $0.sourceRecipeId == recipeId }
        guard existingRecipeItems.isEmpty else { return }

        // Existing item names for dedup (e.g. "Veggies" from another recipe)
        let existingNames = Set(firestoreService.shoppingItems.map {
            $0.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        })

        let nextOrder = (firestoreService.shoppingItems.compactMap { $0.sortOrder }.max() ?? -1) + 1
        var items: [(name: String, quantity: String?, sortOrder: Int)] = []

        for ingredient in recipe.ingredients {
            let key = ingredient.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard !existingNames.contains(key) else { continue }
            items.append((name: ingredient.name, quantity: ingredient.quantity, sortOrder: nextOrder + items.count))
        }

        guard !items.isEmpty else { return }

        do {
            try await firestoreService.addShoppingItemsFromRecipeBatch(
                familyId: familyId,
                listId: listId,
                items: items,
                addedBy: displayName,
                sourceRecipeId: recipeId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func removeRecipeFromShoppingList(recipeId: String) async {
        guard let listId = firestoreService.shoppingLists.first?.id else { return }

        do {
            try await firestoreService.deleteShoppingItemsByRecipe(
                familyId: familyId,
                listId: listId,
                recipeId: recipeId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Recipe Lookup

    func recipe(for assignment: MealAssignment) -> Recipe? {
        firestoreService.recipes.first { $0.id == assignment.recipeId }
    }

    /// Count of unchecked shopping items for a given recipe (for "🛒 N to buy" tag).
    func uncheckedIngredientCount(for recipeId: String) -> Int {
        firestoreService.shoppingItems
            .filter { $0.sourceRecipeId == recipeId && !$0.isChecked }
            .count
    }

    // MARK: - Day Helpers

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

    var todayIndex: Int? {
        weekDays.firstIndex(where: { calendar.isDateInToday($0) })
    }

    // MARK: - Today Hero Helpers

    var todayDayLabel: String {
        guard let idx = todayIndex else { return "TODAY" }
        let date = weekDays[idx]
        return "TONIGHT · \(Self.todayLabelFormatter.string(from: date))"
    }

    var todayAssignment: MealAssignment? {
        guard let idx = todayIndex else { return nil }
        return assignments[String(idx)]
    }

    var todayRecipe: Recipe? {
        todayAssignment.flatMap { recipe(for: $0) }
    }

    // MARK: - AI Briefing

    private func generateBriefing() async {
        let weekString = Self.weekFormatter.string(from: weekStart)
        let dayString = Self.dayFormatter.string(from: Date())
        let cacheKey = "DinnerBriefing.\(familyId).\(weekString)_\(dayString)"

        if let data = UserDefaults.standard.data(forKey: cacheKey),
           let cached = try? JSONDecoder().decode(DinnerBriefing.self, from: data) {
            briefingHeadline = cached.headline
            briefingSummary = cached.summary
            return
        }

        isLoadingBriefing = true
        defer { isLoadingBriefing = false }

        let mealList = buildMealListForPrompt()

        let prompt = """
        You are a warm, friendly family meal planner — like a foodie friend who loves a good dinner. Given this week's dinner plan (with cuisine, effort, and richness metadata), write:

        1. HEADLINE: A short, warm headline (4-8 words) capturing the week's dinner vibe. Use a line break (\\n) to split into two short lines. No quotes.
           Examples:
           - "Taco Tuesday vibes —\\nall week long"
           - "A mix of favourites\\nand something new"
           - "Comfort food week —\\ncosy evenings ahead"

        2. SUMMARY: One short sentence referencing actual recipe names. Under 120 characters.
           - Notice cuisine patterns (e.g. "Three Italian nights — the Thai curry breaks it up nicely")
           - Notice effort patterns (e.g. "Two big cooks back to back — the easy nights balance it out")
           - Notice richness patterns (e.g. "Light Mon and Fri, rich Wed and Sat — good balance")
           - If repetitive: gently note it. "Pasta twice — maybe swap one for something lighter?"
           - If mostly unplanned: be encouraging. "Only Monday sorted — plenty of room for inspiration."
           - Reference actual recipe names, not generic terms.

        Respond in exactly this format:
        HEADLINE: <headline>
        SUMMARY: <summary>

        This week's dinner plan (\(plannedCount) of 7 nights planned):
        \(mealList.isEmpty ? "No dinners planned yet." : mealList)
        """

        do {
            let text = try await claudeService.callClaudeRaw(prompt: prompt, maxTokens: 200)
            var parsedHeadline = "Dinners this week"
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

            let briefing = DinnerBriefing(weekStart: weekStart, headline: parsedHeadline, summary: parsedSummary)
            if let encoded = try? JSONEncoder().encode(briefing) {
                UserDefaults.standard.set(encoded, forKey: cacheKey)
            }
        } catch {
            briefingHeadline = "Dinners this week"
            briefingSummary = plannedCount > 0 ? "\(plannedCount) dinner\(plannedCount == 1 ? "" : "s") planned." : "No dinners planned yet."
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
                let cacheKey = "DinnerBriefing.\(familyId).\(weekString)_\(dayString)"
                UserDefaults.standard.removeObject(forKey: cacheKey)
                await generateBriefing()
            } catch {
                // Cancelled
            }
        }
    }

    private func buildMealListForPrompt() -> String {
        let dayNames = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
        var lines: [String] = []

        for dayIndex in 0..<7 {
            let key = String(dayIndex)
            if let meal = assignments[key] {
                var details: [String] = [meal.recipeName]
                if let recipe = recipe(for: meal) {
                    if let cuisine = recipe.cuisineType { details.append(cuisine.displayName) }
                    if let effort = recipe.prepEffortEnum { details.append("effort: \(effort.displayName)") }
                    if let richness = recipe.calorieDensityEnum { details.append("richness: \(richness.displayName)") }
                    if let prep = recipe.prepTimeDisplay { details.append(prep) }
                }
                lines.append("• \(dayNames[dayIndex]): \(details.joined(separator: ", "))")
            }
        }

        return lines.joined(separator: "\n")
    }

    private func loadCachedBriefing() {
        let weekString = Self.weekFormatter.string(from: weekStart)
        let dayString = Self.dayFormatter.string(from: Date())
        let cacheKey = "DinnerBriefing.\(familyId).\(weekString)_\(dayString)"

        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let cached = try? JSONDecoder().decode(DinnerBriefing.self, from: data) else { return }
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

    @ObservationIgnored
    private static let todayLabelFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE d"
        return f
    }()
}
