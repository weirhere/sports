import Foundation

/// The News tab's feeds (E26): For you, and one per league.
///
/// Each is fetched the first time its page is shown and held for the
/// session; pull to refresh asks again. Never polled — a story isn't live
/// data, and the scoreboard's 1s cadence would be ESPN's news API asked a
/// question it answers every few hours.
@Observable
final class NewsFeedStore {
    /// The tab row's pages, in order: yours first, then the leagues in the
    /// order the app lists them everywhere else.
    enum Feed: Int, CaseIterable, HeroTabItem {
        case forYou, collegeFootball, nfl, nba, nhl

        var league: League? {
            switch self {
            case .forYou: nil
            case .collegeFootball: .collegeFootball
            case .nfl: .nfl
            case .nba: .nba
            case .nhl: .nhl
            }
        }

        var title: String { league?.shortName ?? "For you" }
    }

    enum LoadState {
        case loading
        case loaded([NewsStory])
        case failed
    }

    /// For you asks each followed team's own feed, so it costs a request
    /// per follow. Capped so a user following the whole SEC doesn't open
    /// the tab onto forty requests.
    static let forYouCap = 20

    private(set) var states: [Feed: LoadState] = [:]
    /// The follows For you was built from: a follow added or dropped since
    /// makes it stale, and the next visit rebuilds it.
    private var forYouKeys: Set<String>?
    private var inFlight: Set<Feed> = []

    func state(_ feed: Feed) -> LoadState { states[feed] ?? .loading }

    /// Loads `feed` unless it's already held for these follows. A refresh
    /// that fails keeps the list on screen rather than trading it for an
    /// error.
    func load(_ feed: Feed, followedKeys: Set<String>, force: Bool = false) async {
        let stale = feed == .forYou && forYouKeys != nil && forYouKeys != followedKeys
        if !force, !stale, case .loaded = states[feed] { return }
        guard !inFlight.contains(feed) else { return }
        inFlight.insert(feed)
        defer { inFlight.remove(feed) }
        if stale { states[feed] = nil }
        if case .failed = states[feed] { states[feed] = nil }

        let client = NewsClient()
        let result: [NewsStory]?
        if let league = feed.league {
            result = await client.leagueNews(league: league)
        } else {
            result = await Self.forYou(followedKeys: followedKeys, client: client)
        }

        if let result {
            states[feed] = .loaded(result)
            if feed == .forYou { forYouKeys = followedKeys }
        } else if case .loaded = states[feed] {
            // Keep what's on screen.
        } else {
            states[feed] = .failed
        }
    }

    /// Every followed team's own feed, merged. Some feeds failing makes a
    /// thinner list; all of them failing is a failure. No follows is an
    /// empty list, which the screen answers with a way to add some.
    private static func forYou(followedKeys: Set<String>,
                               client: NewsClient) async -> [NewsStory]? {
        let follows = followedKeys.compactMap(FollowKey.init)
            .sorted { $0.rawValue < $1.rawValue }
            .prefix(forYouCap)
        guard !follows.isEmpty else { return [] }
        let feeds = await withTaskGroup(of: [NewsStory]?.self) { group in
            for key in follows {
                group.addTask { await client.teamNews(teamId: key.teamId, league: key.league) }
            }
            var collected: [[NewsStory]?] = []
            for await feed in group { collected.append(feed) }
            return collected
        }
        let loaded = feeds.compactMap(\.self)
        guard !loaded.isEmpty else { return nil }
        return NewsMapper.forYou(loaded)
    }
}
