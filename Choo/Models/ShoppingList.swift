import Foundation
import FirebaseFirestore

struct ShoppingList: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    var familyId: String
    var name: String
    var createdBy: String
    var createdAt: Date
}
