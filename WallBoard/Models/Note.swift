import Foundation
import FirebaseFirestore

// Phase 2 stub
struct Note: Codable, Identifiable {
    @DocumentID var id: String?
    var familyId: String
    var title: String
    var content: String
    var createdBy: String
    var updatedAt: Date
}
