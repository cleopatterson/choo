import Foundation

@MainActor
@Observable
final class SuppliesViewModel {
    let firestoreService: FirestoreService
    let familyId: String
    let displayName: String

    var errorMessage: String?
    var editingItem: SupplyItem?
    var isAddingItem = false

    @ObservationIgnored private var hasLoadedInitially = false

    init(firestoreService: FirestoreService, familyId: String, displayName: String) {
        self.firestoreService = firestoreService
        self.familyId = familyId
        self.displayName = displayName
    }

    // MARK: - Load

    func load() async {
        guard !hasLoadedInitially else { return }
        hasLoadedInitially = true
        firestoreService.listenToSupplies(familyId: familyId)
        firestoreService.listenToSupplyCategoryOrder(familyId: familyId)

        // One-time migration: if no supplies exist but shopping items do,
        // migrate them across and clear the run.
        // Wait briefly for listeners to populate
        try? await Task.sleep(nanoseconds: 1_500_000_000)
        if firestoreService.supplies.isEmpty && !firestoreService.shoppingItems.isEmpty {
            await migrateRunToSupplies()
        }
    }

    // MARK: - Grouped Data

    var orderedCategories: [SupplyCategory] {
        let order = firestoreService.supplyCategoryOrder
        let hidden = firestoreService.hiddenSupplyCategories
        let base: [SupplyCategory]
        if order.isEmpty {
            base = SupplyCategory.allCases
        } else {
            let mapped = order.compactMap { SupplyCategory(rawValue: $0) }
            let missing = SupplyCategory.allCases.filter { cat in !mapped.contains(cat) }
            base = mapped + missing
        }
        return base.filter { !hidden.contains($0.rawValue) }
    }

    var groupedByCategory: [(category: SupplyCategory, items: [SupplyItem])] {
        let grouped = Dictionary(grouping: firestoreService.supplies) { $0.category }
        return orderedCategories.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (category: cat, items: items.sorted { $0.name < $1.name })
        }
    }

    func reorderCategories(fromOffsets: IndexSet, toOffset: Int) {
        var all = allCategoriesForManagement
        all.move(fromOffsets: fromOffsets, toOffset: toOffset)
        let ordered = all.map(\.rawValue)
        Task {
            do {
                try await firestoreService.saveSupplyCategoryOrder(
                    familyId: familyId,
                    ordered: ordered,
                    hidden: firestoreService.hiddenSupplyCategories
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleCategoryVisibility(_ category: SupplyCategory) {
        var hidden = firestoreService.hiddenSupplyCategories
        if hidden.contains(category.rawValue) {
            hidden.remove(category.rawValue)
        } else {
            hidden.insert(category.rawValue)
        }
        Task {
            do {
                let order = firestoreService.supplyCategoryOrder.isEmpty
                    ? SupplyCategory.allCases.map(\.rawValue)
                    : firestoreService.supplyCategoryOrder
                try await firestoreService.saveSupplyCategoryOrder(
                    familyId: familyId,
                    ordered: order,
                    hidden: hidden
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// All categories in custom order (including hidden) for the manage sheet
    var allCategoriesForManagement: [SupplyCategory] {
        let order = firestoreService.supplyCategoryOrder
        if order.isEmpty {
            return SupplyCategory.allCases.map { $0 }
        }
        let mapped = order.compactMap { SupplyCategory(rawValue: $0) }
        let missing = SupplyCategory.allCases.filter { cat in !mapped.contains(cat) }
        return mapped + missing
    }

    func isCategoryHidden(_ category: SupplyCategory) -> Bool {
        firestoreService.hiddenSupplyCategories.contains(category.rawValue)
    }

    var totalCount: Int {
        firestoreService.supplies.count
    }

    var lowCount: Int {
        firestoreService.supplies.filter { $0.status == .low }.count
    }

    var dueCount: Int {
        firestoreService.supplies.filter { $0.isDueOrLow }.count
    }

    // MARK: - Run Integration

    /// Check if a supply item is already in the current shopping run
    func isInRun(_ supply: SupplyItem) -> Bool {
        guard let supplyId = supply.id else { return false }
        return firestoreService.shoppingItems.contains { $0.supplyItemId == supplyId && !$0.isChecked }
    }

    func addToRun(_ supply: SupplyItem) async {
        guard let listId = firestoreService.shoppingLists.first?.id else { return }
        let nextOrder = (firestoreService.shoppingItems.compactMap { $0.sortOrder }.max() ?? -1) + 1

        let item = ShoppingItem(
            listId: listId,
            name: supply.name,
            isChecked: false,
            addedBy: displayName,
            createdAt: Date(),
            sortOrder: nextOrder,
            source: .cadence,
            cadenceTag: supply.status == .due ? "Due" : (supply.status == .low ? "Overdue" : supply.cadence.displayName),
            aisleOrder: supply.aisleOrder,
            supplyItemId: supply.id
        )

        do {
            try await firestoreService.addShoppingItemFull(familyId: familyId, listId: listId, item: item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func removeFromRun(_ supply: SupplyItem) async {
        guard let supplyId = supply.id,
              let listId = firestoreService.shoppingLists.first?.id else { return }

        let matching = firestoreService.shoppingItems.filter { $0.supplyItemId == supplyId }
        for item in matching {
            guard let itemId = item.id else { continue }
            do {
                try await firestoreService.deleteShoppingItem(familyId: familyId, listId: listId, itemId: itemId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    func toggleRunState(_ supply: SupplyItem) async {
        if isInRun(supply) {
            await removeFromRun(supply)
        } else {
            await addToRun(supply)
        }
    }

    // MARK: - CRUD

    func addItem(name: String, category: SupplyCategory, cadence: SupplyCadence, aisleOrder: Int) async {
        let item = SupplyItem(
            name: name,
            category: category,
            cadence: cadence,
            aisleOrder: aisleOrder
        )
        do {
            try await firestoreService.addSupplyItem(familyId: familyId, item: item)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateItem(_ item: SupplyItem, name: String, category: SupplyCategory, cadence: SupplyCadence, aisleOrder: Int) async {
        guard let itemId = item.id else { return }
        do {
            try await firestoreService.updateSupplyItem(familyId: familyId, itemId: itemId, data: [
                "name": name,
                "category": category.rawValue,
                "cadence": cadence.rawValue,
                "aisleOrder": aisleOrder,
            ])
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: SupplyItem) async {
        guard let itemId = item.id else { return }
        do {
            try await firestoreService.deleteSupplyItem(familyId: familyId, itemId: itemId)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func toggleLow(_ item: SupplyItem) async {
        guard let itemId = item.id else { return }
        do {
            try await firestoreService.markSupplyLow(familyId: familyId, itemId: itemId, isLow: !(item.isLow ?? false))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - One-Time Migration

    /// Migrate existing shopping run items into the Supplies collection with smart cadence,
    /// then clear the shopping list so the run starts empty.
    func migrateRunToSupplies() async {
        let items = firestoreService.shoppingItems.filter { !($0.isHeading ?? false) }
        guard !items.isEmpty else { return }

        // Deduplicate by lowercased name
        var seen = Set<String>()
        var unique: [ShoppingItem] = []
        for item in items {
            let key = item.name.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            if seen.insert(key).inserted {
                unique.append(item)
            }
        }

        for item in unique {
            let (category, cadence, aisle) = classifyItem(item.name)
            let supply = SupplyItem(
                name: item.name,
                category: category,
                cadence: cadence,
                aisleOrder: aisle,
                lastPurchasedDate: Date()  // just purchased = clock starts now
            )
            do {
                try await firestoreService.addSupplyItem(familyId: familyId, item: supply)
            } catch {
                errorMessage = error.localizedDescription
            }
        }

        // Now clear all shopping items
        guard let listId = firestoreService.shoppingLists.first?.id else { return }
        for item in firestoreService.shoppingItems {
            guard let itemId = item.id else { continue }
            do {
                try await firestoreService.deleteShoppingItem(familyId: familyId, listId: listId, itemId: itemId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Smart classification of grocery item name → (category, cadence, aisleOrder)
    private func classifyItem(_ name: String) -> (SupplyCategory, SupplyCadence, Int) {
        let lower = name.lowercased()

        // Cold goods — weekly perishables
        if lower.containsAny("milk", "cream", "yoghurt", "yogurt") {
            return (.coldGoods, .weekly, 1)
        }
        if lower.containsAny("chicken", "mince", "beef", "lamb", "pork", "steak", "sausage", "bacon", "ham", "prawn", "shrimp", "fish", "salmon", "tuna") {
            return (.coldGoods, .weekly, 2)
        }
        if lower.containsAny("cheese", "butter", "dip", "hummus") {
            return (.coldGoods, .fortnightly, 3)
        }
        if lower.containsAny("egg") {
            return (.coldGoods, .weekly, 4)
        }
        if lower.containsAny("frozen", "ice cream") {
            return (.coldGoods, .fortnightly, 5)
        }

        // Fresh produce — weekly
        if lower.containsAny("banana", "apple", "fruit", "grape", "berry", "strawberry", "mango", "pear", "orange", "lemon", "lime", "avocado", "watermelon", "melon", "pineapple") {
            return (.coldGoods, .weekly, 0)
        }
        if lower.containsAny("lettuce", "salad", "spinach", "rocket", "kale", "broccoli", "carrot", "celery", "cucumber", "zucchini", "capsicum", "tomato", "mushroom", "corn", "potato", "onion", "garlic", "ginger", "pumpkin", "sweet potato", "bean", "pea") {
            return (.coldGoods, .weekly, 0)
        }

        // Breakfast items
        if lower.containsAny("bread", "loaf", "sourdough", "toast", "roll", "baguette", "wrap", "tortilla", "pita") {
            return (.breakfast, .weekly, 10)
        }
        if lower.containsAny("cereal", "oat", "muesli", "granola", "weetbix", "weet-bix") {
            return (.breakfast, .fortnightly, 11)
        }
        if lower.containsAny("coffee") {
            return (.breakfast, .fortnightly, 12)
        }
        if lower.containsAny("tea") {
            return (.breakfast, .monthly, 12)
        }
        if lower.containsAny("juice", "cordial") {
            return (.breakfast, .weekly, 13)
        }
        if lower.containsAny("spread", "jam", "peanut butter", "nutella", "honey", "vegemite") {
            return (.breakfast, .monthly, 14)
        }

        // Pantry items
        if lower.containsAny("pasta", "noodle", "spaghetti", "penne", "fettuccine") {
            return (.pantry, .fortnightly, 20)
        }
        if lower.containsAny("rice") {
            return (.pantry, .fortnightly, 20)
        }
        if lower.containsAny("flour", "sugar", "baking") {
            return (.pantry, .monthly, 21)
        }
        if lower.containsAny("oil", "olive oil", "coconut oil", "vegetable oil", "vinegar") {
            return (.pantry, .monthly, 22)
        }
        if lower.containsAny("sauce", "soy sauce", "fish sauce", "ketchup", "mustard", "mayo", "dressing", "sriracha", "hot sauce", "curry paste", "stock", "broth") {
            return (.pantry, .monthly, 23)
        }
        if lower.containsAny("tin", "can", "canned", "tomatoes", "chickpea", "lentil", "kidney bean", "coconut milk", "soup") {
            return (.pantry, .monthly, 24)
        }
        if lower.containsAny("spice", "herb", "cumin", "paprika", "oregano", "basil", "thyme", "cinnamon", "turmeric", "chilli", "pepper", "salt") {
            return (.pantry, .quarterly, 25)
        }
        if lower.containsAny("nut", "almond", "cashew", "peanut", "walnut", "pistachio") {
            return (.pantry, .monthly, 26)
        }
        if lower.containsAny("chip", "crisp", "snack", "cracker", "popcorn") {
            return (.pantry, .fortnightly, 27)
        }
        if lower.containsAny("chocolate", "candy", "sweet", "lolly", "biscuit", "cookie") {
            return (.pantry, .fortnightly, 28)
        }
        if lower.containsAny("water") {
            return (.pantry, .weekly, 29)
        }
        if lower.containsAny("drink", "soda", "coke", "lemonade", "sparkling") {
            return (.pantry, .fortnightly, 29)
        }
        if lower.containsAny("wine", "beer", "alcohol", "spirit", "vodka", "gin", "rum", "whisky") {
            return (.pantry, .fortnightly, 30)
        }

        // Cleaning / household
        if lower.containsAny("toilet", "tissue", "paper towel", "kitchen roll") {
            return (.cleaning, .fortnightly, 40)
        }
        if lower.containsAny("soap", "shampoo", "conditioner", "body wash", "hand wash") {
            return (.cleaning, .monthly, 41)
        }
        if lower.containsAny("detergent", "washing", "laundry", "fabric softener") {
            return (.cleaning, .monthly, 42)
        }
        if lower.containsAny("dishwasher", "dish", "rinse aid") {
            return (.cleaning, .monthly, 43)
        }
        if lower.containsAny("cleaning", "cleaner", "spray", "disinfectant", "bleach") {
            return (.cleaning, .monthly, 44)
        }
        if lower.containsAny("sponge", "cloth", "wipe") {
            return (.cleaning, .monthly, 45)
        }
        if lower.containsAny("bin bag", "garbage", "trash bag", "rubbish") {
            return (.cleaning, .monthly, 46)
        }
        if lower.containsAny("toothpaste", "toothbrush", "dental", "floss", "mouthwash") {
            return (.cleaning, .monthly, 47)
        }
        if lower.containsAny("nappy", "nappies", "diaper") {
            return (.cleaning, .weekly, 48)
        }
        if lower.containsAny("dog food", "cat food", "pet food", "kibble", "litter") {
            return (.cleaning, .fortnightly, 49)
        }
        if lower.containsAny("medicine", "vitamin", "tablet", "pill", "panadol", "nurofen") {
            return (.cleaning, .quarterly, 50)
        }
        if lower.containsAny("sunscreen", "moisturiser", "moisturizer", "deodorant") {
            return (.cleaning, .monthly, 51)
        }
        if lower.containsAny("foil", "cling wrap", "baking paper", "glad wrap", "ziplock", "zip lock") {
            return (.cleaning, .monthly, 52)
        }

        // Default: pantry, monthly
        return (.pantry, .monthly, 25)
    }
}
