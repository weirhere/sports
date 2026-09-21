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
    @Environment(RecentSearchesStore.self) private var recents

    /// Owned here rather than injected: athlete results are this screen's
    /// alone, and a store the whole app holds would keep a stranger's query
    /// warm for the next visit.
    @State private var athleteSearch = AthleteSearchStore()

    @State private var searchText = ""

    /// Every college football team the app has a page for — FBS and FCS
    /// both, since the directory is division-complete for the sport.
    private var collegeTeamNames: Set<String> {
        Set(directory.conferences
            .filter { $0.league == .collegeFootball }
            .flatMap(\.teams)
            .compactMap(\.displayName))
    }

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
        .onChange(of: searchText) { _, text in
            athleteSearch.search(text, collegeTeamsInScope: collegeTeamNames)
        }
    }

    @ViewBuilder
    private var content: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let results = self.results
        if trimmed.isEmpty {
            // The sentence is kept for the one run where it is still true:
            // before anything has been opened there is nothing to hand back
            // and the corpus is worth naming (Andy, 2026-09-21).
            if resolvedRecents.isEmpty {
                centeredMessage("Search teams, conferences, and this week's games")
            } else {
                recentsList
            }
        } else if results.isEmpty, athleteSearch.athletes.isEmpty {
            // Not "no results" while the network half is still out — that
            // sentence would be true for a beat and then wrong, which is
            // worse than saying nothing.
            centeredMessage(athleteSearch.isSearching
                            ? "Searching…"
                            : "No results for “\(trimmed)”")
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
                                SearchTeamRow(team: team, leagueTag: team.league)
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
                    if !athleteSearch.athletes.isEmpty {
                        // Above the games and below the teams: a name query
                        // wants the person, a place query wants the club,
                        // and the slate is the one section that is about
                        // today rather than about the query.
                        resultSection("Players") {
                            ForEach(athleteSearch.athletes) { player in
                                SearchPlayerRow(player: player) { select(player) }
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

    /// A recent, resolved against the live directory. Persisted entries
    /// carry `(id, league)` only, so the row is drawn from today's `Team`
    /// rather than from a snapshot taken whenever it was tapped.
    private enum ResolvedRecent: Identifiable {
        case team(Team)
        case conference(ConferenceTeams)
        case player(PlayerIdentity)

        var id: String {
            switch self {
            case let .team(team): "team.\(team.followKey)"
            case let .conference(conference): "conf.\(conference.rowId)"
            case let .player(player): "player.\(player.id)"
            }
        }
    }

    /// Entries the directory can still account for. One that resolves to
    /// nothing — a league whose directory hasn't loaded — is dropped for
    /// this render rather than deleted: the store is not the judge of
    /// whether a league is loaded yet, and a recent must not evaporate
    /// because the app was opened offline.
    private var resolvedRecents: [ResolvedRecent] {
        recents.entries.compactMap { entry in
            switch entry {
            case let .team(id, league):
                return directory.team(matching: TeamRef(id: id, league: league),
                                      followedKeys: following.teamKeys)
                    .map(ResolvedRecent.team)
            case let .conference(id):
                return directory.conferences(in: id.league)
                    .first { $0.id == id.id }
                    .map(ResolvedRecent.conference)
            case let .player(id, league, name, teamName, headshot):
                // Already whole: the entry is the snapshot, so unlike the
                // other two this resolves without asking anything.
                var player = PlayerIdentity(athleteId: id, name: name,
                                            league: league, teamName: teamName,
                                            teamLogoURL: nil)
                player.headshotURL = headshot
                return ResolvedRecent.player(player)
            }
        }
    }

    private var recentsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                resultSection("Recent", trailing: clearRecentsButton) {
                    ForEach(resolvedRecents) { recent in
                        switch recent {
                        case let .team(team):
                            SearchTeamRow(team: team, leagueTag: team.league) { select(team) }
                        case let .conference(conference):
                            SearchConferenceRow(conference: conference) { select(conference) }
                        case let .player(player):
                            SearchPlayerRow(player: player) { select(player) }
                        }
                    }
                }
            }
            .padding(Spacing.sm)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    private var clearRecentsButton: some View {
        Button("Clear") { recents.clear() }
            .font(.chip)
            .foregroundStyle(.textSecondary)
            .buttonStyle(.plain)
            .accessibilityIdentifier("search.recents.clear")
    }

    private func resultSection(_ title: String,
                               trailing: (some View)? = Optional<EmptyView>.none,
                               @ViewBuilder rows: () -> some View) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title)
                    .font(.sectionHeader)
                    .foregroundStyle(.textPrimary)
                Spacer()
                trailing
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
        recents.record(RecentSearchesStore.Entry(team))
        router.pendingTeam = TeamRef(team)
    }

    private func select(_ conference: ConferenceTeams) {
        guard let id = conference.conference else { return }
        recents.record(.conference(id))
        router.pendingConferenceId = id
    }

    private func select(_ game: Game) {
        router.pendingGame = GameRef(game)
    }

    private func select(_ player: PlayerIdentity) {
        recents.record(RecentSearchesStore.Entry(player))
        router.pendingPlayer = player
    }
}
