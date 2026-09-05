import SwiftUI
import UIKit

/// The app-wide kickoff-reminder toggle, living beside the follow pill.
/// Monochrome and weight-driven like the star; denied state routes to the
/// system's notification settings (the only path once permission is refused).
struct NotificationBell: View {
    @Environment(NotificationScheduler.self) private var notifications
    @Environment(FollowingStore.self) private var following

    var body: some View {
        Button {
            Task { await handleTap() }
        } label: {
            Image(systemName: symbol)
                .foregroundStyle(Color.textPrimary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .task { await notifications.refreshAuthorization() }
    }

    private var symbol: String {
        if notifications.isDenied { return "bell.slash" }
        return notifications.remindersOn ? "bell.fill" : "bell"
    }

    private var accessibilityLabel: String {
        if notifications.isDenied { return "Kickoff reminders off. Opens Settings." }
        return notifications.remindersOn ? "Kickoff reminders on" : "Kickoff reminders off"
    }

    private func handleTap() async {
        if notifications.isDenied {
            // UIKit exception (see CLAUDE.md): SwiftUI has no route to the
            // app's notification settings.
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return
        }
        if notifications.remindersOn {
            await notifications.disable()
        } else {
            await notifications.requestAndEnable(followedKeys: following.teamKeys)
        }
    }
}
