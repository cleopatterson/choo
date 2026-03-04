import Foundation
import FirebaseFirestore

@Observable
final class FirestoreService {
    private let db = Firestore.firestore()

    private var familyListener: ListenerRegistration?
    private var membersListener: ListenerRegistration?
    private var shoppingListsListener: ListenerRegistration?
    private var shoppingItemsListener: ListenerRegistration?
    private var eventsListener: ListenerRegistration?
    private var notesListener: ListenerRegistration?
    private var dependentsListener: ListenerRegistration?
    private var mealPlanListener: ListenerRegistration?
    private var lastWeekMealPlanListener: ListenerRegistration?
    private var recipesListener: ListenerRegistration?
    private var exerciseCategoriesListener: ListenerRegistration?
    private var exercisePlanListener: ListenerRegistration?
    private var choreCategoriesListener: ListenerRegistration?
    private var choresPlanListener: ListenerRegistration?

    var currentFamily: Family?
    var familyMembers: [UserProfile] = []
    var dependents: [FamilyMember] = []
    var shoppingLists: [ShoppingList] = []
    var shoppingItems: [ShoppingItem] = []
    var events: [FamilyEvent] = []
    /// Incremented on every events snapshot change — cheap alternative to hashing all event IDs.
    var eventsVersion: Int = 0
    var notes: [Note] = []
    var currentMealPlan: MealPlan?
    var lastWeekMealPlan: MealPlan?
    var recipes: [Recipe] = []
    var exerciseCategories: [ExerciseCategory] = []
    var currentExercisePlan: ExercisePlan?
    var choreCategories: [ChoreCategory] = []
    var currentChoresPlan: ChoresPlan?

    deinit {
        familyListener?.remove()
        membersListener?.remove()
        shoppingListsListener?.remove()
        shoppingItemsListener?.remove()
        eventsListener?.remove()
        notesListener?.remove()
        dependentsListener?.remove()
        mealPlanListener?.remove()
        lastWeekMealPlanListener?.remove()
        recipesListener?.remove()
        exerciseCategoriesListener?.remove()
        exercisePlanListener?.remove()
        choreCategoriesListener?.remove()
        choresPlanListener?.remove()
    }

    // MARK: - Invite Code Generation

    static func generateInviteCode() -> String {
        // No ambiguous chars: 0/O, 1/I/L removed
        let chars = Array("ABCDEFGHJKMNPQRSTUVWXYZ23456789")
        return String((0..<6).map { _ in chars.randomElement()! })
    }

    // MARK: - User Profile

    func createUserProfile(_ profile: UserProfile, uid: String) async throws {
        try db.collection("users").document(uid).setData(from: profile)
    }

    func getUserProfile(uid: String) async throws -> UserProfile? {
        let snapshot = try await db.collection("users").document(uid).getDocument()
        return try? snapshot.data(as: UserProfile.self)
    }

    func updateUserFamilyId(uid: String, familyId: String, role: UserRole) async throws {
        try await db.collection("users").document(uid).updateData([
            "familyId": familyId,
            "role": role.rawValue
        ])
    }

    // MARK: - Family CRUD

    func createFamily(name: String, adminUID: String) async throws -> String {
        let inviteCode = Self.generateInviteCode()
        let family = Family(
            name: name,
            adminUID: adminUID,
            memberUIDs: [adminUID],
            inviteCode: inviteCode,
            inviteCodeExpiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60)
        )
        let docRef = try db.collection("families").addDocument(from: family)
        return docRef.documentID
    }

    func lookupFamilyByInviteCode(_ code: String) async throws -> Family? {
        let snapshot = try await db.collection("families")
            .whereField("inviteCode", isEqualTo: code.uppercased())
            .limit(to: 1)
            .getDocuments()

        guard let doc = snapshot.documents.first else { return nil }
        return try doc.data(as: Family.self)
    }

    func joinFamily(familyId: String, uid: String) async throws {
        try await db.collection("families").document(familyId).updateData([
            "memberUIDs": FieldValue.arrayUnion([uid])
        ])
    }

    func regenerateInviteCode(familyId: String) async throws -> String {
        let newCode = Self.generateInviteCode()
        let newExpiry = Date().addingTimeInterval(7 * 24 * 60 * 60)
        try await db.collection("families").document(familyId).updateData([
            "inviteCode": newCode,
            "inviteCodeExpiresAt": Timestamp(date: newExpiry)
        ])
        return newCode
    }

    // MARK: - Real-time Listeners

    func listenToFamily(familyId: String) {
        familyListener?.remove()
        familyListener = db.collection("families").document(familyId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot, error == nil else { return }
                self?.currentFamily = try? snapshot.data(as: Family.self)

                if let memberUIDs = self?.currentFamily?.memberUIDs {
                    self?.listenToMembers(uids: memberUIDs)
                }
            }
        listenToDependents(familyId: familyId)
    }

    private func listenToMembers(uids: [String]) {
        membersListener?.remove()
        guard !uids.isEmpty else {
            familyMembers = []
            return
        }
        membersListener = db.collection("users")
            .whereField(FieldPath.documentID(), in: uids)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot, error == nil else { return }
                self?.familyMembers = snapshot.documents.compactMap {
                    try? $0.data(as: UserProfile.self)
                }
            }
    }

    func stopListening() {
        familyListener?.remove()
        membersListener?.remove()
        shoppingListsListener?.remove()
        shoppingItemsListener?.remove()
        eventsListener?.remove()
        notesListener?.remove()
        dependentsListener?.remove()
        mealPlanListener?.remove()
        lastWeekMealPlanListener?.remove()
        recipesListener?.remove()
        familyListener = nil
        membersListener = nil
        shoppingListsListener = nil
        shoppingItemsListener = nil
        eventsListener = nil
        notesListener = nil
        dependentsListener = nil
        mealPlanListener = nil
        lastWeekMealPlanListener = nil
        recipesListener = nil
        exerciseCategoriesListener?.remove()
        exercisePlanListener?.remove()
        exerciseCategoriesListener = nil
        exercisePlanListener = nil
        currentFamily = nil
        familyMembers = []
        dependents = []
        shoppingLists = []
        shoppingItems = []
        events = []
        notes = []
        currentMealPlan = nil
        lastWeekMealPlan = nil
        recipes = []
        exerciseCategories = []
        currentExercisePlan = nil
        choreCategoriesListener?.remove()
        choresPlanListener?.remove()
        choreCategoriesListener = nil
        choresPlanListener = nil
        choreCategories = []
        currentChoresPlan = nil
    }

    // MARK: - Shopping Lists

    func listenToShoppingLists(familyId: String) {
        shoppingListsListener?.remove()
        shoppingLists = []
        shoppingListsListener = db.collection("families").document(familyId)
            .collection("shoppingLists")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added:
                        if let list = try? change.document.data(as: ShoppingList.self),
                           !self.shoppingLists.contains(where: { $0.id == list.id }) {
                            self.shoppingLists.append(list)
                        }
                    case .modified:
                        if let list = try? change.document.data(as: ShoppingList.self),
                           let idx = self.shoppingLists.firstIndex(where: { $0.id == list.id }) {
                            self.shoppingLists[idx] = list
                        }
                    case .removed:
                        self.shoppingLists.removeAll { $0.id == change.document.documentID }
                    }
                }
            }
    }

    @discardableResult
    func createShoppingList(familyId: String, name: String, createdBy: String) async throws -> String {
        let list = ShoppingList(
            familyId: familyId,
            name: name,
            createdBy: createdBy,
            createdAt: Date()
        )
        let docRef = try db.collection("families").document(familyId)
            .collection("shoppingLists")
            .addDocument(from: list)
        return docRef.documentID
    }

    func deleteShoppingList(familyId: String, listId: String) async throws {
        try await db.collection("families").document(familyId)
            .collection("shoppingLists").document(listId)
            .delete()
    }

    // MARK: - Shopping Items

    func listenToShoppingItems(familyId: String, listId: String) {
        shoppingItemsListener?.remove()
        shoppingItems = []
        shoppingItemsListener = db.collection("families").document(familyId)
            .collection("shoppingLists").document(listId)
            .collection("items")
            .order(by: "createdAt")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added:
                        if let item = try? change.document.data(as: ShoppingItem.self),
                           !self.shoppingItems.contains(where: { $0.id == item.id }) {
                            self.shoppingItems.append(item)
                        }
                    case .modified:
                        if let item = try? change.document.data(as: ShoppingItem.self),
                           let idx = self.shoppingItems.firstIndex(where: { $0.id == item.id }) {
                            self.shoppingItems[idx] = item
                        }
                    case .removed:
                        self.shoppingItems.removeAll { $0.id == change.document.documentID }
                    }
                }
            }
    }

    func addShoppingItem(familyId: String, listId: String, name: String, isHeading: Bool, sortOrder: Int, addedBy: String) async throws {
        let item = ShoppingItem(
            listId: listId,
            name: name,
            isChecked: false,
            addedBy: addedBy,
            createdAt: Date(),
            isHeading: isHeading,
            sortOrder: sortOrder
        )
        _ = try db.collection("families").document(familyId)
            .collection("shoppingLists").document(listId)
            .collection("items")
            .addDocument(from: item)
    }

    func reorderShoppingItems(familyId: String, listId: String, items: [ShoppingItem]) async throws {
        let batch = db.batch()
        for (index, item) in items.enumerated() {
            guard let itemId = item.id else { continue }
            let ref = db.collection("families").document(familyId)
                .collection("shoppingLists").document(listId)
                .collection("items").document(itemId)
            batch.updateData(["sortOrder": index], forDocument: ref)
        }
        try await batch.commit()
    }

    func toggleShoppingItem(familyId: String, listId: String, itemId: String, isChecked: Bool) async throws {
        try await db.collection("families").document(familyId)
            .collection("shoppingLists").document(listId)
            .collection("items").document(itemId)
            .updateData(["isChecked": isChecked])
    }

    func updateShoppingItemName(familyId: String, listId: String, itemId: String, name: String) async throws {
        try await db.collection("families").document(familyId)
            .collection("shoppingLists").document(listId)
            .collection("items").document(itemId)
            .updateData(["name": name])
    }

    func deleteShoppingItem(familyId: String, listId: String, itemId: String) async throws {
        try await db.collection("families").document(familyId)
            .collection("shoppingLists").document(listId)
            .collection("items").document(itemId)
            .delete()
    }

    func stopListeningToShoppingItems() {
        shoppingItemsListener?.remove()
        shoppingItemsListener = nil
        shoppingItems = []
    }

    // MARK: - Events

    func listenToEvents(familyId: String) {
        eventsListener?.remove()
        events = []
        // Limit to events from 6 months ago onward to avoid unbounded growth
        let sixMonthsAgo = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()
        eventsListener = db.collection("families").document(familyId)
            .collection("events")
            .whereField("startDate", isGreaterThan: Timestamp(date: sixMonthsAgo))
            .order(by: "startDate")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added:
                        if let event = try? change.document.data(as: FamilyEvent.self),
                           !self.events.contains(where: { $0.id == event.id }) {
                            self.events.append(event)
                        }
                    case .modified:
                        if let event = try? change.document.data(as: FamilyEvent.self),
                           let idx = self.events.firstIndex(where: { $0.id == event.id }) {
                            self.events[idx] = event
                        }
                    case .removed:
                        self.events.removeAll { $0.id == change.document.documentID }
                    }
                }
                self.eventsVersion += 1
            }
    }

    func createEvent(familyId: String, title: String, startDate: Date, endDate: Date, createdBy: String, attendeeUIDs: [String] = [], isAllDay: Bool? = nil, location: String? = nil, recurrenceFrequency: String? = nil, recurrenceEndDate: Date? = nil, reminderEnabled: Bool? = nil, isBill: Bool? = nil, amount: Double? = nil, note: String? = nil, lastModifiedByUID: String? = nil, isTodo: Bool? = nil, todoEmoji: String? = nil) async throws {
        let event = FamilyEvent(
            familyId: familyId,
            title: title,
            startDate: startDate,
            endDate: endDate,
            createdBy: createdBy,
            attendeeUIDs: attendeeUIDs,
            isAllDay: isAllDay,
            location: location,
            recurrenceFrequency: recurrenceFrequency,
            recurrenceEndDate: recurrenceEndDate,
            reminderEnabled: reminderEnabled,
            isBill: isBill,
            amount: amount,
            note: note,
            lastModifiedByUID: lastModifiedByUID,
            isTodo: isTodo,
            todoEmoji: todoEmoji
        )
        _ = try db.collection("families").document(familyId)
            .collection("events")
            .addDocument(from: event)
    }

    func updateEvent(familyId: String, event: FamilyEvent) async throws {
        guard let eventId = event.id else { return }
        try db.collection("families").document(familyId)
            .collection("events").document(eventId)
            .setData(from: event, merge: true)
    }

    func updateEventAttendees(familyId: String, eventId: String, attendeeUIDs: [String]) async throws {
        try await db.collection("families").document(familyId)
            .collection("events").document(eventId)
            .updateData(["attendeeUIDs": attendeeUIDs])
    }

    func deleteEvent(familyId: String, eventId: String) async throws {
        try await db.collection("families").document(familyId)
            .collection("events").document(eventId)
            .delete()
    }

    // MARK: - Dependents (non-app family members)

    private func listenToDependents(familyId: String) {
        dependentsListener?.remove()
        dependents = []
        dependentsListener = db.collection("families").document(familyId)
            .collection("dependents")
            .order(by: "displayName")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added:
                        if let dep = try? change.document.data(as: FamilyMember.self),
                           !self.dependents.contains(where: { $0.id == dep.id }) {
                            self.dependents.append(dep)
                        }
                    case .modified:
                        if let dep = try? change.document.data(as: FamilyMember.self),
                           let idx = self.dependents.firstIndex(where: { $0.id == dep.id }) {
                            self.dependents[idx] = dep
                        }
                    case .removed:
                        self.dependents.removeAll { $0.id == change.document.documentID }
                    }
                }
            }
    }

    func addDependent(familyId: String, name: String, type: FamilyMember.MemberType, addedBy: String) async throws {
        let member = FamilyMember(familyId: familyId, displayName: name, type: type, addedBy: addedBy)
        _ = try db.collection("families").document(familyId)
            .collection("dependents")
            .addDocument(from: member)
    }

    func updateDependent(familyId: String, dependentId: String, displayName: String, type: FamilyMember.MemberType, emoji: String? = nil) async throws {
        var data: [String: Any] = ["displayName": displayName, "type": type.rawValue]
        if let emoji, !emoji.isEmpty {
            data["emoji"] = emoji
        } else {
            data["emoji"] = FieldValue.delete()
        }
        try await db.collection("families").document(familyId)
            .collection("dependents").document(dependentId)
            .updateData(data)
    }

    func deleteDependent(familyId: String, dependentId: String) async throws {
        try await db.collection("families").document(familyId)
            .collection("dependents").document(dependentId)
            .delete()
    }

    // MARK: - Notes

    func listenToNotes(familyId: String) {
        notesListener?.remove()
        notes = []
        notesListener = db.collection("families").document(familyId)
            .collection("notes")
            .order(by: "updatedAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added:
                        if let note = try? change.document.data(as: Note.self),
                           !self.notes.contains(where: { $0.id == note.id }) {
                            self.notes.append(note)
                        }
                    case .modified:
                        if let note = try? change.document.data(as: Note.self),
                           let idx = self.notes.firstIndex(where: { $0.id == note.id }) {
                            self.notes[idx] = note
                        }
                    case .removed:
                        self.notes.removeAll { $0.id == change.document.documentID }
                    }
                }
            }
    }

    func createNote(familyId: String, title: String, content: String, createdBy: String, isList: Bool? = nil) async throws {
        let now = Date()
        let note = Note(
            familyId: familyId,
            title: title,
            content: content,
            createdBy: createdBy,
            createdAt: now,
            updatedAt: now,
            isList: isList
        )
        _ = try db.collection("families").document(familyId)
            .collection("notes")
            .addDocument(from: note)
    }

    func updateNote(familyId: String, noteId: String, title: String, content: String) async throws {
        try await db.collection("families").document(familyId)
            .collection("notes").document(noteId)
            .updateData([
                "title": title,
                "content": content,
                "updatedAt": Timestamp(date: Date())
            ])
    }

    func deleteNote(familyId: String, noteId: String) async throws {
        try await db.collection("families").document(familyId)
            .collection("notes").document(noteId)
            .delete()
    }

    // MARK: - Meal Plans

    func listenToMealPlan(familyId: String, weekStart: Date) {
        mealPlanListener?.remove()
        let docId = MealPlan.docId(for: weekStart)
        mealPlanListener = db.collection("families").document(familyId)
            .collection("mealPlans").document(docId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot, error == nil else { return }
                self?.currentMealPlan = try? snapshot.data(as: MealPlan.self)
            }
    }

    func saveMealPlan(familyId: String, mealPlan: MealPlan) async throws {
        let docId = MealPlan.docId(for: mealPlan.weekStart)
        try db.collection("families").document(familyId)
            .collection("mealPlans").document(docId)
            .setData(from: mealPlan, merge: true)
    }

    func listenToLastWeekMealPlan(familyId: String, weekStart: Date) {
        lastWeekMealPlanListener?.remove()
        let docId = MealPlan.docId(for: weekStart)
        lastWeekMealPlanListener = db.collection("families").document(familyId)
            .collection("mealPlans").document(docId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot, error == nil else { return }
                self?.lastWeekMealPlan = try? snapshot.data(as: MealPlan.self)
            }
    }

    func stopListeningToMealPlan() {
        mealPlanListener?.remove()
        mealPlanListener = nil
        currentMealPlan = nil
        lastWeekMealPlanListener?.remove()
        lastWeekMealPlanListener = nil
        lastWeekMealPlan = nil
    }

    // MARK: - Recipes

    func listenToRecipes(familyId: String) {
        recipesListener?.remove()
        recipes = []
        recipesListener = db.collection("families").document(familyId)
            .collection("recipes")
            .order(by: "name")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added:
                        if let recipe = try? change.document.data(as: Recipe.self),
                           !self.recipes.contains(where: { $0.id == recipe.id }) {
                            self.recipes.append(recipe)
                        }
                    case .modified:
                        if let recipe = try? change.document.data(as: Recipe.self),
                           let idx = self.recipes.firstIndex(where: { $0.id == recipe.id }) {
                            self.recipes[idx] = recipe
                        }
                    case .removed:
                        self.recipes.removeAll { $0.id == change.document.documentID }
                    }
                }
            }
    }

    func seedDefaultRecipes(familyId: String) async throws {
        let familyRef = db.collection("families").document(familyId)
        let recipesRef = familyRef.collection("recipes")
        let snapshot = try await recipesRef.whereField("isDefault", isEqualTo: true).getDocuments()

        // Skip if default count already matches
        guard snapshot.documents.count != Recipe.defaults.count else { return }

        // Delete stale defaults
        let deleteBatch = db.batch()
        for doc in snapshot.documents {
            deleteBatch.deleteDocument(doc.reference)
        }
        try await deleteBatch.commit()

        // Clear recipe-generated shopping items
        if let listId = shoppingLists.first?.id {
            let itemsRef = familyRef.collection("shoppingLists").document(listId).collection("items")
            let recipeItems = try await itemsRef.whereField("sourceRecipeId", isGreaterThan: "").getDocuments()
            let cleanBatch = db.batch()
            for doc in recipeItems.documents {
                cleanBatch.deleteDocument(doc.reference)
            }
            try await cleanBatch.commit()
        }

        // Clear meal plans
        let plansSnapshot = try await familyRef.collection("mealPlans").getDocuments()
        let plansBatch = db.batch()
        for doc in plansSnapshot.documents {
            plansBatch.deleteDocument(doc.reference)
        }
        try await plansBatch.commit()

        // Seed fresh defaults
        let seedBatch = db.batch()
        for recipe in Recipe.defaults {
            let ref = recipesRef.document()
            try seedBatch.setData(from: recipe, forDocument: ref)
        }
        try await seedBatch.commit()
    }

    func stopListeningToRecipes() {
        recipesListener?.remove()
        recipesListener = nil
        recipes = []
    }

    func updateRecipe(familyId: String, recipe: Recipe) async throws {
        guard let recipeId = recipe.id else { return }
        try db.collection("families").document(familyId)
            .collection("recipes").document(recipeId)
            .setData(from: recipe, merge: true)
    }

    func addRecipe(familyId: String, recipe: Recipe) async throws -> Recipe {
        let ref = try db.collection("families").document(familyId)
            .collection("recipes")
            .addDocument(from: recipe)
        var saved = recipe
        saved.id = ref.documentID
        return saved
    }

    func deleteRecipe(familyId: String, recipeId: String) async throws {
        try await db.collection("families").document(familyId)
            .collection("recipes").document(recipeId)
            .delete()
    }

    // MARK: - Recipe Shopping Items

    func addShoppingItemsFromRecipeBatch(familyId: String, listId: String, items: [(name: String, quantity: String?, sortOrder: Int)], addedBy: String, sourceRecipeId: String) async throws {
        let batch = db.batch()
        let collRef = db.collection("families").document(familyId)
            .collection("shoppingLists").document(listId)
            .collection("items")
        for item in items {
            let displayName = item.quantity != nil ? "\(item.name) (\(item.quantity!))" : item.name
            let shoppingItem = ShoppingItem(
                listId: listId,
                name: displayName,
                isChecked: false,
                addedBy: addedBy,
                createdAt: Date(),
                isHeading: false,
                sortOrder: item.sortOrder,
                sourceRecipeId: sourceRecipeId
            )
            let docRef = collRef.document()
            try batch.setData(from: shoppingItem, forDocument: docRef)
        }
        try await batch.commit()
    }

    func addShoppingItemFromRecipe(familyId: String, listId: String, name: String, quantity: String?, sortOrder: Int, addedBy: String, sourceRecipeId: String) async throws {
        let item = ShoppingItem(
            listId: listId,
            name: quantity != nil ? "\(name) (\(quantity!))" : name,
            isChecked: false,
            addedBy: addedBy,
            createdAt: Date(),
            isHeading: false,
            sortOrder: sortOrder,
            sourceRecipeId: sourceRecipeId
        )
        _ = try db.collection("families").document(familyId)
            .collection("shoppingLists").document(listId)
            .collection("items")
            .addDocument(from: item)
    }

    func deleteShoppingItemsByRecipe(familyId: String, listId: String, recipeId: String) async throws {
        let snapshot = try await db.collection("families").document(familyId)
            .collection("shoppingLists").document(listId)
            .collection("items")
            .whereField("sourceRecipeId", isEqualTo: recipeId)
            .getDocuments()

        let batch = db.batch()
        for doc in snapshot.documents {
            batch.deleteDocument(doc.reference)
        }
        try await batch.commit()
    }

    // MARK: - Exercise Categories

    func listenToExerciseCategories(familyId: String, userId: String) {
        exerciseCategoriesListener?.remove()
        exerciseCategories = []
        exerciseCategoriesListener = db.collection("families").document(familyId)
            .collection("exerciseData").document(userId)
            .collection("categories")
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added:
                        if let cat = try? change.document.data(as: ExerciseCategory.self),
                           !self.exerciseCategories.contains(where: { $0.id == cat.id }) {
                            self.exerciseCategories.append(cat)
                        }
                    case .modified:
                        if let cat = try? change.document.data(as: ExerciseCategory.self),
                           let idx = self.exerciseCategories.firstIndex(where: { $0.id == cat.id }) {
                            self.exerciseCategories[idx] = cat
                        }
                    case .removed:
                        self.exerciseCategories.removeAll { $0.id == change.document.documentID }
                    }
                }
            }
    }

    func saveExerciseCategory(familyId: String, userId: String, category: ExerciseCategory) async throws {
        if let catId = category.id {
            try db.collection("families").document(familyId)
                .collection("exerciseData").document(userId)
                .collection("categories").document(catId)
                .setData(from: category, merge: true)
        } else {
            _ = try db.collection("families").document(familyId)
                .collection("exerciseData").document(userId)
                .collection("categories")
                .addDocument(from: category)
        }
    }

    func deleteExerciseCategory(familyId: String, userId: String, categoryId: String) async throws {
        try await db.collection("families").document(familyId)
            .collection("exerciseData").document(userId)
            .collection("categories").document(categoryId)
            .delete()
    }

    func seedDefaultExerciseCategories(familyId: String, userId: String) async throws {
        let ref = db.collection("families").document(familyId)
            .collection("exerciseData").document(userId)
            .collection("categories")
        let snapshot = try await ref.limit(to: 1).getDocuments()
        guard snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        for category in ExerciseCategory.defaults {
            let docRef = ref.document()
            try batch.setData(from: category, forDocument: docRef)
        }
        try await batch.commit()
    }

    // MARK: - Exercise Plans

    func listenToExercisePlan(familyId: String, userId: String, weekStart: Date) {
        exercisePlanListener?.remove()
        let docId = ExercisePlan.docId(for: weekStart)
        exercisePlanListener = db.collection("families").document(familyId)
            .collection("exerciseData").document(userId)
            .collection("weekPlans").document(docId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot, error == nil else { return }
                self?.currentExercisePlan = try? snapshot.data(as: ExercisePlan.self)
            }
    }

    func saveExercisePlan(familyId: String, userId: String, plan: ExercisePlan) async throws {
        let docId = ExercisePlan.docId(for: plan.weekStart)
        try db.collection("families").document(familyId)
            .collection("exerciseData").document(userId)
            .collection("weekPlans").document(docId)
            .setData(from: plan, merge: true)
    }

    func stopListeningToExercise() {
        exerciseCategoriesListener?.remove()
        exercisePlanListener?.remove()
        exerciseCategoriesListener = nil
        exercisePlanListener = nil
        exerciseCategories = []
        currentExercisePlan = nil
    }

    // MARK: - Chore Categories

    func listenToChoreCategories(familyId: String) {
        choreCategoriesListener?.remove()
        choreCategories = []
        choreCategoriesListener = db.collection("families").document(familyId)
            .collection("choresData").document("shared")
            .collection("categories")
            .order(by: "sortOrder")
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot, error == nil else { return }
                for change in snapshot.documentChanges {
                    switch change.type {
                    case .added:
                        if let cat = try? change.document.data(as: ChoreCategory.self),
                           !self.choreCategories.contains(where: { $0.id == cat.id }) {
                            self.choreCategories.append(cat)
                        }
                    case .modified:
                        if let cat = try? change.document.data(as: ChoreCategory.self),
                           let idx = self.choreCategories.firstIndex(where: { $0.id == cat.id }) {
                            self.choreCategories[idx] = cat
                        }
                    case .removed:
                        self.choreCategories.removeAll { $0.id == change.document.documentID }
                    }
                }
            }
    }

    func saveChoreCategory(familyId: String, category: ChoreCategory) async throws {
        if let catId = category.id {
            try db.collection("families").document(familyId)
                .collection("choresData").document("shared")
                .collection("categories").document(catId)
                .setData(from: category, merge: true)
        } else {
            _ = try db.collection("families").document(familyId)
                .collection("choresData").document("shared")
                .collection("categories")
                .addDocument(from: category)
        }
    }

    func deleteChoreCategory(familyId: String, categoryId: String) async throws {
        try await db.collection("families").document(familyId)
            .collection("choresData").document("shared")
            .collection("categories").document(categoryId)
            .delete()
    }

    func seedDefaultChoreCategories(familyId: String) async throws {
        let ref = db.collection("families").document(familyId)
            .collection("choresData").document("shared")
            .collection("categories")
        let snapshot = try await ref.limit(to: 1).getDocuments()
        guard snapshot.documents.isEmpty else { return }

        let batch = db.batch()
        for category in ChoreCategory.defaults {
            let docRef = ref.document()
            try batch.setData(from: category, forDocument: docRef)
        }
        try await batch.commit()
    }

    // MARK: - Chores Plans

    func listenToChoresPlan(familyId: String, weekStart: Date) {
        choresPlanListener?.remove()
        let docId = ChoresPlan.docId(for: weekStart)
        choresPlanListener = db.collection("families").document(familyId)
            .collection("choresData").document("shared")
            .collection("weekPlans").document(docId)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let snapshot, error == nil else { return }
                self?.currentChoresPlan = try? snapshot.data(as: ChoresPlan.self)
            }
    }

    func saveChoresPlan(familyId: String, plan: ChoresPlan) async throws {
        let docId = ChoresPlan.docId(for: plan.weekStart)
        try db.collection("families").document(familyId)
            .collection("choresData").document("shared")
            .collection("weekPlans").document(docId)
            .setData(from: plan, merge: true)
    }

    func stopListeningToChores() {
        choreCategoriesListener?.remove()
        choresPlanListener?.remove()
        choreCategoriesListener = nil
        choresPlanListener = nil
        choreCategories = []
        currentChoresPlan = nil
    }
}
