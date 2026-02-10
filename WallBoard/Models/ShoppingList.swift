import Foundation
import FirebaseFirestore

// Phase 2 stub
struct ShoppingList: Codable, Identifiable {
    @DocumentID var id: String?
    var familyId: String
    var name: String
    var createdBy: String
}
