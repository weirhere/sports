import Foundation
import UserNotifications

/// Presents kickoff reminders even while foregrounded and routes taps to
/// the game via the same Router widget taps use.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let router: Router
    private let reviewPrompt: ReviewPrompt

    init(router: Router, reviewPrompt: ReviewPrompt) {
        self.router = router
        self.reviewPrompt = reviewPrompt
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
        guard let intent = KickoffReminderActions.intent(
            actionIdentifier: response.actionIdentifier,
            userInfo: response.notification.request.content.userInfo
        ) else { return }
        if intent.pin {
            // Set before the game, so the page finds it when it loads.
            // No rating arm on this path: the card is what the user asked
            // for, and a rating sheet over it would eat the moment.
            router.pendingPin = intent.gameId
        } else {
            // The one moment worth asking for a rating at: the reminder
            // fired and the user followed it in. `GameDetailScreen` spends
            // the arm once the game is actually on screen and loaded.
            reviewPrompt.armFromKickoffReminder(gameId: intent.gameId)
        }
        router.pendingGame = GameRef(id: intent.gameId)
    }
}
