import Foundation
import FirebaseFirestore

enum ShoppingItemSource: String, Codable {
    case manual
    case cadence   // auto-added from supply cadence
    case meal      // added from recipe ingredients
}

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
    var source: ShoppingItemSource?
    var cadenceTag: String?      // e.g. "Weekly", "Due"
    var aisleOrder: Int?
    var supplyItemId: String?    // links back to SupplyItem for cadence reset

    var heading: Bool { isHeading ?? false }
    var itemSource: ShoppingItemSource { source ?? .manual }
}
