import SwiftUI

/// The teams you follow, one card each.
///
/// It used to be the whole directory in accordions — every conference, every
/// team, ~250 rows deep (Andy, 2026-09-05: "the teams page doesn't need to
/// really surface all the teams grouped in accordions"). Browsing by
/// conference is what the Tables hub is for, and finding one team by name is
/// what search is for; what this tab is for is the handful of teams that are
/// yours. Adding one is a sheet away.
struct TeamsScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(Router.self) private var router
    @Environment(TeamDirectoryStore.self) private var directory

    // Heterogeneous: team cards push Team, a search intent pushes
    // ConferenceDestination — a typed path can't hold both.
    @State private var path = NavigationPath()
    @State private var isAddingTeams = false

    @ScaledMetric(relativeTo: .body) private var addIconSize: CGFloat = 40

    var body: some View {
        NavigationStack(path: $path) {
            content
                .background(Color.bgRecessed)
                .navigationTitle("Teams")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isAddingTeams = true
                        } label: {
                            Image(systemName: "plus")
                        }
                        .tint(.textPrimary)
                        .accessibilityLabel("Add teams")
                    }
                }
                .navigationDestination(for: Team.self) { team in
                    TeamPage(team: team)
                }
                .navigationDestination(for: ConferenceDestination.self) { destination in
                    ConferencePage(destination: destination)
                }
                // TeamPage's Next game card pushes game detail.
                .navigationDestination(for: Game.self) { game in
                    GameDetailScreen(game: game)
                }
        }
        .task { await directory.load() }
        // Tab content is created lazily (iOS 18 Tab builder), so an intent
        // set before the first visit predates the onChange observers —
        // onAppear catches it.
        .onAppear {
            resolvePendingTeam()
            resolvePendingConference()
        }
        .onChange(of: router.pendingTeam) { _, _ in resolvePendingTeam() }
        .onChange(of: router.pendingConferenceId) { _, _ in resolvePendingConference() }
        .onChange(of: directory.conferences) { _, _ in
            resolvePendingTeam()
            resolvePendingConference()
        }
        .sheet(isPresented: $isAddingTeams) {
            AddTeamsSheet()
        }
    }

    /// Lands a deep-linked or searched team once the directory is loaded;
    /// an unknown id degrades to landing on the Teams tab.
    ///
    /// The match is league-qualified — see `TeamDirectoryStore.team(matching:)`.
    private func resolvePendingTeam() {
        guard let pending = router.pendingTeam,
              let team = directory.team(matching: pending,
                                        followedKeys: following.teamKeys) else { return }
        router.pendingTeam = nil
        path = NavigationPath([team])
    }

    /// Lands a search result's conference on its standings page — the
    /// dedicated destination the search seam was left open for. No data
    /// dependency: the page fetches its own standings, so an intent
    /// resolves immediately even before the directory has loaded.
    private func resolvePendingConference() {
        guard let pendingId = router.pendingConferenceId else { return }
        router.pendingConferenceId = nil
        path = NavigationPath([ConferenceDestination(conference: pendingId,
                                                     name: Conference.name(for: pendingId))])
    }

    @ViewBuilder
    private var content: some View {
        // A follow can't be rendered as a card until the directory says who
        // it is, so the load state stands in for the whole screen — the
        // empty state must never be shown to someone who follows teams.
        if directory.conferences.isEmpty {
            TeamDirectoryPlaceholder()
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if followedTeams.isEmpty {
                        emptyState
                    } else {
                        // Keyed on the follow key, never the bare id: UCLA
                        // and the Seahawks are both team 26, and duplicate
                        // identities inside one LazyVStack corrupt its
                        // layout into blank card-sized gaps.
                        ForEach(followedTeams, id: \.followKey) { team in
                            FollowedTeamCard(team: team)
                        }
                    }
                    addTeamsCard
                }
                .padding(Spacing.sm)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: Spacing.xs) {
            Text("No teams yet")
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            Text("Your teams lead the Scores screen, the widget, and your kickoff reminders.")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.xl)
        .padding(.bottom, Spacing.sm)
    }

    /// The second door to the sheet, and the only one that reads as an
    /// invitation — the toolbar plus is the one that's always in reach.
    private var addTeamsCard: some View {
        Button {
            isAddingTeams = true
        } label: {
            HStack(spacing: Spacing.md) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.textPrimary)
                    .frame(width: addIconSize, height: addIconSize)
                    .background(Circle().fill(Color.bgElevated))
                Text("Add teams")
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
                Spacer(minLength: Spacing.sm)
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add teams")
        .cardSurface()
    }

    private var followedTeams: [Team] {
        directory.allTeams
            .filter { following.isFollowing($0) }
            .sorted { $0.location.localizedCaseInsensitiveCompare($1.location) == .orderedAscending }
    }
}
