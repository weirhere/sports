import SwiftUI
import UIKit

/// The app-wide kickoff-reminder toggle, living beside the follow pill.
/// Monochrome and weight-driven like the star; denied state routes to the
/// system's notification settings (the only path once permission is refused).
struct NotificationBell: View {
    @Environment(NotificationScheduler.self) private var notifications
    @Environment(FollowingStore.self) private var following

    private var ink: Color { .textPrimary }
    private var inverse: Color { Color.bgPrimary }

    var body: some View {
        Button {
            Task { await handleTap() }
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 14))
                .foregroundStyle(notifications.remindersOn ? inverse : ink)
                .padding(9)
                .background(
                    Circle().fill(notifications.remindersOn ? ink : Color.clear)
                )
                .overlay(
                    Circle().strokeBorder(ink, lineWidth: notifications.remindersOn ? 0 : 1)
                )
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
            await notifications.requestAndEnable(followedIds: following.teamIds)
        }
    }
}
