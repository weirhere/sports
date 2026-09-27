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

    /// For you, in FotMob's sections (Andy, 2026-09-27): Trending, one
    /// section per followed team, then Latest.
    struct ForYouPage {
        /// The newest real stories across the four leagues — recency, not
        /// popularity, which ESPN doesn't publish.
        var trending: [NewsStory]
        /// Each followed team's own stories, by follow key. A team whose
        /// feed failed or came back empty isn't here.
        var teams: [String: [NewsStory]]
        /// Every league's stories, newest first, previews last.
        var latest: [NewsStory]
    }

    /// Trending's size: the featured story and four under it.
    static let sectionSize = 5
    /// Latest is full-width photo cards; past this it's a scroll nobody
    /// finishes.
    static let latestCap = 30

    /// For you asks each followed team's own feed, so it costs a request
    /// per follow. Capped so a user following the whole SEC doesn't open
    /// the tab onto forty requests.
    static let forYouCap = 20

    private(set) var states: [Feed: LoadState] = [:]
    /// For you's sections, built by the same load as its `.forYou` state.
    private(set) var forYouPage: ForYouPage?
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
        } else if let page = await Self.forYouPage(followedKeys: followedKeys, client: client) {
            forYouPage = page
            result = page.latest
        } else {
            result = nil
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

    /// Every league's page as one (E26), for For you's Trending and Latest: each
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

    /// For you's sections: every league at once (Trending and Latest) and
    /// each followed team's own feed, side by side. Nil only when all of
    /// it failed.
    static func forYouPage(followedKeys: Set<String>,
                           client: NewsClient = NewsClient()) async -> ForYouPage? {
        let follows = followedKeys.compactMap(FollowKey.init)
            .sorted { $0.rawValue < $1.rawValue }
            .prefix(forYouCap)
        async let leagues = allLeagues(client: client)
        let teamFeeds = await withTaskGroup(of: (String, [NewsStory]?).self) { group in
            for key in follows {
                group.addTask { (key.rawValue, await client.teamNews(teamId: key.teamId, league: key.league)) }
            }
            var collected: [String: [NewsStory]] = [:]
            var answered = 0
            for await (key, feed) in group {
                guard let feed else { continue }
                answered += 1
                if !feed.isEmpty { collected[key] = feed }
            }
            return (collected, answered)
        }
        let all = await leagues
        guard all != nil || teamFeeds.1 > 0 else { return nil }
        let latest = all ?? []
        return ForYouPage(
            trending: Array(latest.filter { $0.kind != .preview }.prefix(sectionSize)),
            teams: teamFeeds.0,
            latest: Array(latest.prefix(latestCap))
        )
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
