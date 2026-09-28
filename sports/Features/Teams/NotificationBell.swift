import SwiftUI
import UIKit

/// The team's notifications, living beside the follow pill. A tap opens
/// `TeamNotificationSheet` (2026-09-28); before that it toggled the one
/// app-wide kickoff reminder. The glyph says whether *this* team sends
/// anything. Monochrome and weight-driven like the star; the denied state
/// still routes straight to the system's notification settings, the only
/// path once permission is refused.
struct NotificationBell: View {
    let team: Team

    @Environment(NotificationScheduler.self) private var notifications
    @Environment(FollowingStore.self) private var following
    @Environment(TeamAlertStore.self) private var teamAlerts
    @State private var showsSheet = false

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
        .sheet(isPresented: $showsSheet) {
            TeamNotificationSheet(team: team)
        }
    }

    private var isOn: Bool {
        notifications.remindersOn
            && following.isFollowing(team)
            && teamAlerts.sendsAnything(team.followKey, in: team.league)
    }

    private var symbol: String {
        if notifications.isDenied { return "bell.slash" }
        return isOn ? "bell.fill" : "bell"
    }

    private var accessibilityLabel: String {
        if notifications.isDenied { return "Notifications off. Opens Settings." }
        return isOn ? "Notifications on" : "Notifications off"
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
        showsSheet = true
    }
}
