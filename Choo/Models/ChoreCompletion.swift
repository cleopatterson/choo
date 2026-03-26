import Foundation
import FirebaseFirestore

struct ChoreCompletion: Codable, Identifiable {
    @DocumentID var id: String?
    var choreTypeId: String
    var choreTypeName: String
    var categoryName: String
    var completedBy: String
    var completedDate: Date
    var familyId: String
}
