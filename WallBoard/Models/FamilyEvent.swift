import Foundation
import FirebaseFirestore

// Phase 2 stub
struct FamilyEvent: Codable, Identifiable {
    @DocumentID var id: String?
    var familyId: String
    var title: String
    var startDate: Date
    var endDate: Date
    var createdBy: String
}
