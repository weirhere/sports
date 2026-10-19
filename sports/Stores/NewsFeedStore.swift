import Foundation

/// The News tab's feeds (E26; reshaped 2026-10-19): For you, Latest,
/// Transfers and Leagues.
///
/// All four read the same four league feeds, so those are fetched once
/// and held for the session — Latest, Transfers and the Leagues page are
/// views of that one list — and For you adds one request per followed
/// team it shows. Pull to refresh asks again. Never polled: a story isn't
/// live data, and the scoreboard's 1s cadence would be ESPN's news API
/// asked a question it answers every few hours.
@Observable
final class NewsFeedStore {
    /// The tab row's pages, in order (Andy, 2026-10-19): yours, then the
    /// two cross-league streams, then the leagues one by one.
    enum Feed: Int, CaseIterable, HeroTabItem {
        case forYou, latest, transfers, leagues

        var title: String {
            switch self {
            case .forYou: "For you"
            case .latest: "Latest"
            case .transfers: "Transfers"
            case .leagues: "Leagues"
            }
        }
    }

    enum LoadState {
        case loading
        case loaded
        case failed
    }

    /// For you's own part (Andy, 2026-09-27): each followed team's stories,
    /// by follow key. A team whose feed failed or came back empty isn't
    /// here. Trending reads the shared league list.
    struct ForYouPage {
        var teams: [String: [NewsStory]]
    }

    /// Trending's size, and a league's share of the Leagues page: the
    /// featured story and four under it.
    static let sectionSize = 5
    /// Latest is full-width photo cards; past this it's a scroll nobody
    /// finishes.
    static let latestCap = 30

    /// For you asks each followed team's own feed, so it costs a request
    /// per follow. Capped so a user following the whole SEC doesn't open
    /// the tab onto forty requests.
    static let forYouCap = 20

    /// How many of the poll's teams top up a flooded page. Ten is a
    /// Saturday's headline programs, at ten requests, only on a flood day.
    static let topUpCount = 10

    /// Each league's page, newest first, previews last, topped up when
    /// flooded. A league whose refresh failed keeps its last page.
    private(set) var leaguePages: [League: [NewsStory]] = [:]
    /// Every league's page as one: each story once, newest first,
    /// previews last. What Latest, Transfers and Trending are cut from.
    private(set) var merged: [NewsStory] = []
    private(set) var forYouPage: ForYouPage?

    private var leaguesState: LoadState?
    private var forYouState: LoadState?
    /// The follows For you was built from: one added, dropped or hidden
    /// since makes it stale, and the next visit rebuilds it.
    private var forYouKeys: Set<String>?
    /// The league fetch in flight, so a second page asking for it waits
    /// on the same request rather than starting another.
    private var leaguesTask: Task<Bool, Never>?
    private var forYouInFlight = false

    func state(_ feed: Feed) -> LoadState {
        (feed == .forYou ? forYouState : leaguesState) ?? .loading
    }

    var latest: [NewsStory] { Array(merged.prefix(Self.latestCap)) }

    /// The roster moves in every league's feed (Andy, 2026-10-19). Thin by
    /// nature, so uncapped.
    var transfers: [NewsStory] { merged.filter(\.isTransaction) }

    /// The newest real stories across the four leagues — recency, not
    /// popularity, which ESPN doesn't publish.
    var trending: [NewsStory] {
        Array(merged.filter { $0.kind != .preview }.prefix(Self.sectionSize))
    }

    func stories(in league: League) -> [NewsStory] { leaguePages[league] ?? [] }

    /// Loads what `feed` needs unless it's already held. A refresh that
    /// fails keeps the page on screen rather than trading it for an error.
    func load(_ feed: Feed, followedKeys: Set<String>, force: Bool = false) async {
        if feed == .forYou {
            await loadForYou(followedKeys: followedKeys, force: force)
        } else {
            await loadLeagues(force: force)
        }
    }

    // MARK: - The leagues

    /// Fetches the four league pages once; later callers get the held
    /// pages, and callers during the fetch wait on it. True when there
    /// are pages to show.
    @discardableResult
    func loadLeagues(force: Bool = false) async -> Bool {
        if !force, case .loaded = leaguesState { return true }
        if let leaguesTask { return await leaguesTask.value }
        let task = Task { await fetchLeagues() }
        leaguesTask = task
        let loaded = await task.value
        leaguesTask = nil
        return loaded
    }

    private func fetchLeagues() async -> Bool {
        if case .loaded = leaguesState {} else { leaguesState = .loading }
        let client = NewsClient()
        let pages = await withTaskGroup(of: (League, [NewsStory]?).self) { group in
            for league in League.allCases {
                group.addTask {
                    let page = await Self.leaguePage(league, client: client)
                    return (league, page)
                }
            }
            var collected: [League: [NewsStory]] = [:]
            for await (league, page) in group { if let page { collected[league] = page } }
            return collected
        }
        guard !pages.isEmpty else {
            // Some leagues failing makes a thinner list; all of them
            // failing is a failure — unless there's a page to keep.
            if case .loaded = leaguesState { return true }
            leaguesState = .failed
            return false
        }
        leaguePages.merge(pages) { _, fresh in fresh }
        merged = NewsMapper.toppedUp([], with: League.allCases.compactMap { leaguePages[$0] })
        leaguesState = .loaded
        return true
    }

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

    // MARK: - For you

    /// The league pages and each shown follow's own feed, side by side.
    /// Failed only when all of it failed.
    private func loadForYou(followedKeys: Set<String>, force: Bool) async {
        let stale = forYouKeys != nil && forYouKeys != followedKeys
        if !force, !stale, case .loaded = forYouState { return }
        guard !forYouInFlight else { return }
        forYouInFlight = true
        defer { forYouInFlight = false }
        if stale {
            forYouState = .loading
        } else if case .loaded = forYouState {
            // Keep the page up while it refreshes.
        } else {
            forYouState = .loading
        }

        async let leaguesLoaded = loadLeagues(force: force)
        let follows = followedKeys.compactMap(FollowKey.init)
            .sorted { $0.rawValue < $1.rawValue }
            .prefix(Self.forYouCap)
        let teamFeeds = await Self.teamFeeds(for: Array(follows), client: NewsClient())
        let hasLeagues = await leaguesLoaded
        // A page re-keyed out from under this load shouldn't write a
        // failure its cancelled requests only look like.
        guard !Task.isCancelled else { return }

        if hasLeagues || teamFeeds.answered > 0 {
            forYouPage = ForYouPage(teams: teamFeeds.teams)
            forYouState = .loaded
            forYouKeys = followedKeys
        } else if case .loaded = forYouState {
            // Keep what's on screen.
        } else {
            forYouState = .failed
        }
    }

    /// Each follow's own feed, by key, and how many feeds answered at all
    /// — an empty feed answered; a failed one didn't.
    static func teamFeeds(for follows: [FollowKey],
                          client: NewsClient) async -> (teams: [String: [NewsStory]], answered: Int) {
        await withTaskGroup(of: (String, [NewsStory]?).self) { group in
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
    }

    /// Several teams' own feeds as one page: each story once, newest first
    /// — a conference's members. Some feeds failing makes a thinner list;
    /// all of them failing is a failure.
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
