import Foundation
import FirebaseFirestore

struct ShoppingItem: Codable, Identifiable {
    @DocumentID var id: String?
    var listId: String
    var name: String
    var isChecked: Bool
    var addedBy: String
    var createdAt: Date
    // New fields — optional for backward compat with existing Firestore docs
    var isHeading: Bool?
    var sortOrder: Int?
    var sourceRecipeId: String?  // non-nil = auto-generated from recipe

    var heading: Bool { isHeading ?? false }
}
