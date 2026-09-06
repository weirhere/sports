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
/// poll at all — `/nfl/rankings` is a 404 — so it leads with its own
/// 32-team table and then the AFC and the NFC, with no poll row rather
/// than an empty one. Hence "Tables".
///
/// FCS gets a card of its own rather than 14 more rows inside College
/// Football's. It is a separate competition — its own group on ESPN, its
/// own playoff — and it is opt-in (E8 scope (b)), so it arrives collapsed:
/// one discoverable row with a count, not fourteen the app never promised
/// to cover. Following a conference here is what puts group 81 on the
/// Scores slate, which is the path that went missing when the view-options
/// sheet retired.
struct TablesScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState

    @State private var polls: [Poll] = []
    /// Standings per league, each fetched and failing independently.
    @State private var standings: [League: [ConferenceStandings]] = [:]
    /// College football's other division, kept apart from `standings`
    /// because FCS is not a `League` — it is a division of one, and making
    /// it a league case would leak into follow keys, clients and ids.
    @State private var fcsStandings: [ConferenceStandings] = []
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

    /// Every card the hub shows, in order, skipping any whose fetch came
    /// back empty — a group that didn't load isn't there at all, rather
    /// than being there and empty.
    ///
    /// FCS follows College Football, since it is the other half of the
    /// same sport, and precedes the NFL.
    private var groups: [TableGroup] {
        League.allCases.flatMap { league -> [TableGroup] in
            var groups = [TableGroup(id: Self.sectionId(for: league),
                                     title: league.displayName,
                                     startsExpanded: true,
                                     rows: rows(for: league))]
            if league == .collegeFootball {
                groups.append(TableGroup(id: Self.fcsSectionId,
                                         title: "FCS",
                                         startsExpanded: false,
                                         rows: fcsStandings.foldingDivisions()
                                             .map(TableRow.conference)))
            }
            return groups
        }
        .filter { !$0.rows.isEmpty }
    }

    /// Empty for the NFL, which has no poll.
    private func displayedPolls(for league: League) -> [Poll] {
        guard league == .collegeFootball else { return [] }
        // One filter for the hub row and the page it pushes, so the two
        // agree on which poll is "first".
        return PollScreen.displayed(polls)
    }

    /// Divisions folded into their conference: the hub names conferences,
    /// so the Sun Belt is one row here even though its standings are two
    /// tables (the page that tables them still gets both).
    private func conferences(in league: League) -> [ConferenceStandings] {
        (standings[league] ?? []).foldingDivisions()
    }

    /// The league's own table, where it has one — the NFL's 32 teams in a
    /// single ranking (Andy's ask, 2026-09-05: "the whole NFL as well, not
    /// just the different conferences"). College football answers the same
    /// question with its poll, so this is nil there.
    private func leagueTable(in league: League) -> ConferenceStandings? {
        (standings[league] ?? []).leagueTable(in: league)
    }

    /// Every table a league offers, league-wide row first: the whole thing
    /// above its parts, which is also where the poll row sits in college
    /// football.
    private func tables(in league: League) -> [ConferenceStandings] {
        (leagueTable(in: league).map { [$0] } ?? []) + conferences(in: league)
    }

    /// What a league's accordion holds — its conferences, plus the poll row
    /// where the league has one. The count in the header is this.
    private func rows(for league: League) -> [TableRow] {
        var rows: [TableRow] = []
        let polls = displayedPolls(for: league)
        if !polls.isEmpty { rows.append(.poll(polls, league)) }
        rows += tables(in: league).map(TableRow.conference)
        return rows
    }

    /// The leagues whose poll is followed and actually loaded — the
    /// Following section's poll rows, which lead it the way the poll leads
    /// its league's accordion.
    private var followedPolls: [League] {
        League.allCases.filter {
            following.isFollowingPoll(in: $0) && !displayedPolls(for: $0).isEmpty
        }
    }

    /// The Following section's rows, across every league — a followed
    /// league table sits among the conferences it contains, the way a
    /// followed conference sits beside a followed team's.
    private var followedConferences: [ConferenceStandings] {
        (League.allCases.flatMap(tables(in:)) + fcsStandings.foldingDivisions())
            .filter { conference in
                conference.conference.map(following.isFollowingConference) ?? false
            }
    }

    @ViewBuilder
    private var content: some View {
        if !groups.isEmpty {
            ScrollView {
                // FotMob-Leagues shape: Following leads, then the complete
                // list — followed rows repeat inside their league, sections
                // stay complete, never deduplicated.
                LazyVStack(spacing: Spacing.sm) {
                    if !followedPolls.isEmpty || !followedConferences.isEmpty {
                        ListSectionHeading(title: "Following")
                        VStack(spacing: 0) {
                            ForEach(followedPolls) { league in
                                Top25Row(polls: displayedPolls(for: league), league: league)
                            }
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
                    ForEach(groups) { group in
                        groupSection(group)
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

    /// One group's accordion, the Teams-browse card: a bgHeader toggle row
    /// over its rows, collapse state persisted like every other accordion
    /// in the app.
    ///
    /// Two expansion mechanisms, because the two defaults differ. A league
    /// arrives open and `collapsedConferences` records the exception; FCS
    /// arrives closed, and `expandedSections` — whose absence already means
    /// collapsed — records that exception instead. Same persistence, read
    /// from the end that makes the default free.
    private func groupSection(_ group: TableGroup) -> some View {
        let sectionId = group.id
        let isExpanded = group.startsExpanded
            ? !uiState.isConferenceCollapsed(sectionId)
            : uiState.isExpanded(sectionId)
        let rows = group.rows
        return VStack(spacing: 0) {
            Button {
                withAnimation {
                    if group.startsExpanded {
                        uiState.toggleConference(sectionId)
                    } else {
                        uiState.toggle(sectionId)
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Text(group.title)
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
            .accessibilityIdentifier(group.identifier)
            .accessibilityLabel("\(group.title), \(rows.count) \(rows.count == 1 ? "table" : "tables")")
            .accessibilityValue(isExpanded ? "expanded" : "collapsed")
            .accessibilityAddTraits(.isHeader)
            .background(Color.bgHeader)

            if isExpanded {
                ForEach(rows) { row in
                    switch row {
                    case .poll(let polls, let league):
                        Top25Row(polls: polls, league: league)
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

    /// Namespaced under the same prefix, so the two mechanisms can't
    /// collide with each other or with a Scores day id.
    private static let fcsSectionId = "tables.division.fcs"

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        // Clear first: a refresh must not leave stale tables on screen
        // while the new fetches are in flight.
        polls = []
        standings = [:]
        fcsStandings = []
        // The fetches fail independently: no poll is a screen-level error
        // only when no league's standings came back either; a standings
        // miss just drops that league's accordion.
        async let pollsFetch = DataProvider.makeClient(league: .collegeFootball).rankings()
        async let standingsFetch = Self.allStandings()
        // College football's other division, its own request. A miss drops
        // the FCS card and nothing else.
        async let fcsFetch = try? await DataProvider.makeClient(league: .collegeFootball)
            .conferenceStandings(year: nil, division: .fcs)
        do {
            polls = try await pollsFetch
            lastError = nil
        } catch {
            lastError = "Couldn't load tables."
        }
        standings = await standingsFetch
        fcsStandings = await fcsFetch ?? []
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
    /// The league rides along so the row never has to assume which one
    /// polls — only college football does today, but the assumption would
    /// be invisible at the render site.
    case poll([Poll], League)
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

/// One accordion card on the hub — a league, or college football's FCS
/// half, which is a competition of its own but not a `League`.
private struct TableGroup: Identifiable {
    let id: String
    let title: String
    /// Whether the card arrives open. Leagues do; FCS doesn't, because it
    /// is opt-in and fourteen rows the app never promised to cover.
    let startsExpanded: Bool
    let rows: [TableRow]

    /// `tables-league-cfb`, `tables-division-fcs` — the UI tests' handle.
    var identifier: String { id.replacingOccurrences(of: ".", with: "-") }
}
