import Foundation
import FirebaseFirestore

struct Family: Codable, Identifiable {
    @DocumentID var id: String?
    var name: String
    var adminUID: String
    var memberUIDs: [String]
    var inviteCode: String
    var inviteCodeExpiresAt: Date

    var isInviteCodeExpired: Bool {
        inviteCodeExpiresAt < Date()
    }
}
