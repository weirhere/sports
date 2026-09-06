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
    @Environment(LeagueScoreboards.self) private var scoreboards
    @Environment(FollowingStore.self) private var following

    @State private var searchText = ""

    private var results: SearchResults {
        SearchResults.compute(query: searchText,
                              conferences: directory.conferences,
                              games: scoreboards.allLoadedGames,
                              followingIds: following.teamKeys,
                              preferredLeague: following.preferredLeague)
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
                            // Keyed on the follow key, never `Team.id`: the
                            // bare ESPN id collides across leagues, and this
                            // is the one list in the app that always spans
                            // them. Two teams sharing an identity here let
                            // SwiftUI reuse one row's state for the other as
                            // the query changes — which is why the Bills'
                            // row wore Auburn's mark, both being id 2 (Andy,
                            // 2026-09-06). A query matching both at once
                            // would corrupt the layout outright.
                            ForEach(results.teams, id: \.followKey) { team in
                                SearchTeamRow(team: team,
                                              leagueTag: results.spansLeagues ? team.league : nil)
                                { select(team) }
                            }
                        }
                    }
                    if !results.conferences.isEmpty {
                        resultSection("Conferences") {
                            ForEach(results.conferences, id: \.rowId) { conference in
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

    /// The whole team, not its id: ids collide across leagues, and a
    /// result row that reads "Browns" must not open UAB (Andy, 2026-09-06).
    private func select(_ team: Team) {
        router.pendingTeam = TeamRef(team)
    }

    private func select(_ conference: ConferenceTeams) {
        guard let id = conference.conference else { return }
        router.pendingConferenceId = id
    }

    private func select(_ game: Game) {
        router.pendingGameId = game.id
    }
}
