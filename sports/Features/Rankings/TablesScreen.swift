import SwiftUI

/// The tables hub, FotMob-Leagues-shaped: a Following section first, then
/// every league as its own accordion — followed rows repeat inside them,
/// since sections stay complete.
///
/// The league is an accordion header rather than a segmented control
/// (Andy, 2026-09-05): a control shows one league at a time and has to
/// grow a new segment per sport, while stacked accordions show them all
/// and cost one row each. The hub is also the one screen that isn't scoped
/// to the app-wide league — "who's good" has an answer per league, and
/// they fit on one page.
///
/// Each league answers the question its own way. College football leads
/// with the Top 25 row (the poll one tap down, so the conferences aren't
/// buried under 25 rank rows) and lists its conferences. The NFL has no
/// poll at all — `/nfl/rankings` is a 404 — so it is the AFC and the NFC,
/// with no poll row rather than an empty one. Hence "Tables".
struct TablesScreen: View {
    /// The FBS polls we show, in picker order. ESPN's response also carries
    /// FCS and DII/DIII polls — filtered out.
    private static let pollTypes = ["ap", "usa", "cfp"]

    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState

    @State private var polls: [Poll] = []
    /// Standings per league, each fetched and failing independently.
    @State private var standings: [League: [ConferenceStandings]] = [:]
    @State private var isLoading = false
    @State private var lastError: String?

    var body: some View {
        NavigationStack {
            content
                .background(Color.bgPrimary)
                .navigationTitle("Tables")
                .navigationBarTitleDisplayMode(.inline)
                // TeamPage is pushed view-based here, but its standing line
                // and a standings row's team both push values — register
                // them so those links work inside this stack too.
                .navigationDestination(for: ConferenceDestination.self) { destination in
                    ConferencePage(destination: destination)
                }
                .navigationDestination(for: Team.self) { team in
                    TeamPage(team: team)
                }
                // TeamPage's Next game card pushes game detail.
                .navigationDestination(for: Game.self) { game in
                    GameDetailScreen(game: game)
                }
        }
        .task { await load() }
    }

    /// The leagues with something to show. A league whose standings didn't
    /// come back isn't there at all, rather than being there and empty.
    private var populatedLeagues: [League] {
        League.allCases.filter { !rows(for: $0).isEmpty }
    }

    /// Empty for the NFL, which has no poll.
    private func displayedPolls(for league: League) -> [Poll] {
        guard league == .collegeFootball else { return [] }
        return Self.pollTypes.compactMap { type in polls.first { $0.type == type } }
    }

    /// Divisions folded into their conference: the hub names conferences,
    /// so the Sun Belt is one row here even though its standings are two
    /// tables (the page that tables them still gets both).
    private func conferences(in league: League) -> [ConferenceStandings] {
        (standings[league] ?? []).foldingDivisions()
    }

    /// What a league's accordion holds — its conferences, plus the poll row
    /// where the league has one. The count in the header is this.
    private func rows(for league: League) -> [TableRow] {
        var rows: [TableRow] = []
        let polls = displayedPolls(for: league)
        if !polls.isEmpty { rows.append(.poll(polls)) }
        rows += conferences(in: league).map(TableRow.conference)
        return rows
    }

    /// The Following section's conference rows, across every league.
    private var followedConferences: [ConferenceStandings] {
        League.allCases.flatMap(conferences(in:)).filter { conference in
            conference.conference.map(following.isFollowingConference) ?? false
        }
    }

    @ViewBuilder
    private var content: some View {
        if !populatedLeagues.isEmpty {
            ScrollView {
                // FotMob-Leagues shape: Following leads, then the complete
                // list — followed rows repeat inside their league, sections
                // stay complete, never deduplicated.
                LazyVStack(spacing: Spacing.sm) {
                    if !followedConferences.isEmpty {
                        ListSectionHeading(title: "Following")
                        VStack(spacing: 0) {
                            // Section-prefixed ids: a followed conference
                            // appears in both sections, and duplicate
                            // identities inside one LazyVStack corrupt its
                            // layout (blank card-sized gaps).
                            ForEach(followedConferences, id: \.followingRowId) { conference in
                                ConferenceListRow(conference: conference)
                            }
                        }
                        .padding(.vertical, Spacing.xs)
                        .cardSurface()
                    }
                    ListSectionHeading(title: "Leagues")
                    ForEach(populatedLeagues) { league in
                        leagueSection(league)
                    }
                }
                .padding(Spacing.sm)
            }
            .background(Color.bgRecessed)
            .refreshable { await load() }
        } else if isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else {
            Spacer()
            Text(lastError ?? "No tables right now")
                .font(.teamName)
                .foregroundStyle(.textSecondary)
            Button("Retry") {
                Task { await load() }
            }
            .font(.teamNameEmphasis)
            .foregroundStyle(.textPrimary)
            Spacer()
        }
    }

    /// One league's accordion, the Teams-browse card: a bgHeader toggle row
    /// over the league's rows, collapse state persisted like every other
    /// accordion in the app.
    private func leagueSection(_ league: League) -> some View {
        let sectionId = Self.sectionId(for: league)
        let isExpanded = !uiState.isConferenceCollapsed(sectionId)
        let rows = rows(for: league)
        return VStack(spacing: 0) {
            Button {
                withAnimation { uiState.toggleConference(sectionId) }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text(league.displayName)
                        .font(.sectionHeader)
                        .foregroundStyle(.textPrimary)
                    Text("\(rows.count)")
                        .font(.meta)
                        .foregroundStyle(.textSecondary)
                    Spacer()
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("tables-league-\(league.rawValue)")
            .accessibilityLabel("\(league.displayName), \(rows.count) \(rows.count == 1 ? "table" : "tables")")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .accessibilityAddTraits(.isHeader)
            .background(Color.bgHeader)

            if isExpanded {
                ForEach(rows) { row in
                    switch row {
                    case .poll(let polls):
                        Top25Row(polls: polls)
                    case .conference(let conference):
                        ConferenceListRow(conference: conference)
                    }
                }
            }
        }
        .padding(.bottom, isExpanded ? Spacing.xs : 0)
        .cardSurface()
    }

    /// League-qualified and namespaced: the collapse state is persisted
    /// alongside every conference accordion's, so the key has to be unique
    /// across screens. Absence means expanded, so a new league arrives open.
    private static func sectionId(for league: League) -> String {
        "tables.league.\(league.rawValue)"
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        // Clear first: a refresh must not leave stale tables on screen
        // while the new fetches are in flight.
        polls = []
        standings = [:]
        // The fetches fail independently: no poll is a screen-level error
        // only when no league's standings came back either; a standings
        // miss just drops that league's accordion.
        async let pollsFetch = DataProvider.makeClient(league: .collegeFootball).rankings()
        async let standingsFetch = Self.allStandings()
        do {
            polls = try await pollsFetch
            lastError = nil
        } catch {
            lastError = "Couldn't load tables."
        }
        standings = await standingsFetch
    }

    /// Every league's standings in parallel — one league's outage leaves
    /// the others' tables on screen rather than emptying the hub.
    private static func allStandings() async -> [League: [ConferenceStandings]] {
        await withTaskGroup(of: (League, [ConferenceStandings]).self) { group in
            for league in League.allCases {
                group.addTask {
                    let client = DataProvider.makeClient(league: league)
                    return (league, (try? await client.conferenceStandings()) ?? [])
                }
            }
            var standings: [League: [ConferenceStandings]] = [:]
            for await (league, tables) in group {
                standings[league] = tables
            }
            return standings
        }
    }
}

/// A row inside a league's accordion: its poll, or one of its conferences.
private enum TableRow: Identifiable {
    case poll([Poll])
    case conference(ConferenceStandings)

    var id: String {
        switch self {
        case .poll: "poll"
        case .conference(let conference): conference.id.map(String.init) ?? conference.name
        }
    }
}

private extension ConferenceStandings {
    /// The hub shows a followed conference in both the Following section
    /// and its league's accordion; this gives the Following appearance a
    /// distinct ForEach identity, league-qualified because group id 8 is
    /// the SEC and the AFC.
    var followingRowId: String {
        "following-\(league.rawValue)-\(id.map(String.init) ?? name)"
    }
}
