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
            result = await Self.leaguePage(league, client: client)
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

    /// How many of the poll's teams top up a flooded page. Ten is a
    /// Saturday's headline programs, at ten requests, only on a flood day.
    static let topUpCount = 10

    /// A league's page. College football's feed can be nothing but AP's
    /// previews for the next slate — all 50 items on 2026-09-27, ESPN's
    /// every filter parameter ignored — so a flooded page is topped up
    /// with the AP Top 10's own stories. Leagues with no poll, and a poll
    /// that won't load, keep the feed as it came.
    static func leaguePage(_ league: League, client: NewsClient = NewsClient()) async -> [NewsStory]? {
        guard let feed = await client.leagueNews(league: league) else { return nil }
        guard NewsMapper.isFlooded(feed),
              let polls = try? await DataProvider.makeClient(league: league).rankings(year: nil),
              let poll = polls.first(where: { $0.type == "ap" }) ?? polls.first
        else { return feed }
        let teams = poll.ranks.sorted { $0.current < $1.current }.prefix(topUpCount).map(\.team.id)
        let teamFeeds = await withTaskGroup(of: [NewsStory]?.self) { group in
            for teamId in teams {
                group.addTask { await client.teamNews(teamId: teamId, league: league) }
            }
            var collected: [[NewsStory]] = []
            for await teamFeed in group { if let teamFeed { collected.append(teamFeed) } }
            return collected
        }
        return NewsMapper.toppedUp(feed, with: teamFeeds)
    }

    /// Every league's page as one (E26), for the Leagues tab's News: each
    /// story once, newest first, previews last. Some leagues failing makes
    /// a thinner list; all of them failing is a failure.
    static func allLeagues(client: NewsClient = NewsClient()) async -> [NewsStory]? {
        let pages = await withTaskGroup(of: [NewsStory]?.self) { group in
            for league in League.allCases {
                group.addTask { await leaguePage(league, client: client) }
            }
            var collected: [[NewsStory]] = []
            for await page in group { if let page { collected.append(page) } }
            return collected
        }
        guard !pages.isEmpty else { return nil }
        return NewsMapper.toppedUp([], with: pages)
    }

    /// Every followed team's own feed, merged. No follows is an empty
    /// list, which the screen answers with a way to add some.
    private static func forYou(followedKeys: Set<String>,
                               client: NewsClient) async -> [NewsStory]? {
        let follows = followedKeys.compactMap(FollowKey.init)
            .sorted { $0.rawValue < $1.rawValue }
            .prefix(forYouCap)
        return await teamsPage(Array(follows), client: client)
    }

    /// Several teams' own feeds as one page: each story once, newest first
    /// — For you's teams, or a conference's members. Some feeds failing
    /// makes a thinner list; all of them failing is a failure.
    static func teamsPage(_ teams: [FollowKey],
                          client: NewsClient = NewsClient()) async -> [NewsStory]? {
        guard !teams.isEmpty else { return [] }
        let feeds = await withTaskGroup(of: [NewsStory]?.self) { group in
            for key in teams {
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
