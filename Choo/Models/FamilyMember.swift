import Foundation
import FirebaseFirestore

struct FamilyMember: Codable, Identifiable {
    @DocumentID var id: String?
    var familyId: String
    var displayName: String
    var type: MemberType
    var addedBy: String
    var emoji: String?

    enum MemberType: String, Codable {
        case person
        case pet
    }
}

/// Unified representation for both app users and non-app dependents (kids, pets).
struct AnyFamilyMember: Identifiable {
    let id: String
    let displayName: String
    let isAppUser: Bool
    var emoji: String? = nil
}
