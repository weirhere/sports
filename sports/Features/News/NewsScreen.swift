import SwiftUI

/// The News tab (E26, Andy 2026-09-27): every league's stories in one place,
/// after FotMob's News tab. It reverses the brief's N1 ("no News tab") on
/// Andy's call, and its photos supersede N8 (the color budget's sixth
/// exception); the in-app reader (N4) and no generated summaries still hold.
///
/// FotMob's top row, adapted: **For you**, then one page per league. For
/// you is FotMob's sectioned feed (Mobbin `bfd98a17`): Trending, one section
/// per followed team with a "See more" to that team's News tab, then Latest.
/// A league page is one section whose "See more" opens the league's own
/// News tab.
struct NewsScreen: View {
    @Environment(FollowingStore.self) private var following
    @Environment(TeamDirectoryStore.self) private var directory

    @State private var store = NewsFeedStore()
    @State private var feed: NewsFeedStore.Feed = .forYou
    @State private var path = NavigationPath()
    @State private var isAddingTeams = false

    var body: some View {
        NavigationStack(path: $path) {
            VStack(spacing: 0) {
                // The masthead every root tab shares.
                PageHeader("News")
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
            // A pro league page's "See more", and whatever a team page's
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
        // Keyed by the page and the follows: a new page loads on first
        // visit, and For you rebuilds after a follow changes.
        .task(id: "\(feed.rawValue):\(following.teamKeys.sorted())") { await load() }
        .task { await directory.load() }
        .sheet(isPresented: $isAddingTeams) {
            AddTeamsSheet()
        }
    }

    private func load(force: Bool = false) async {
        await store.load(feed, followedKeys: following.teamKeys, force: force)
    }

    @ViewBuilder
    private var content: some View {
        switch store.state(feed) {
        case .loaded(let stories):
            if let league = feed.league {
                leaguePage(league, stories: stories)
            } else if let page = store.forYouPage {
                forYou(page)
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

    /// The followed teams with stories, in the Teams tab's order.
    private func teamSections(_ page: NewsFeedStore.ForYouPage) -> [(team: Team, stories: [NewsStory])] {
        directory.allTeams
            .filter { following.isFollowing($0) }
            .sorted { $0.location.localizedCaseInsensitiveCompare($1.location) == .orderedAscending }
            .compactMap { team in page.teams[team.followKey].map { (team, $0) } }
    }

    private func forYou(_ page: NewsFeedStore.ForYouPage) -> some View {
        LazyVStack(spacing: Spacing.sm) {
            if !page.trending.isEmpty {
                ListSectionHeading(title: "Trending")
                StorySection(stories: page.trending)
            }
            ForEach(teamSections(page), id: \.team.followKey) { section in
                teamHeading(section.team)
                StorySection(stories: section.stories,
                             seeMore: TeamNewsDestination(team: section.team))
            }
            if following.teamKeys.isEmpty {
                addTeamsCard
            }
            if !page.latest.isEmpty {
                ListSectionHeading(title: "Latest")
                // One story per card, full width: FotMob's Latest.
                ForEach(page.latest) { story in
                    NavigationLink(value: StoryDestination(story: story)) {
                        FeaturedStory(story: story)
                    }
                    .buttonStyle(.plain)
                    .cardSurface()
                }
            }
            if page.trending.isEmpty, page.latest.isEmpty, page.teams.isEmpty,
               !following.teamKeys.isEmpty {
                StatusMessage(text: "No stories right now.")
                    .cardSurface()
            }
        }
    }

    /// A team section's heading: the team's mark and its name, in
    /// `ListSectionHeading`'s type and spacing.
    private func teamHeading(_ team: Team) -> some View {
        HStack(spacing: Spacing.sm) {
            LogoImage(url: team.logoURL)
                .frame(width: 20, height: 20)
            Text(team.displayName ?? team.location)
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xs)
    }

    /// For you with nobody followed still has Trending and Latest; this is
    /// where the team sections would be.
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

    // MARK: - A league

    /// One section, and "See more" to the league's own News tab: the Top 25
    /// for college football, the league-wide conference page for the rest.
    @ViewBuilder
    private func leaguePage(_ league: League, stories: [NewsStory]) -> some View {
        if stories.isEmpty {
            StatusMessage(text: "No \(league.shortName) stories right now.")
                .cardSurface()
        } else if league == .collegeFootball {
            StorySection(stories: stories,
                         seeMore: PollDestination(league: league, opensNews: true))
        } else if let id = Conference.leagueWideId(in: league) {
            StorySection(stories: stories,
                         seeMore: ConferenceDestination(conference: ConferenceID(league, id),
                                                        name: Conference.name(for: id, in: league),
                                                        opensNews: true))
        } else {
            StorySection(stories: stories)
        }
    }
}
