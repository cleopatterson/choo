import Foundation
import FirebaseFirestore

enum UserRole: String, Codable {
    case admin
    case member
}

struct UserProfile: Codable, Identifiable {
    @DocumentID var id: String?
    var email: String
    var displayName: String
    var familyId: String?
    var role: UserRole
    var fcmTokens: [String: String]?
    var notificationPreferences: NotificationPreferences?
}
