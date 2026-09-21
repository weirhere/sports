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
    @State private var scope: SearchScope = .all

    /// Search pushes onto its **own** stack (Andy, 2026-09-21: *"tapping
    /// back should take the user back to the search list rather than back
    /// to the teams page unnecessarily"*).
    ///
    /// It used to hand the Router a pending intent, which switched to the
    /// Teams tab and pushed there — so Back landed on a list of followed
    /// teams nobody had asked for, and the query was gone. The Router path
    /// stays for the doors that genuinely come from outside the hierarchy
    /// (a widget tap, a notification, a deep link); a tap on a row that is
    /// already on screen is not one of those.
    @State private var path = NavigationPath()

    /// The Leagues accordion header's height (Andy, 2026-09-21: *"make the
    /// search cards taller (like the league accordions)"*) — 34pt of
    /// content plus its 7pt and `Spacing.xs` paddings. A minimum, never a
    /// fixed height, so a two-line row at accessibility sizes can outgrow
    /// it rather than clip.
    private static let cardHeight: CGFloat = 34 + (7 * 2) + (Spacing.xs * 2)

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
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                PageHeader("Search")
                SearchScopePills(selection: scope) { scope = $0 }
                content
            }
            .background(Color.bgRecessed)
            .toolbar(.hidden, for: .navigationBar)
            // Identity follows the value, the rule every other stack in the
            // app follows (2026-09-10): a destination whose identity doesn't
            // change is reused with its `@State` intact.
            .navigationDestination(for: Team.self) { team in
                TeamPage(team: team).id(team.followKey)
            }
            .navigationDestination(for: PlayerIdentity.self) { player in
                PlayerPage(player: player).id(player.id)
            }
            .navigationDestination(for: ConferenceDestination.self) { destination in
                ConferencePage(destination: destination).id(destination)
            }
            .navigationDestination(for: Game.self) { game in
                GameDetailScreen(game: game).id(game.id)
            }
        }
        // The field rides the bottom, above the keyboard rather than a
        // screen away from it (Andy, 2026-09-21). `safeAreaInset` is what
        // makes that true of the keyboard as well as the home indicator:
        // the content above keeps its own scrollable height and the field
        // lifts with the keys instead of being covered by them.
        .safeAreaInset(edge: .bottom, spacing: 0) { searchBar }
        .onChange(of: searchText) { _, text in
            athleteSearch.search(text, collegeTeamsInScope: collegeTeamNames)
        }
    }

    /// The field and the way out, at the foot of the screen.
    private var searchBar: some View {
        HStack(spacing: Spacing.md) {
            SearchField(text: $searchText,
                        prompt: "Teams, players, conferences, games",
                        focusOnAppear: true,
                        identifier: "search.appWide")
            Button("Cancel", action: onCancel)
                .font(.chip)
                .foregroundStyle(.textPrimary)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .background(.bar)
    }

    @ViewBuilder
    private var content: some View {
        let trimmed = searchText.trimmingCharacters(in: .whitespaces)
        let results = self.results
        if trimmed.isEmpty {
            // The sentence is kept for the one run where it is still true:
            // before anything has been opened there is nothing to hand back
            // and the corpus is worth naming (Andy, 2026-09-21).
            if scopedRecents.isEmpty {
                centeredMessage("Search teams, conferences, and this week's games")
            } else {
                recentsList
            }
        } else if visibleResultsAreEmpty {
            // Not "no results" while the network half is still out — that
            // sentence would be true for a beat and then wrong, which is
            // worse than saying nothing.
            centeredMessage(athleteSearch.isSearching
                            ? "Searching…"
                            : "No results for “\(trimmed)”")
        } else {
            ScrollView {
                // One card per result, not one card per section (Andy,
                // 2026-09-21). A game and a team are different shapes, and
                // a shared card made them read as one list of one kind of
                // thing. The scope pills carry the taxonomy the section
                // headings used to.
                LazyVStack(spacing: Spacing.sm) {
                    if shows(.teams) {
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
                            SearchTeamRow(team: team) { select(team) }
                                .frame(minHeight: Self.cardHeight)
                                .cardSurface()
                        }
                    }
                    if shows(.conferences) {
                        ForEach(results.conferences, id: \.rowId) { conference in
                            SearchConferenceRow(conference: conference) { select(conference) }
                                .frame(minHeight: Self.cardHeight)
                                .cardSurface()
                        }
                    }
                    if shows(.players) {
                        ForEach(athleteSearch.athletes) { player in
                            SearchPlayerRow(player: player) { select(player) }
                                .frame(minHeight: Self.cardHeight)
                                .cardSurface()
                        }
                    }
                    if shows(.games) {
                        ForEach(results.games) { game in
                            Button { select(game) } label: {
                                GameRow(game: game)
                            }
                            .buttonStyle(.plain)
                            .frame(minHeight: Self.cardHeight)
                            .cardSurface()
                        }
                    }
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.sm)
            }
            .scrollDismissesKeyboard(.immediately)
        }
    }

    /// Whether a kind of result belongs in the list right now. `all` shows
    /// everything; any other pill shows only its own.
    private func shows(_ kind: SearchScope) -> Bool {
        scope == .all || scope == kind
    }

    /// True when the visible scope has nothing in it — which is not the
    /// same as the query having no matches. Narrowed to Players, a query
    /// that found three teams and no people is empty *here*, and saying so
    /// beats an empty screen with no explanation.
    private var visibleResultsAreEmpty: Bool {
        let teams = shows(.teams) && !results.teams.isEmpty
        let conferences = shows(.conferences) && !results.conferences.isEmpty
        let players = shows(.players) && !athleteSearch.athletes.isEmpty
        let games = shows(.games) && !results.games.isEmpty
        return !(teams || conferences || players || games)
    }

    /// A recent, resolved against the live directory. Persisted entries
    /// carry `(id, league)` only, so the row is drawn from today's `Team`
    /// rather than from a snapshot taken whenever it was tapped.
    private struct ResolvedRecent: Identifiable {
        let entry: RecentSearchesStore.Entry
        let kind: Kind

        enum Kind {
            case team(Team)
            case conference(ConferenceTeams)
            case player(PlayerIdentity)
            case game(Game)
        }

        var id: String { entry.id }
    }

    /// Entries the directory can still account for. One that resolves to
    /// nothing — a league whose directory hasn't loaded — is dropped for
    /// this render rather than deleted: the store is not the judge of
    /// whether a league is loaded yet, and a recent must not evaporate
    /// because the app was opened offline.
    private var resolvedRecents: [ResolvedRecent] {
        recents.entries.compactMap { entry -> ResolvedRecent? in
            switch entry {
            case let .team(id, league):
                return directory.team(matching: TeamRef(id: id, league: league),
                                      followedKeys: following.teamKeys)
                    .map { ResolvedRecent(entry: entry, kind: .team($0)) }
            case let .conference(id):
                return directory.conferences(in: id.league)
                    .first { $0.id == id.id }
                    .map { ResolvedRecent(entry: entry, kind: .conference($0)) }
            case let .player(id, league, name, teamName, headshot):
                // Already whole: the entry is the snapshot, so unlike the
                // other two this resolves without asking anything.
                var player = PlayerIdentity(athleteId: id, name: name,
                                            league: league, teamName: teamName,
                                            teamLogoURL: nil)
                player.headshotURL = headshot
                return ResolvedRecent(entry: entry, kind: .player(player))
            case let .game(id, _):
                // Resolved live, so a score is never stale. Unresolvable
                // when its day isn't loaded — skipped, like a team whose
                // league directory hasn't arrived.
                return scoreboards.allLoadedGames
                    .first { $0.id == id }
                    .map { ResolvedRecent(entry: entry, kind: .game($0)) }
            }
        }
    }

    /// Recents, narrowed by the scope pills. Without this the pills looked
    /// broken on the screen people see first: an empty query shows recents,
    /// and recents ignored the filter entirely, so every pill rendered the
    /// same list (Andy, 2026-09-21).
    private var scopedRecents: [ResolvedRecent] {
        resolvedRecents.filter { recent in
            switch recent.kind {
            case .team: shows(.teams)
            case .conference: shows(.conferences)
            case .player: shows(.players)
            case .game: shows(.games)
            }
        }
    }

    private var recentsList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(scopedRecents) { recent in
                    HStack(spacing: 0) {
                        row(for: recent.kind)
                        dismissButton { recents.remove(recent.entry) }
                    }
                    .frame(minHeight: Self.cardHeight)
                    .cardSurface()
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
        }
        .scrollDismissesKeyboard(.immediately)
    }

    @ViewBuilder
    private func row(for kind: ResolvedRecent.Kind) -> some View {
        switch kind {
        case let .team(team):
            SearchTeamRow(team: team) { select(team) }
        case let .conference(conference):
            SearchConferenceRow(conference: conference) { select(conference) }
        case let .player(player):
            SearchPlayerRow(player: player) { select(player) }
        case let .game(game):
            Button { select(game) } label: { GameRow(game: game) }
                .buttonStyle(.plain)
        }
    }

    /// Clears one row from the list (Andy, 2026-09-21). Trailing, outside
    /// the row's own button so a tap here can't be read as opening the
    /// thing you meant to forget.
    private func dismissButton(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 17))
                .foregroundStyle(.textSecondary.opacity(0.5))
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, Spacing.sm)
        .accessibilityLabel("Remove from recent searches")
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
        path.append(team)
    }

    private func select(_ conference: ConferenceTeams) {
        guard let id = conference.conference else { return }
        recents.record(.conference(id))
        path.append(ConferenceDestination(conference: id, name: conference.name))
    }

    private func select(_ game: Game) {
        recents.record(RecentSearchesStore.Entry(game))
        path.append(game)
    }

    private func select(_ player: PlayerIdentity) {
        recents.record(RecentSearchesStore.Entry(player))
        path.append(player)
    }
}
