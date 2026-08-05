import Foundation
import UserNotifications

/// Presents kickoff reminders even while foregrounded and routes taps to
/// the game via the same Router widget taps use.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: Router

    init(router: Router) {
        self.router = router
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        if let gameId = response.notification.request.content.userInfo["gameId"] as? String {
            router.pendingGameId = gameId
        }
    }
}
