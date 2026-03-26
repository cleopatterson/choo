import UIKit
import FirebaseMessaging

class AppDelegate: NSObject, UIApplicationDelegate, MessagingDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        print("[Push] AppDelegate didFinishLaunching")
        Messaging.messaging().delegate = self
        UNUserNotificationCenter.current().delegate = self
        application.registerForRemoteNotifications()
        return true
    }

    // MARK: - APNs Token

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("[Push] APNs token received (\(deviceToken.count) bytes)")
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("[Push] APNs registration FAILED: \(error.localizedDescription)")
    }

    // MARK: - FCM Token Refresh

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        print("FCM token: \(fcmToken)")
        PushNotificationService.shared.handleTokenRefresh(fcmToken)
    }

    // MARK: - Foreground Notification Display

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    // MARK: - Notification Tap

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo

        // Local notifications store eventDate as TimeInterval directly;
        // push notifications from FCM send it as a String in the data payload.
        let timestamp: TimeInterval?
        if let t = userInfo["eventDate"] as? TimeInterval {
            timestamp = t
        } else if let s = userInfo["eventDate"] as? String, let t = Double(s) {
            timestamp = t
        } else {
            timestamp = nil
        }

        if let timestamp {
            let date = Date(timeIntervalSince1970: timestamp)
            Task { @MainActor in
                NavigationRouter.shared.navigateToEvent(date: date)
            }
        }
        completionHandler()
    }
}
