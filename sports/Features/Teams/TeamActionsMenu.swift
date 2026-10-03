import SwiftUI
import UIKit

/// The team page's bar controls once its hero has scrolled away: the bell,
/// the follow pill and share, folded into one ellipsis (Andy, 2026-10-02),
/// so the inline team name has the bar to itself. Same three actions as
/// the expanded row, same rules.
struct TeamActionsMenu: View {
    let team: Team
    let shareText: String

    @Environment(NotificationScheduler.self) private var notifications
    @Environment(FollowingStore.self) private var following
    @Environment(TeamAlertStore.self) private var teamAlerts
    /// On the menu, not its item: a menu's items are torn down when it
    /// closes, and a sheet hung on one would go with it.
    @State private var showsAlertSheet = false

    var body: some View {
        Menu {
            Toggle("Following", isOn: Binding(
                get: { following.isFollowing(team) },
                set: { _ in following.toggle(team) }))
            Button {
                Task { await openNotifications() }
            } label: {
                Label("Notifications", systemImage: bellSymbol)
            }
            ShareLink(item: shareText) {
                Label("Share", systemImage: "square.and.arrow.up")
            }
        } label: {
            Image(systemName: "ellipsis")
                .foregroundStyle(Color.textPrimary)
        }
        .accessibilityLabel("More")
        .sensoryFeedback(.impact(weight: .light), trigger: following.isFollowing(team))
        .sheet(isPresented: $showsAlertSheet) {
            TeamNotificationSheet(team: team)
        }
    }

    /// `NotificationBell`'s glyph, so the menu says what the bell would.
    private var bellSymbol: String {
        if notifications.isDenied { return "bell.slash" }
        let isOn = notifications.remindersOn
            && following.isFollowing(team)
            && teamAlerts.sendsAnything(team.followKey, in: team.league)
        return isOn ? "bell.fill" : "bell"
    }

    /// `NotificationBell`'s tap: the sheet, or the system's notification
    /// settings once permission is refused.
    private func openNotifications() async {
        if notifications.isDenied {
            // UIKit exception (see CLAUDE.md): SwiftUI has no route to the
            // app's notification settings.
            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                await UIApplication.shared.open(url)
            }
            return
        }
        showsAlertSheet = true
    }
}
