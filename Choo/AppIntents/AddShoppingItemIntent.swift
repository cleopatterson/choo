import AppIntents
import FirebaseFirestore

struct AddShoppingItemIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Shopping Item"
    static var description: IntentDescription = "Add an item to your Choo shopping list"

    @Parameter(title: "Item Name")
    var itemName: String

    func perform() async throws -> some IntentResult & ProvidesDialog {
        guard SharedUserContext.isLoggedIn,
              let familyId = SharedUserContext.familyId,
              let listId = SharedUserContext.defaultShoppingListId,
              let displayName = SharedUserContext.displayName else {
            return .result(dialog: "Please open Choo and sign in first.")
        }

        let db = Firestore.firestore()
        let data: [String: Any] = [
            "listId": listId,
            "name": itemName,
            "isChecked": false,
            "addedBy": displayName,
            "createdAt": Timestamp(date: Date()),
            "isHeading": false,
            "sortOrder": -1
        ]

        try await db.collection("families").document(familyId)
            .collection("shoppingLists").document(listId)
            .collection("items")
            .addDocument(data: data)

        return .result(dialog: "Added \(itemName) to your shopping list.")
    }
}
