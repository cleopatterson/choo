import Foundation
import FirebaseFirestore

// Phase 2 stub
struct ShoppingItem: Codable, Identifiable {
    @DocumentID var id: String?
    var listId: String
    var name: String
    var isChecked: Bool
    var addedBy: String
}
