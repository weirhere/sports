import Foundation
import UserNotifications
#if canImport(ActivityKit)
import ActivityKit
#endif

/// The kickoff reminder's one action: pin the game to the Lock Screen.
///
/// E12's second door (2026-09-24). The 30-minute reminder is the moment a
/// fan decides whether they care about a game, so it is the other place the
/// Live Activity is offered, beside the pin on the game page.
///
/// **The action opens the app** (`.foreground`) and the game page starts
/// the card once the game has loaded, rather than starting it from a
/// background launch. The background start would be the smoother product,
/// but it runs with no summary in hand and on a budget the system can cut
/// short, and a pin that silently fails is worse than one that shows you
/// the game while it works.
nonisolated enum KickoffReminderActions {
    static let categoryId = "kickoff"
    static let pinActionId = "kickoff.pin"

    /// Offered only where the pin could actually work: the feature is on
    /// for this build and the user hasn't switched Live Activities off.
    static func offersPin(isAvailable: Bool, activitiesEnabled: Bool) -> Bool {
        isAvailable && activitiesEnabled
    }

    /// The category every reminder carries. Without the pin it has no
    /// actions, so the reminder is exactly what it was before this existed.
    static func categories(offersPin: Bool) -> Set<UNNotificationCategory> {
        let actions = offersPin
            ? [UNNotificationAction(identifier: pinActionId,
                                    title: "Pin to Lock Screen",
                                    options: [.foreground],
                                    icon: UNNotificationActionIcon(systemImageName: "pin"))]
            : []
        return [UNNotificationCategory(identifier: categoryId, actions: actions,
                                       intentIdentifiers: [])]
    }

    /// Registered at launch and again on every scene-active, because the
    /// user can switch Live Activities off in Settings while the app is
    /// away. A reminder's actions come from what is registered when it
    /// fires, not when it was scheduled.
    @MainActor
    static func register() {
        #if canImport(ActivityKit)
        let offers = offersPin(isAvailable: LiveActivityController.isAvailable,
                               activitiesEnabled: ActivityAuthorizationInfo().areActivitiesEnabled)
        #else
        let offers = false
        #endif
        UNUserNotificationCenter.current().setNotificationCategories(categories(offersPin: offers))
    }

    /// What a response asks for: the game it names, and whether the pin
    /// action (rather than a plain tap) was chosen. Nil when it names none.
    static func intent(actionIdentifier: String,
                       userInfo: [AnyHashable: Any]) -> (gameId: String, pin: Bool)? {
        guard let gameId = userInfo["gameId"] as? String else { return nil }
        return (gameId, actionIdentifier == pinActionId)
    }
}
