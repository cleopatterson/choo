import Foundation
import FirebaseFirestore
import FirebaseMessaging
import UIKit

final class PushNotificationService {
    static let shared = PushNotificationService()

    private let db = Firestore.firestore()
    private var currentUID: String?

    private init() {}

    private var deviceId: String {
        UIDevice.current.identifierForVendor?.uuidString ?? "unknown"
    }

    // MARK: - Token Management

    func saveFCMToken(uid: String) {
        currentUID = uid
        guard let token = Messaging.messaging().fcmToken else { return }
        let field = "fcmTokens.\(deviceId)"
        db.collection("users").document(uid).updateData([field: token]) { error in
            if let error {
                print("Failed to save FCM token: \(error.localizedDescription)")
            }
        }
    }

    func removeFCMToken(uid: String) {
        let field = "fcmTokens.\(deviceId)"
        db.collection("users").document(uid).updateData([
            field: FieldValue.delete()
        ]) { error in
            if let error {
                print("Failed to remove FCM token: \(error.localizedDescription)")
            }
        }
        currentUID = nil
    }

    func handleTokenRefresh(_ token: String) {
        guard let uid = currentUID else { return }
        let field = "fcmTokens.\(deviceId)"
        db.collection("users").document(uid).updateData([field: token]) { error in
            if let error {
                print("Failed to update FCM token: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Notification Preferences

    func updatePreferences(_ prefs: NotificationPreferences, uid: String) async throws {
        try await db.collection("users").document(uid).updateData([
            "notificationPreferences": [
                "eventCreated": prefs.isEventCreatedEnabled,
                "eventUpdated": prefs.isEventUpdatedEnabled,
                "eventDeleted": prefs.isEventDeletedEnabled,
                "shoppingChanges": prefs.isShoppingChangesEnabled,
            ]
        ])
    }
}
