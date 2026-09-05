import SwiftUI

/// The tables hub, FotMob-Leagues-shaped: a Following section first, then
/// the complete list — followed rows repeat there, since sections stay
/// complete.
///
/// Contextual, because the two leagues answer "who's good" differently.
/// College football leads with the Top 25 row (the poll one tap down, so
/// the conferences aren't buried under 25 rank rows) and lists its
/// conferences. The NFL has no poll at all — `/nfl/rankings` is a 404 —
/// so its hub is the AFC and the NFC, and a tab named "Rankings" would
/// have been half a screen of dead space. Hence "Tables".
struct TablesScreen: View {
    /// The FBS polls we show, in picker order. ESPN's response also carries
    /// FCS and DII/DIII polls — filtered out.
    private static let pollTypes = ["ap", "usa", "cfp"]

    @Environment(FollowingStore.self) private var following
    @Environment(UIStateStore.self) private var uiState
    @Environment(LeagueScoreboards.self) private var scoreboards

    @State private var polls: [Poll] = []
    @State private var conferences: [ConferenceStandings] = []
    @State private var isLoading = false
    @State private var lastError: String?

    private var league: League { scoreboards.selectedLeague }

    private var client: any ScoresProviding { DataProvider.makeClient(league: league) }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // The same scope control the Scores header carries: the
                // league is one app-wide scope, so changing it here
                // changes it there (Sofascore's sport row, which sits on
                // every screen rather than one).
                HStack {
                    Spacer(minLength: 0)
                    LeagueSelector(selected: league, onSelect: select(league:))
                        .padding(4)
                        .glassCapsule(fallback: Color.bgElevated)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, Spacing.lg)
                .padding(.bottom, Spacing.sm)
                content
            }
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
        .task(id: league) { await load() }
    }

    private func select(league: League) {
        scoreboards.select(league)
        uiState.league = league
    }

    /// Empty for the NFL, which has no poll — the section simply isn't
    /// there, rather than being there and empty.
    private var displayedPolls: [Poll] {
        guard league == .collegeFootball else { return [] }
        return Self.pollTypes.compactMap { type in polls.first { $0.type == type } }
    }

    /// The Following section's conference rows. The Top 25 row leads the
    /// section regardless — it's the hub's #1 answer, not a follow state.
    private var followedConferences: [ConferenceStandings] {
        conferences.filter { conference in
            conference.conference.map(following.isFollowingConference) ?? false
        }
    }

    @ViewBuilder
    private var content: some View {
        if !displayedPolls.isEmpty || !conferences.isEmpty {
            ScrollView {
                // FotMob-Leagues shape per the P1 review: Following leads
                // (Top 25 row + followed conferences), then the complete
                // list — followed rows repeat there, sections stay
                // complete, never deduplicated.
                LazyVStack(spacing: Spacing.sm) {
                    if !displayedPolls.isEmpty || !followedConferences.isEmpty {
                        ListSectionHeading(title: "Following")
                    }
                    if !displayedPolls.isEmpty {
                        Top25Row(polls: displayedPolls)
                            .padding(.vertical, Spacing.xs)
                            .cardSurface()
                    }
                    // Section-prefixed ids: a followed conference appears in
                    // both sections, and duplicate identities inside one
                    // LazyVStack corrupt its layout (blank card-sized gaps).
                    ForEach(followedConferences, id: \.followingRowId) { conference in
                        ConferenceListRow(conference: conference)
                            .padding(.vertical, Spacing.xs)
                            .cardSurface()
                    }
                    if !conferences.isEmpty {
                        ListSectionHeading(title: allSectionTitle)
                        ForEach(conferences, id: \.allRowId) { conference in
                            ConferenceListRow(conference: conference)
                                .padding(.vertical, Spacing.xs)
                                .cardSurface()
                        }
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
            Text(lastError ?? emptyMessage)
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

    /// The NFL's two groups are conferences; college football's list is
    /// conferences too, but the word does different work in each.
    private var allSectionTitle: String {
        league == .nfl ? "Conferences" : "All conferences"
    }

    private var emptyMessage: String {
        league == .nfl ? "No standings right now" : "No rankings right now"
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        // Clear first: a league switch must not leave the previous one's
        // tables on screen while the new fetch is in flight.
        polls = []
        conferences = []
        // The two fetches fail independently: no poll is a screen-level
        // error only when there are no conferences either; a standings miss
        // just hides the CONFERENCES card under a healthy Top 25 row.
        async let pollsFetch = client.rankings()
        async let standingsFetch = client.conferenceStandings()
        do {
            polls = try await pollsFetch
            lastError = nil
        } catch {
            lastError = "Couldn't load tables."
        }
        conferences = (try? await standingsFetch) ?? []
    }
}

private extension ConferenceStandings {
    /// The hub shows a followed conference in both sections; these give the
    /// two appearances distinct ForEach identities so the shared LazyVStack
    /// never sees a duplicate id.
    var followingRowId: String { "following-\(id.map(String.init) ?? name)" }
    var allRowId: String { "all-\(id.map(String.init) ?? name)" }
}
