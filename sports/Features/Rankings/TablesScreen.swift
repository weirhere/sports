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
/// Following is one card per followed table, draggable (Andy, 2026-09-06):
/// the Teams tab's shape, and the order is the order those same tables lead
/// the Scores page in, one tab over. See `FollowedTablesList`.
///
/// FCS is inside College Football's card, not beside it (Andy,
/// 2026-09-06): the hub's accordions are leagues, and FCS is a division of
/// one, so a card of its own read as a third league. Its 14 conferences
/// sort below the 11 FBS ones on the tier rule that already orders the
/// list — `.fcs` sits under `.independent` — so they arrive grouped
/// without a second header saying so. Following one is still what puts
/// group 81 on the Scores slate.
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
    /// Set while a Following card is lifted, so the hub's ScrollView stops
    /// competing for the same vertical pan. See `FollowedTablesList`.
    @State private var isReordering = false

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
    private var groups: [TableGroup] {
        League.allCases
            .map { TableGroup(id: Self.sectionId(for: $0),
                              title: $0.displayName,
                              logoURL: $0.logoURL,
                              rows: rows(for: $0)) }
            .filter { !$0.rows.isEmpty }
    }

    /// Empty for the NFL, which has no poll.
    private func displayedPolls(for league: League) -> [Poll] {
        guard league == .collegeFootball else { return [] }
        // One filter for the hub row and the page it pushes, so the two
        // agree on which poll is "first".
        return PollScreen.displayed(polls)
    }

    /// Divisions folded into their conference: the Sun Belt, not
    /// "Sun Belt - East" and "Sun Belt - West"; the AFC, not its four.
    ///
    /// College football's two divisions fold together here — the fetches
    /// stay separate (they are separate requests, and either can fail
    /// alone), the list doesn't. Folding the union in one pass is what
    /// sorts FBS above FCS: `foldingDivisions()` re-applies the tier rule
    /// across everything it is handed.
    ///
    /// For the pro leagues this is a *derivation*, not a fetch: their hub
    /// request is the divisional one, and folding it back up is what
    /// gives the league row something to merge.
    private func conferences(in league: League) -> [ConferenceStandings] {
        var fetched = standings[league] ?? []
        if league == .collegeFootball { fetched += fcsStandings }
        return fetched.foldingDivisions()
    }

    /// The divisions a league's accordion lists, grouped by the
    /// conference they belong to and alphabetical inside it — the AFC's
    /// four, then the NFC's.
    ///
    /// The mapper sorts divisions by name alone, which is right for a
    /// standings pane listing one conference's and wrong for a list of
    /// every one: alphabetically the NBA's six interleave their
    /// conferences, and Northwest lands between Central and Pacific with
    /// nothing on screen to explain why.
    private func divisions(in league: League) -> [ConferenceStandings] {
        let conferenceOrder = Conference.topLevelIds(in: league)
        func rank(_ table: ConferenceStandings) -> Int {
            table.parentId.flatMap(conferenceOrder.firstIndex(of:)) ?? conferenceOrder.count
        }
        return (standings[league] ?? [])
            .filter { $0.parentId != nil }
            .sorted { lhs, rhs in
                let (l, r) = (rank(lhs), rank(rhs))
                return l == r ? lhs.name < rhs.name : l < r
            }
    }

    /// The league's own table, where it has one — the NFL's 32 teams in a
    /// single ranking (Andy's ask, 2026-09-05: "the whole NFL as well, not
    /// just the different conferences"). College football answers the same
    /// question with its poll, so this is nil there.
    private func leagueTable(in league: League) -> ConferenceStandings? {
        conferences(in: league).leagueTable(in: league)
    }

    /// What a league's accordion holds, league-wide row first: the whole
    /// thing above its parts.
    ///
    /// The parts are **divisions** for the pro leagues (Andy, 2026-09-09:
    /// "split into division rather than conference … conferences aren't as
    /// a priority here") — a division is the race anyone is actually in,
    /// where a conference is a playoff bracket's seeding pool. College
    /// football's parts are its conferences, which is the same rung: the
    /// group a team plays a schedule inside.
    private func tables(in league: League) -> [ConferenceStandings] {
        let parts = league.hasCollegeDivisions ? conferences(in: league) : divisions(in: league)
        return (leagueTable(in: league).map { [$0] } ?? []) + parts
    }

    /// Every table a league offers that someone could be following,
    /// including the conference rows the accordion no longer lists. A
    /// conference follow made before the hub showed divisions still has a
    /// card in Following and still hoists its section on Scores.
    private func followableTables(in league: League) -> [ConferenceStandings] {
        var seen: Set<ConferenceID?> = []
        return (tables(in: league) + conferences(in: league))
            .filter { seen.insert($0.conference).inserted }
    }

    /// What a league's accordion holds — its tables, plus the poll row
    /// where the league has one. The count in the header is this.
    private func rows(for league: League) -> [TableRow] {
        var rows: [TableRow] = []
        let polls = displayedPolls(for: league)
        if !polls.isEmpty { rows.append(.poll(polls, league)) }
        rows += tables(in: league).map(TableRow.conference)
        return rows
    }

    /// The Following section's rows, in the user's own order (Andy,
    /// 2026-09-06) — polls and conferences interleaved, since both are
    /// tables and the order is what the Scores screen reads to decide
    /// which sections lead its page.
    ///
    /// Resolved against what actually loaded: a followed table whose fetch
    /// came back empty has no row here, exactly as it has no accordion
    /// below. Nothing errors over a missing one.
    private var followedRows: [FollowedTableRow] {
        let loaded = League.allCases.flatMap(followableTables(in:))
        return following.orderedTables.compactMap { table -> FollowedTableRow? in
            switch table {
            case .poll(let league):
                let polls = displayedPolls(for: league)
                return polls.isEmpty ? nil
                    : FollowedTableRow(table: table, content: .poll(polls, league))
            case .conference(let id):
                guard let standings = loaded.first(where: { $0.conference == id })
                else { return nil }
                return FollowedTableRow(table: table, content: .conference(standings))
            }
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
                    let followed = followedRows
                    if !followed.isEmpty {
                        ListSectionHeading(title: "Following")
                        // The list owns its own cards' identities, which
                        // are the follow tokens — distinct from the ids
                        // the same conferences use inside their league's
                        // accordion below, since duplicate identities in
                        // one LazyVStack corrupt its layout (blank
                        // card-sized gaps).
                        FollowedTablesList(rows: followed, isReordering: $isReordering)
                    }
                    ListSectionHeading(title: "Leagues")
                    ForEach(groups) { group in
                        groupSection(group)
                    }
                }
                .padding(Spacing.sm)
            }
            .background(Color.bgRecessed)
            .scrollDisabled(isReordering)
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
    /// in the app. A league arrives open — absence of a stored collapse
    /// means expanded, so a new league needs no migration.
    ///
    /// The header stands a followed card's height (Andy, 2026-09-06), not
    /// the 12pt padding alone its content asks for — the hub is a stack of
    /// cards, and two sizes of card in one stack reads as an accident. This
    /// is the hub's own header, not the Scores accordion's: `SectionAccordion`
    /// is a different view, and its rows are games, which set their own
    /// height.
    private func groupSection(_ group: TableGroup) -> some View {
        let sectionId = group.id
        let isExpanded = !uiState.isConferenceCollapsed(sectionId)
        let rows = group.rows
        return VStack(spacing: 0) {
            Button {
                withAnimation { uiState.toggleConference(sectionId) }
            } label: {
                HStack(spacing: Spacing.sm) {
                    ConferenceLogo(url: group.logoURL)
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
                // minHeight, never a fixed height: at accessibility text
                // sizes the title outgrows the card and must be allowed to.
                .frame(minHeight: Self.headerHeight)
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

    /// What a followed table's card measures, and so what a league header
    /// does: the follow star's 34pt tap target, inside the row's 7pt and
    /// the card's 4pt.
    private static let headerHeight: CGFloat = 34 + (7 * 2) + (Spacing.xs * 2)

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
        fcsStandings = []
        // The fetches fail independently: no poll is a screen-level error
        // only when no league's standings came back either; a standings
        // miss just drops that league's accordion.
        async let pollsFetch = DataProvider.makeClient(league: .collegeFootball).rankings()
        async let standingsFetch = Self.allStandings()
        // College football's other division, its own request. A miss drops
        // the FCS rows and nothing else — the card is the league's, and its
        // FBS half arrived on a different request.
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
    ///
    /// A league whose accordion lists divisions asks for the divisional
    /// response instead of the conference one, and the conference tables
    /// are folded back out of it (`conferences(in:)`). One request either
    /// way: asking for both would have cost three more on every hub load,
    /// and `level=3` carries everything the shallower response does.
    private static func allStandings() async -> [League: [ConferenceStandings]] {
        await withTaskGroup(of: (League, [ConferenceStandings]).self) { group in
            for league in League.allCases {
                group.addTask {
                    let client = DataProvider.makeClient(league: league)
                    guard !league.hasCollegeDivisions else {
                        return (league, (try? await client.conferenceStandings()) ?? [])
                    }
                    let divisions = (try? await client.divisionStandings(year: nil)) ?? []
                    // A league that ships no divisional response still has
                    // conferences worth listing.
                    guard divisions.isEmpty else { return (league, divisions) }
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

/// One accordion card on the hub — one league, with every table it offers
/// inside it.
private struct TableGroup: Identifiable {
    let id: String
    let title: String
    /// The badge beside the title — the league's own mark. Optional so a
    /// future card without one falls back to the football glyph every
    /// conference header already uses.
    let logoURL: URL?
    let rows: [TableRow]

    /// `tables-league-cfb` — the UI tests' handle.
    var identifier: String { id.replacingOccurrences(of: ".", with: "-") }
}
