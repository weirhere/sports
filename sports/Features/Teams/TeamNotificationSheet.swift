import SwiftUI
import UIKit
#if canImport(ActivityKit)
import ActivityKit
#endif

/// What one team sends, opened from the bell on its page (Andy, 2026-09-28,
/// FotMob's "Set notifications" sheet).
///
/// Top to bottom: pin every game to the Lock Screen, a switch for this
/// team, then the checklist. Only rows that can actually fire are offered
/// (`TeamAlert.offered`), so today a release build shows the kickoff
/// reminder alone and the scoring, final and news rows arrive with the
/// service that sends them. The Settings screen's surface: `bgRecessed`
/// ground, `bgCard` rows, ink switches on light and the one green on dark.
struct TeamNotificationSheet: View {
    let team: Team

    @Environment(NotificationScheduler.self) private var notifications
    @Environment(FollowingStore.self) private var following
    @Environment(TeamAlertStore.self) private var teamAlerts
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var key: String { team.followKey }
    private var isFollowing: Bool { following.isFollowing(team) }
    private var teamIsOn: Bool { notifications.remindersOn && !teamAlerts.isMuted(key) }

    var body: some View {
        NavigationStack {
            List {
                if offersLiveActivities {
                    Section {
                        Toggle(isOn: pinBinding) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Live Activities")
                                Text("Pin every game to the Lock Screen")
                                    .font(.subheadline)
                                    .foregroundStyle(.textSecondary)
                            }
                        }
                    }
                    .disabled(!isFollowing)
                }

                if !isFollowing {
                    Section {
                        Button("Follow \(team.displayName ?? team.location)") {
                            following.toggle(team)
                        }
                        .foregroundStyle(.textPrimary)
                    } footer: {
                        Text("Notifications come from the teams you follow.")
                    }
                }

                Section {
                    if notifications.isDenied {
                        Button("Notifications are off in iOS Settings") {
                            if let url = URL(string: UIApplication.openNotificationSettingsURLString) {
                                UIApplication.shared.open(url)
                            }
                        }
                        .foregroundStyle(.textPrimary)
                    } else {
                        Toggle("Notifications", isOn: teamBinding)
                    }
                }
                .disabled(!isFollowing)

                Section {
                    ForEach(TeamAlert.offered(in: team.league)) { alert in
                        TeamAlertRow(alert: alert, league: team.league,
                                     isOn: teamAlerts.isOn(alert, for: key)) {
                            teamAlerts.toggle(alert, for: key)
                        }
                    }
                }
                .disabled(!isFollowing || !teamIsOn)
                .opacity(isFollowing && teamIsOn ? 1 : 0.4)
            }
            .scrollContentBackground(.hidden)
            .background(Color.bgRecessed)
            .listRowBackground(Color.bgCard)
            // Settings' rule (2026-09-26): ink on light, the one green on
            // dark, where an ink track would vanish under a white thumb.
            .tint(colorScheme == .dark ? Color.rankUp : Color.textPrimary)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    HStack(spacing: Spacing.sm) {
                        LogoImage(url: team.logoURL, placeholder: nil)
                            .frame(width: 22, height: 22)
                            .accessibilityHidden(true)
                        Text("Notifications")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(.textPrimary)
                    }
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(team.location) notifications")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .task { await notifications.refreshAuthorization() }
    }

    /// Only where a card could actually appear: the feature is on for this
    /// build and the user hasn't switched Live Activities off in iOS.
    private var offersLiveActivities: Bool {
        #if canImport(ActivityKit)
        LiveActivityController.isAvailable && ActivityAuthorizationInfo().areActivitiesEnabled
        #else
        false
        #endif
    }

    /// On asks for permission the first time (the bell used to), then
    /// unmutes this team. Off mutes this team only; the app-wide switch in
    /// Settings is the one that silences everything.
    private var teamBinding: Binding<Bool> {
        Binding {
            teamIsOn
        } set: { on in
            teamAlerts.setMuted(!on, for: key)
            guard on, !notifications.remindersOn else { return }
            Task {
                let keys = teamAlerts.keys(receiving: .kickoffReminder, among: following.teamKeys)
                await notifications.requestAndEnable(followedKeys: keys)
            }
        }
    }

    private var pinBinding: Binding<Bool> {
        Binding {
            teamAlerts.pinsGames(key)
        } set: { pins in
            teamAlerts.setPinsGames(pins, for: key)
        }
    }
}
