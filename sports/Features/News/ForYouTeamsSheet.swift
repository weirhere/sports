import SwiftUI

/// Which followed teams get a section on For you (Andy, 2026-10-19),
/// opened from the filter button on the News masthead. FotMob's For you
/// filter sheet, as `docs/news.md` N12 described and declined; taken now
/// on Andy's call, superseding N12.
///
/// A checklist of every followed team in the Teams tab's order — A–Z by
/// location, since follows carry no order of their own — and a row to
/// the Teams tab, where the follows themselves are managed. Unchecking
/// keeps the follow and takes the team off this one page. Done closes
/// it, and so does a swipe down. `TeamNotificationSheet`'s surface.
struct ForYouTeamsSheet: View {
    @Environment(FollowingStore.self) private var following
    @Environment(TeamDirectoryStore.self) private var directory
    @Environment(UIStateStore.self) private var ui
    @Environment(Router.self) private var router
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    /// The followed teams, in the Teams tab's order.
    private var teams: [Team] {
        directory.allTeams
            .filter { following.isFollowing($0) }
            .sorted { $0.location.localizedCaseInsensitiveCompare($1.location) == .orderedAscending }
    }

    var body: some View {
        NavigationStack {
            List {
                if teams.isEmpty {
                    Section {
                        Text("No teams yet")
                            .foregroundStyle(.textSecondary)
                    } footer: {
                        Text("Follow teams and their stories get a section on For you.")
                    }
                } else {
                    Section {
                        ForEach(teams, id: \.followKey) { team in
                            TeamCheckRow(team: team, isOn: ui.isShownInNews(team.followKey)) {
                                ui.setShownInNews(!ui.isShownInNews(team.followKey), for: team.followKey)
                            }
                        }
                    } footer: {
                        Text("Unchecked teams keep their follow and leave this page.")
                    }
                }

                Section {
                    Button {
                        dismiss()
                        router.pendingTeamsBrowse = true
                    } label: {
                        HStack {
                            Text("Manage teams")
                                .foregroundStyle(.textPrimary)
                            Spacer(minLength: Spacing.sm)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.textSecondary)
                                .accessibilityHidden(true)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityHint("Opens the Teams tab")
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color.bgRecessed)
            .listRowBackground(Color.bgCard)
            // Settings' rule (2026-09-26): ink on light, the one green on
            // dark, where an ink track would vanish under a white thumb.
            .tint(colorScheme == .dark ? Color.rankUp : Color.textPrimary)
            .navigationTitle("For you")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
}
