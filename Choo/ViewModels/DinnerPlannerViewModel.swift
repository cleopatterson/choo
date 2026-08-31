import Foundation

/// Dinners are a set of meals for the week, not a meal per night. You pick the
/// 5–6 things you want to eat, and that set is what you shop for.
@MainActor
@Observable
final class DinnerPlannerViewModel {
    let firestoreService: FirestoreService
    let familyId: String
    let displayName: String
    let userUID: String

    var errorMessage: String?

    /// Recipe id → the Monday of the most recent *past* week it was cooked.
    private(set) var lastCookedWeek: [String: Date] = [:]
    private(set) var hasLoadedHistory = false

    /// `.task {}` re-runs on every tab appearance — this keeps load() to once.
    @ObservationIgnored private var hasLoadedInitially = false

    private let calendar: Calendar = {
        var cal = Calendar.current
        cal.firstWeekday = 2 // Monday
        return cal
    }()

    init(firestoreService: FirestoreService, familyId: String, displayName: String, userUID: String) {
        self.firestoreService = firestoreService
        self.familyId = familyId
        self.displayName = displayName
        self.userUID = userUID
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

    var weekDateRange: String {
        let startDay = calendar.component(.day, from: weekStart)
        let endDate = weekDays.last ?? weekStart
        return "\(startDay)–\(Self.endDateFormatter.string(from: endDate))"
    }

    // MARK: - This week's picks

    /// The meals chosen for this week. Weeks planned before dinners stopped
    /// being per-night are read back through their old day assignments.
    var picks: [MealAssignment] {
        if let picks = firestoreService.currentMealPlan?.picks {
            return picks
        }
        let legacy = firestoreService.currentMealPlan?.assignments ?? [:]
        return legacy.keys.sorted().compactMap { legacy[$0] }
    }

    var pickedRecipeIds: Set<String> {
        Set(picks.map(\.recipeId))
    }

    func isPicked(_ recipe: Recipe) -> Bool {
        guard let id = recipe.id else { return false }
        return pickedRecipeIds.contains(id)
    }

    /// The design aims for 5–6 meals a week.
    static let targetPickCount = 6

    var pickCountLabel: String {
        "\(picks.count) of \(Self.targetPickCount) picked · aiming for 5–6"
    }

    var lastWeekRecipeIds: Set<String> {
        let plan = firestoreService.lastWeekMealPlan
        let fromPicks = (plan?.picks ?? []).map(\.recipeId)
        let fromDays = (plan?.assignments ?? [:]).values.map(\.recipeId)
        return Set(fromPicks).union(fromDays)
    }

    var ingredientCount: Int {
        let ingredients = firestoreService.recipes
            .filter { pickedRecipeIds.contains($0.id ?? "") }
            .flatMap(\.ingredients)

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

        hasLoadedInitially = true
        await loadCookingHistory()
    }

    /// Reads past meal plans once so "last had it" is a real date, not a guess.
    func loadCookingHistory() async {
        do {
            let plans = try await firestoreService.fetchRecentMealPlans(familyId: familyId)
            var mostRecent: [String: Date] = [:]
            for plan in plans where plan.weekStart < weekStart {
                let ids = Set((plan.picks ?? []).map(\.recipeId))
                    .union(plan.assignments.values.map(\.recipeId))
                for id in ids where mostRecent[id] == nil || mostRecent[id]! < plan.weekStart {
                    mostRecent[id] = plan.weekStart
                }
            }
            lastCookedWeek = mostRecent
            hasLoadedHistory = true
        } catch {
            // History is a nicety — a failure here shouldn't block planning.
            hasLoadedHistory = true
        }
    }

    // MARK: - Pick / Unpick

    func togglePick(_ recipe: Recipe) async {
        if isPicked(recipe) {
            await removePick(recipe)
        } else {
            await addPick(recipe)
        }
    }

    func addPick(_ recipe: Recipe) async {
        guard let recipeId = recipe.id, !pickedRecipeIds.contains(recipeId) else { return }
        var updated = picks
        updated.append(MealAssignment(
            recipeId: recipeId,
            recipeName: recipe.name,
            recipeIcon: recipe.icon
        ))
        await savePicks(updated)
    }

    func removePick(_ recipe: Recipe) async {
        guard let recipeId = recipe.id else { return }
        await removePick(recipeId: recipeId)
    }

    func removePick(recipeId: String) async {
        let updated = picks.filter { $0.recipeId != recipeId }
        guard updated.count != picks.count else { return }
        await savePicks(updated)
        await removeRecipeFromShoppingList(recipeId: recipeId)
    }

    private func savePicks(_ updated: [MealAssignment]) async {
        let plan = MealPlan(
            familyId: familyId,
            weekStart: weekStart,
            assignments: [:],
            picks: updated
        )
        do {
            try await firestoreService.saveMealPlan(familyId: familyId, mealPlan: plan)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Shopping List Sync

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

    func uncheckedIngredientCount(for recipeId: String) -> Int {
        firestoreService.shoppingItems
            .filter { $0.sourceRecipeId == recipeId && !$0.isChecked }
            .count
    }

    // MARK: - "Last had it"

    /// e.g. "had it last week", "last had 5 weeks ago", "never made it".
    func lastHadText(for recipe: Recipe) -> String {
        guard let id = recipe.id else { return "" }
        guard let week = lastCookedWeek[id] else {
            return hasLoadedHistory ? "never made it" : ""
        }
        let weeks = calendar.dateComponents([.weekOfYear], from: week, to: weekStart).weekOfYear ?? 0
        switch weeks {
        case ..<1: return "had it this week"
        case 1: return "had it last week"
        default: return "last had \(weeks) weeks ago"
        }
    }

    /// The line under a meal in the pick list: "25 min · had it last week".
    func librarySubtitle(for recipe: Recipe) -> String {
        [recipe.prepTimeDisplay, lastHadText(for: recipe)]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
    }

    func hadItLastWeek(_ recipe: Recipe) -> Bool {
        guard let id = recipe.id else { return false }
        return lastWeekRecipeIds.contains(id)
    }

    /// Meals you haven't had for longest float to the top of the pick list.
    var libraryRecipes: [Recipe] {
        firestoreService.recipes.sorted { lhs, rhs in
            let lhsWeek = lhs.id.flatMap { lastCookedWeek[$0] }
            let rhsWeek = rhs.id.flatMap { lastCookedWeek[$0] }
            switch (lhsWeek, rhsWeek) {
            case (nil, nil): return lhs.name < rhs.name
            case (nil, _):   return true      // never cooked comes first
            case (_, nil):   return false
            case let (l?, r?):
                return l == r ? lhs.name < rhs.name : l < r
            }
        }
    }

    // MARK: - Week context

    /// "Tony's out Wed and Fri", read from the calendar — or a plain count.
    var contextLabel: String {
        let nights = awayNights
        guard !nights.isEmpty else {
            return "\(picks.count) meal\(picks.count == 1 ? "" : "s") for the week"
        }
        let firstName = displayName.split(separator: " ").first.map(String.init) ?? displayName
        return "\(firstName)'s out \(Self.listPhrase(nights))"
    }

    /// Nights this week where the user has an evening (5pm onwards) event.
    var awayNights: [String] {
        weekDays
            .filter { day in
                firestoreService.events.contains { event in
                    guard event.isBill != true, event.isTodo != true, event.isAllDay != true else { return false }
                    guard calendar.isDate(event.startDate, inSameDayAs: day) else { return false }
                    guard (event.attendeeUIDs ?? []).contains(userUID) else { return false }
                    return calendar.component(.hour, from: event.startDate) >= 17
                }
            }
            .map { Self.abbrevFormatter.string(from: $0) }
    }

    /// ["Wed"] → "Wed"; ["Wed","Fri"] → "Wed and Fri"; 3+ → "Wed, Thu and Fri".
    private static func listPhrase(_ items: [String]) -> String {
        switch items.count {
        case 0: return ""
        case 1: return items[0]
        default: return items.dropLast().joined(separator: ", ") + " and " + items[items.count - 1]
        }
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

    var todayIndex: Int? {
        weekDays.firstIndex(where: { calendar.isDateInToday($0) })
    }

    // MARK: - Formatters

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
