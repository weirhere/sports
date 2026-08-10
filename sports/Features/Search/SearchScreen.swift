import SwiftUI

/// The search tab (FotMob-style circle beside the tab bar on iOS 26). The
/// corpus is whatever's already loaded — the FBS directory and the selected
/// week's games — so results are instant and cost zero requests. Result taps
/// hand the Router a pending intent; RootView's intent handlers switch tabs
/// and the destination screens do the navigating.
struct SearchScreen: View {
    /// Escape hatch back to the previous tab (the keyboard can cover the
    /// tab bar, so the field row carries its own way out).
    var onCancel: () -> Void = {}

    @Environment(Router.self) private var router
    @Environment(TeamDirectoryStore.self) private var directory
    @Environment(ScoreboardStore.self) private var scoreboard
    @Environment(FollowingStore.self) private var following

    @State private var searchText = ""

    private var results: SearchResults {
        SearchResults.compute(query: searchText,
                              conferences: directory.conferences,
                              games: scoreboard.games,
                              followingIds: following.teamIds)
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: Spacing.md) {
                SearchField(text: $searchText,
                            prompt: "Teams, conferences, games",
                            focusOnAppear: true,
                            identifier: "search.appWide")
                Button("Cancel", action: onCancel)
                    .font(.chip)
                    .foregroundStyle(.textPrimary)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.sm)
            content
        }
        .background(Color.bgRecessed)
    }

    @ViewBuilder
    private var content: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let results = self.results
        if trimmed.isEmpty {
            centeredMessage("Search teams, conferences, and this week's games")
        } else if results.isEmpty {
            centeredMessage("No results for “\(trimmed)”")
        } else {
            ScrollView {
                LazyVStack(spacing: Spacing.sm) {
                    if !results.teams.isEmpty {
                        resultSection("Teams") {
                            ForEach(results.teams) { team in
                                SearchTeamRow(team: team) { select(team) }
                            }
                        }
                    }
                    if !results.conferences.isEmpty {
                        resultSection("Conferences") {
                            ForEach(results.conferences) { conference in
                                SearchConferenceRow(conference: conference) { select(conference) }
                            }
                        }
                    }
                    if !results.games.isEmpty {
                        resultSection("This Week") {
                            ForEach(results.games) { game in
                                Button { select(game) } label: {
                                    GameRow(game: game)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(Spacing.sm)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    private func resultSection(_ title: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.sectionHeader)
                    .foregroundStyle(.textPrimary)
                Spacer()
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            .background(Color.bgHeader)
            .accessibilityAddTraits(.isHeader)
            rows()
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    private func centeredMessage(_ message: String) -> some View {
        VStack {
            Spacer()
            Text(message)
                .font(.teamName)
                .foregroundStyle(.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Spacing.xl)
            Spacer()
            Spacer() // Sits the message above the keyboard's midline.
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Intents
    // Setting a pending id is the whole gesture: RootView's intent handlers
    // switch tabs, which also leaves the search tab.

    private func select(_ team: Team) {
        router.pendingTeamId = team.id
    }

    private func select(_ conference: ConferenceTeams) {
        guard let id = conference.id else { return }
        router.pendingConferenceId = id
    }

    private func select(_ game: Game) {
        router.pendingGameId = game.id
    }
}
