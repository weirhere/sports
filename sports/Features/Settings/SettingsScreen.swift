import SwiftUI
import UIKit

/// The app's few preferences, in one place (2026-09-24).
///
/// It exists because Betting lines needed somewhere to be switched on. Coard
/// Miller asked for the lines on both the game page and the Scores page, and
/// in the same breath for a toggle, since they "might be frowned upon". A
/// preference nobody can find is the same as none, and the Scores header is
/// the app's front door, not a place for a gambling switch. Kickoff reminders
/// live here too, as the same state the Team page's bell shows, so the one
/// place called Settings holds every setting there is.
struct SettingsScreen: View {
    @Environment(UIStateStore.self) private var uiState
    @Environment(NotificationScheduler.self) private var notifications
    @Environment(FollowingStore.self) private var following
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        @Bindable var uiState = uiState
        NavigationStack {
            List {
                Section {
                    Toggle("Betting lines", isOn: $uiState.showsLines)
                } header: {
                    Text("Scores")
                } footer: {
                    Text("Shows the spread and over/under before kickoff, on the Scores page and the game page.")
                }

                Section {
                    if notifications.isDenied {
                        Button("Kickoff reminders are off in iOS Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundStyle(.textPrimary)
                    } else {
                        Toggle("Kickoff reminders", isOn: remindersBinding)
                    }
                } header: {
                    Text("Notifications")
                } footer: {
                    Text("A heads-up 30 minutes before each of your teams' games.")
                }

                Section("About") {
                    LabeledContent("Version", value: Self.version)
                }
            }
            // The app's own ground and card, not the system's grouped grays,
            // so the sheet reads as part of StatSide in both appearances.
            .scrollContentBackground(.hidden)
            .background(Color.bgRecessed)
            .listRowBackground(Color.bgCard)
            // Monochrome switches (no green: the color budget). Ink on light,
            // but on dark an ink track is white under a white thumb and the
            // "on" state disappears, so dark takes the secondary gray.
            .tint(colorScheme == .dark ? Color.textSecondary : Color.textPrimary)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await notifications.refreshAuthorization() }
    }

    /// The bell's own calls, so this switch and the bell are one state.
    private var remindersBinding: Binding<Bool> {
        Binding {
            notifications.remindersOn
        } set: { on in
            Task {
                if on {
                    await notifications.requestAndEnable(followedKeys: following.teamKeys)
                } else {
                    await notifications.disable()
                }
            }
        }
    }

    /// "2.4.0 (18)".
    static var version: String {
        let info = Bundle.main.infoDictionary
        let marketing = info?["CFBundleShortVersionString"] as? String ?? "—"
        let build = info?["CFBundleVersion"] as? String ?? "—"
        return "\(marketing) (\(build))"
    }
}
