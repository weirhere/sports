import SwiftUI

/// The News tab (E26, Andy 2026-09-27): every league's stories in one place,
/// after FotMob's News tab. It reverses the brief's N1 ("no News tab") on
/// Andy's call; the rest of `docs/news.md` still holds — text rows (N8), the
/// in-app reader (N4), no photos, no generated summaries.
///
/// FotMob's top row, adapted: **For you**, your followed teams' own stories
/// merged newest first, then one page per league. FotMob's Latest and
/// Transfers pages and its filter sheet aren't here — the leagues are the
/// app's own axis, and follows are the filter.
struct NewsScreen: View {
    @Environment(FollowingStore.self) private var following

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
            .navigationDestination(for: PlayerIdentity.self) { player in
                PlayerPage(player: player)
                    .id(player.id)
            }
            .navigationDestination(for: ConferenceDestination.self) { destination in
                ConferencePage(destination: destination)
                    .id(destination)
            }
        }
        // Keyed by the page and the follows: a new page loads on first
        // visit, and For you rebuilds after a follow changes.
        .task(id: "\(feed.rawValue):\(following.teamKeys.sorted())") { await load() }
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
        case .loaded(let stories) where !stories.isEmpty:
            StoryListCard(stories: stories)
        case .loaded:
            emptyState
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

    /// For you with nobody followed is a way to follow someone; a league
    /// page or a For you with follows and no stories just says so.
    @ViewBuilder
    private var emptyState: some View {
        if feed == .forYou, following.teamKeys.isEmpty {
            VStack(spacing: Spacing.sm) {
                VStack(spacing: Spacing.xs) {
                    Text("No teams yet")
                        .font(.teamNameEmphasis)
                        .foregroundStyle(.textPrimary)
                    Text("Follow teams and their stories collect here.")
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
        } else {
            StatusMessage(text: feed == .forYou
                          ? "No stories about your teams right now."
                          : "No \(feed.title) stories right now.")
                .cardSurface()
        }
    }
}
