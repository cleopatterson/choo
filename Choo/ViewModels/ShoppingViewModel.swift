import Foundation

@MainActor
@Observable
final class ShoppingViewModel {
    let firestoreService: FirestoreService
    let familyId: String
    let displayName: String

    var errorMessage: String?
    var isBusy = false

    private var defaultListId: String?
    private var hasSetUpList = false

    init(firestoreService: FirestoreService, familyId: String, displayName: String) {
        self.firestoreService = firestoreService
        self.familyId = familyId
        self.displayName = displayName
        firestoreService.listenToShoppingLists(familyId: familyId)
    }

    // MARK: - Single List Setup

    func ensureDefaultList() async {
        guard !hasSetUpList else { return }
        hasSetUpList = true

        if let existing = firestoreService.shoppingLists.first {
            defaultListId = existing.id
            if let listId = existing.id {
                firestoreService.listenToShoppingItems(familyId: familyId, listId: listId)
                SharedUserContext.saveDefaultListId(listId)
            }
        } else {
            do {
                let listId = try await firestoreService.createShoppingList(
                    familyId: familyId,
                    name: "Shopping List",
                    createdBy: displayName
                )
                defaultListId = listId
                firestoreService.listenToShoppingItems(familyId: familyId, listId: listId)
                SharedUserContext.saveDefaultListId(listId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Sorted Items

    @ObservationIgnored private var _cachedSortedItems: [ShoppingItem] = []
    @ObservationIgnored private var _sortedItemsCacheKey = ""

    var sortedItems: [ShoppingItem] {
        let key = "\(firestoreService.shoppingItems.count)-\(firestoreService.shoppingItems.map { $0.sortOrder ?? -1 }.hashValue)-\(firestoreService.shoppingItems.filter(\.isChecked).count)"
        if key == _sortedItemsCacheKey && !_cachedSortedItems.isEmpty {
            return _cachedSortedItems
        }
        _cachedSortedItems = firestoreService.shoppingItems.sorted { a, b in
            (a.sortOrder ?? Int.max) < (b.sortOrder ?? Int.max)
        }
        _sortedItemsCacheKey = key
        return _cachedSortedItems
    }

    var firstHeadingId: String? {
        sortedItems.first(where: { $0.heading })?.id
    }

    // MARK: - Add Item (ALL CAPS = heading)

    private func isAllCaps(_ text: String) -> Bool {
        let letters = text.filter { $0.isLetter }
        return letters.count >= 2 && letters.allSatisfy { $0.isUppercase }
    }

    func addItem(name: String) async {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let listId = defaultListId else { return }
        errorMessage = nil

        let heading = isAllCaps(trimmed)
        let nextOrder = (firestoreService.shoppingItems.compactMap { $0.sortOrder }.max() ?? -1) + 1

        do {
            try await firestoreService.addShoppingItem(
                familyId: familyId,
                listId: listId,
                name: trimmed,
                isHeading: heading,
                sortOrder: nextOrder,
                addedBy: displayName
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func addItemsToUnsorted(names: [String]) async {
        await addItemsBefore(names: names, beforeItemId: firstHeadingId)
    }

    /// Insert one or more items before a specific item (by ID) using raw sort order.
    /// Uses `sortedItems` to avoid issues with checked-item reordering.
    func addItemsBefore(names: [String], beforeItemId: String?) async {
        guard let listId = defaultListId, !names.isEmpty else { return }
        errorMessage = nil

        let sorted = sortedItems

        // Determine base sort order
        var baseSortOrder: Int
        if let beforeId = beforeItemId,
           let idx = sorted.firstIndex(where: { $0.id == beforeId }) {
            let after = sorted[idx].sortOrder ?? 0
            if idx == 0 {
                baseSortOrder = after - names.count
            } else {
                let before = sorted[idx - 1].sortOrder ?? 0
                let gap = after - before
                if gap > names.count {
                    // Enough room — just slot them in
                    baseSortOrder = before + 1
                } else {
                    // Need to shift items from idx onward to make room
                    baseSortOrder = before + 1
                    let reordered = sorted.map { item -> ShoppingItem in
                        var m = item
                        if (m.sortOrder ?? 0) >= baseSortOrder {
                            m.sortOrder = (m.sortOrder ?? 0) + names.count
                        }
                        return m
                    }
                    do {
                        try await firestoreService.reorderShoppingItems(
                            familyId: familyId,
                            listId: listId,
                            items: reordered
                        )
                    } catch {
                        errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            // Append at end
            baseSortOrder = (sorted.last?.sortOrder ?? 0) + 1
        }

        for (offset, name) in names.enumerated() {
            let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let heading = isAllCaps(trimmed)
            do {
                try await firestoreService.addShoppingItem(
                    familyId: familyId,
                    listId: listId,
                    name: trimmed,
                    isHeading: heading,
                    sortOrder: baseSortOrder + offset,
                    addedBy: displayName
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Toggle / Delete

    func toggleItem(_ item: ShoppingItem) async {
        guard !item.heading, let itemId = item.id, let listId = defaultListId else { return }
        errorMessage = nil

        do {
            try await firestoreService.toggleShoppingItem(
                familyId: familyId,
                listId: listId,
                itemId: itemId,
                isChecked: !item.isChecked
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func renameItem(_ item: ShoppingItem, to newName: String) async {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let itemId = item.id, let listId = defaultListId else { return }
        errorMessage = nil

        do {
            try await firestoreService.updateShoppingItemName(
                familyId: familyId,
                listId: listId,
                itemId: itemId,
                name: trimmed
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteItem(_ item: ShoppingItem) async {
        guard let itemId = item.id, let listId = defaultListId else { return }
        errorMessage = nil

        do {
            try await firestoreService.deleteShoppingItem(
                familyId: familyId,
                listId: listId,
                itemId: itemId
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Sort Section (unchecked first, checked last)

    func sortSectionByChecked(headingId: String) async {
        guard let listId = defaultListId else { return }
        let sorted = sortedItems

        guard let headingIdx = sorted.firstIndex(where: { $0.id == headingId && $0.heading }) else { return }

        // Collect non-heading items in this section
        var sectionItems: [ShoppingItem] = []
        for i in (headingIdx + 1)..<sorted.count {
            if sorted[i].heading { break }
            sectionItems.append(sorted[i])
        }
        guard !sectionItems.isEmpty else { return }

        let unchecked = sectionItems.filter { !$0.isChecked }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let checked = sectionItems.filter { $0.isChecked }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        let reordered = unchecked + checked

        // Rebuild full list with reordered section
        var result = Array(sorted[0...headingIdx])
        result.append(contentsOf: reordered)
        let afterIdx = headingIdx + 1 + sectionItems.count
        if afterIdx < sorted.count {
            result.append(contentsOf: sorted[afterIdx...])
        }

        do {
            try await firestoreService.reorderShoppingItems(
                familyId: familyId,
                listId: listId,
                items: result
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Run Items (flat, no headings, sorted by aisle)

    var runItems: [ShoppingItem] {
        firestoreService.shoppingItems
            .filter { !$0.heading }
            .sorted { a, b in
                let aisle1 = a.aisleOrder ?? Int.max
                let aisle2 = b.aisleOrder ?? Int.max
                if aisle1 != aisle2 { return aisle1 < aisle2 }
                return (a.sortOrder ?? Int.max) < (b.sortOrder ?? Int.max)
            }
    }

    // MARK: - Run Stats

    var uncheckedCount: Int {
        runItems.filter { !$0.isChecked }.count
    }

    var checkedCount: Int {
        runItems.filter { $0.isChecked }.count
    }

    // MARK: - Done Flow

    func completeDoneFlow() async {
        guard let listId = defaultListId else { return }
        errorMessage = nil

        do {
            let deleted = try await firestoreService.deleteCheckedShoppingItems(familyId: familyId, listId: listId)

            // Reset cadence clocks for supply-linked items
            for item in deleted {
                if let supplyId = item.supplyItemId {
                    try? await firestoreService.markSupplyPurchased(familyId: familyId, itemId: supplyId)
                }
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Reorder

    func moveItems(from source: IndexSet, to destination: Int) {
        var reordered = sortedItems
        reordered.move(fromOffsets: source, toOffset: destination)

        let snapshot = reordered
        guard let listId = defaultListId else { return }
        Task {
            do {
                try await firestoreService.reorderShoppingItems(
                    familyId: familyId,
                    listId: listId,
                    items: snapshot
                )
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
