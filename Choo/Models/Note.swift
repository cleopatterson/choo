import Foundation
import FirebaseFirestore

struct Note: Codable, Identifiable {
    @DocumentID var id: String?
    var familyId: String
    var title: String
    var content: String
    var createdBy: String
    var createdAt: Date
    var updatedAt: Date
    var isList: Bool?
}
