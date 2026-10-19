import SwiftUI

/// The News tab (E26, Andy 2026-09-27): every league's stories in one place,
/// after FotMob's News tab. It reverses the brief's N1 ("no News tab") on
/// Andy's call, and its photos supersede N8 (the color budget's sixth
/// exception); the in-app reader (N4) and no generated summaries still hold.
///
/// Four pages (Andy, 2026-10-19): **For you**, Trending and a section per
/// followed team you've kept on it; **Latest**, every league newest first;
/// **Transfers**, the roster moves among them; and **Leagues**, each
/// league's own stories in the Leagues tab's order. The last three are the
/// same four feeds read three ways, and `NewsFeedStore` fetches them once.
struct NewsScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(TeamDirectoryStore.self) private var directory
    @Environment(UIStateStore.self) private var ui

    @State private var store = NewsFeedStore()
    @State private var feed: NewsFeedStore.Feed = .forYou
    @State private var path = NavigationPath()
    @State private var isAddingTeams = false
    @State private var isChoosingTeams = false

    /// The follows For you shows: everyone followed, less the teams the
    /// sheet unchecked. What the page is keyed by and fetched for.
    private var visibleKeys: Set<String> {
        following.teamKeys.filter { ui.isShownInNews($0) }
    }

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // The masthead every root tab shares; For you's filter
                // sits where Teams puts its plus.
                PageHeader(title: "News") {
                    if feed == .forYou { chooseTeamsButton }
                }
                HeroTabBar(tabs: NewsFeedStore.Feed.allCases, selection: feed,
                           onSelect: { feed = $0 })
                ScrollView {
                    content
                        .padding(Spacing.sm)
                }
                .refreshable { await load(force: true) }
            }
            .background(Color.bgRecessed)
            .toolbar(.hidden, for: .navigationBar)
            // Every page a story can lead to: the reader, and from it the
            // game, a team, and whatever those push.
            .navigationDestination(for: StoryDestination.self) { destination in
                StoryReader(destination: destination)
                    .id(destination.story.id)
            }
            .navigationDestination(for: Game.self) { game in
                GameDetailScreen(game: game)
                    .id(game.routeKey)
            }
            .navigationDestination(for: Team.self) { team in
                TeamPage(team: team)
                    .id(team.followKey)
            }
            // A team section's "See more".
            .navigationDestination(for: TeamNewsDestination.self) { destination in
                TeamPage(team: destination.team, opensNews: true)
                    .id(destination)
            }
            .navigationDestination(for: PlayerIdentity.self) { player in
                PlayerPage(player: player)
                    .id(player.id)
            }
            .navigationDestination(for: CoachIdentity.self) { coach in
                CoachPage(coach: coach)
                    .id(coach.id)
            }
            // A pro league's "See more", and whatever a team page's
            // badges open.
            .navigationDestination(for: ConferenceDestination.self) { destination in
                ConferencePage(destination: destination)
                    .id(destination)
            }
            // College football's "See more": its league page is the Top 25.
            .navigationDestination(for: PollDestination.self) { destination in
                PollScreen(polls: destination.polls, league: destination.league,
                           opensNews: destination.opensNews)
                    .id(destination)
            }
        }
        // Keyed by the page and the follows it shows: a new page loads on
        // first visit, and For you rebuilds after a follow or the sheet
        // changes.
        .task(id: "\(feed.rawValue):\(visibleKeys.sorted())") { await load() }
        .task { await directory.load() }
        .sheet(isPresented: $isAddingTeams) {
            AddTeamsSheet()
        }
        .sheet(isPresented: $isChoosingTeams) {
            ForYouTeamsSheet()
        }
    }

    private func load(force: Bool = false) async {
        await store.load(feed, followedKeys: visibleKeys, force: force)
    }

    /// The door to the For you sheet, in the slot Teams gives its plus:
    /// the same 44pt circle, so the two read as one class of control.
    private var chooseTeamsButton: some View {
        Button {
            isChoosingTeams = true
        } label: {
            Image(systemName: "slider.horizontal.3")
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(Color.textPrimary)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .glassCircleInteractive(fallback: Color.bgElevated)
        .accessibilityLabel("Choose teams")
        .accessibilityIdentifier("news-choose-teams")
    }

    @ViewBuilder
    private var content: some View {
        switch store.state(feed) {
        case .loaded:
            switch feed {
            case .forYou: forYou
            case .latest: NewsLatestPage(stories: store.latest)
            case .transfers: NewsTransfersPage(stories: store.transfers)
            case .leagues: NewsLeaguesPage(stories: store.stories(in:))
            }
        case .failed:
            StatusMessage(text: "Couldn't load the news.",
                          retry: { Task { await load(force: true) } })
                .cardSurface()
        case .loading:
            // A lone spinner gets no card (Andy, 2026-08-31).
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, Spacing.xl)
        }
    }

    // MARK: - For you

    /// The followed teams with stories, less the sheet's unchecked ones,
    /// in the Teams tab's order.
    private var teamSections: [(team: Team, stories: [NewsStory])] {
        let pages = store.forYouPage?.teams ?? [:]
        return directory.allTeams
            .filter { following.isFollowing($0) && ui.isShownInNews($0.followKey) }
            .sorted { $0.location.localizedCaseInsensitiveCompare($1.location) == .orderedAscending }
            .compactMap { team in pages[team.followKey].map { (team, $0) } }
    }

    private var forYou: some View {
        let trending = store.trending
        let sections = teamSections
        return LazyVStack(spacing: Spacing.sm) {
            if !trending.isEmpty {
                ListSectionHeading(title: "Trending")
                StorySection(stories: trending)
            }
            ForEach(sections, id: \.team.followKey) { section in
                NewsSectionHeading(logoURL: section.team.logoURL,
                                   title: section.team.displayName ?? section.team.location)
                StorySection(stories: section.stories,
                             seeMore: TeamNewsDestination(team: section.team))
            }
            if following.teamKeys.isEmpty {
                addTeamsCard
            }
            if trending.isEmpty, sections.isEmpty, !following.teamKeys.isEmpty {
                StatusMessage(text: "No stories right now.")
                    .cardSurface()
            }
        }
    }

    /// For you with nobody followed still has Trending; this is where the
    /// team sections would be.
    private var addTeamsCard: some View {
        VStack(spacing: Spacing.sm) {
            VStack(spacing: Spacing.xs) {
                Text("No teams yet")
                    .font(.teamNameEmphasis)
                    .foregroundStyle(.textPrimary)
                Text("Follow teams and their stories get a section here.")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Button("Add teams") { isAddingTeams = true }
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Spacing.xl)
        .cardSurface()
    }
}
