import Foundation

/// A team's stories and the body of one (docs/news.md, N4 and N9).
///
/// The game page's story needs none of this: it arrives inside the summary.
/// This is the team page's News tab, which asks `/news?team=` for a feed of
/// headlines, and the reader, which asks the content API for a feed item's
/// text when it opens.
///
/// The player clients' shape: a plain struct, `@concurrent`, and nil on any
/// failure, so the tab can say it couldn't load rather than that there's
/// nothing to read.
nonisolated struct NewsClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// The stories about `teamId`, newest first. Nil when the request failed;
    /// empty when it worked and nothing survived the filters.
    ///
    /// `site.web.api.espn.com`, the stats clients' host: on `site.api` this
    /// path sits behind the same User-Agent rule they found, answering 403
    /// to a browser or empty UA (probed 2026-09-27). Here it answers all
    /// three.
    @concurrent
    func teamNews(teamId: String, league: League) async -> [NewsStory]? {
        let string = "https://site.web.api.espn.com/apis/site/v2/sports/"
            + "\(league.sportSegment)/\(league.pathSegment)/news?team=\(teamId)&limit=25"
        guard let url = URL(string: string),
              let (data, _) = try? await session.data(from: url),
              let dto = try? JSONDecoder().decode(NewsFeedDTO.self, from: data)
        else { return nil }
        return NewsMapper.teamFeed(from: dto, teamId: teamId, league: league)
    }

    /// A league's own feed for the News tab's league pages (E26), newest
    /// first with previews last. Nil when the request failed.
    @concurrent
    func leagueNews(league: League) async -> [NewsStory]? {
        let string = "https://site.web.api.espn.com/apis/site/v2/sports/"
            + "\(league.sportSegment)/\(league.pathSegment)/news?limit=50"
        guard let url = URL(string: string),
              let (data, _) = try? await session.data(from: url),
              let dto = try? JSONDecoder().decode(NewsFeedDTO.self, from: data)
        else { return nil }
        return NewsMapper.leagueFeed(from: dto, league: league)
    }

    /// A player's stories, newest first (E26). From the athlete overview on
    /// `site.web.api`, the stats clients' host; `/news?athlete=` answers
    /// with the league feed. Nil when the request failed.
    @concurrent
    func playerNews(athleteId: String, league: League) async -> [NewsStory]? {
        let string = "https://site.web.api.espn.com/apis/common/v3/sports/"
            + "\(league.sportSegment)/\(league.pathSegment)/athletes/\(athleteId)/overview"
        guard let url = URL(string: string),
              let (data, _) = try? await session.data(from: url),
              let dto = try? JSONDecoder().decode(AthleteOverviewNewsDTO.self, from: data)
        else { return nil }
        return NewsMapper.playerFeed(from: dto, league: league)
    }

    /// A feed item's text, and the attribution the feed didn't carry — the
    /// feed has bylines but no `source`, so an AP story lists as nobody's
    /// and reads as AP's once opened. Nil when the request failed or the
    /// story has no text.
    @concurrent
    func body(of story: NewsStory) async -> (blocks: [StoryBlock], attribution: String?)? {
        guard let url = story.bodyURL,
              let (data, _) = try? await session.data(from: url),
              let dto = try? JSONDecoder().decode(NewsHeadlinesDTO.self, from: data),
              let article = dto.headlines?.elements.first
        else { return nil }
        let blocks = StoryText.blocks(fromHTML: article.story ?? "")
        guard !blocks.isEmpty else { return nil }
        return (blocks, NewsMapper.attribution(byline: article.byline, source: article.source))
    }
}

// MARK: - Mapping

nonisolated enum NewsMapper {
    /// A story the app will show, or nil: an unshown type (N10), no
    /// headline, or no way to get its text — a list row that opens onto
    /// nothing is worse than no row (N4).
    static func story(from dto: NewsArticleDTO, league: League) -> NewsStory? {
        guard let kind = NewsStory.Kind(espnType: dto.type),
              let id = dto.id?.value,
              let headline = dto.headline?.trimmingCharacters(in: .whitespacesAndNewlines),
              !headline.isEmpty
        else { return nil }
        let body = dto.story.map(StoryText.blocks(fromHTML:)).flatMap { $0.isEmpty ? nil : $0 }
        let bodyURL = dto.links?.api?.selfLink?.href.flatMap(URL.init(string:))
        guard body != nil || bodyURL != nil else { return nil }

        let categories = dto.categories?.elements ?? []
        var seen: Set<String> = []
        let teams = categories.compactMap { category -> NewsStory.TeamTag? in
            guard category.type == "team", let id = category.teamId?.value.map(String.init),
                  seen.insert(id).inserted else { return nil }
            return NewsStory.TeamTag(id: id, name: category.description ?? "")
        }
        let eventId = categories.first { $0.type == "event" }?.eventId?.value
        return NewsStory(
            id: String(id),
            kind: kind,
            league: league,
            headline: headline,
            dek: dek(dto.description),
            attribution: attribution(byline: dto.byline, source: dto.source),
            published: ESPNDate.parse(dto.published),
            gameId: (dto.gameId?.value ?? eventId).map(String.init),
            teams: teams,
            body: body,
            bodyURL: body == nil ? bodyURL : nil
        )
    }

    /// The team's feed after both filters: types the app shows, and stories
    /// about this team rather than roundups that tag it (N9). Newest first,
    /// whatever order ESPN sent.
    static func teamFeed(from dto: NewsFeedDTO, teamId: String, league: League) -> [NewsStory] {
        (dto.articles?.elements ?? [])
            .compactMap { story(from: $0, league: league) }
            .filter { $0.isFocused(on: teamId) }
            .sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
    }

    /// A league's feed (E26): the types the app shows, newest first, and
    /// **previews last**. ESPN's college-football feed floods with AP's
    /// previews for the next slate — on 2026-09-27 all 50 items were
    /// previews published within four minutes of each other — and a tab
    /// that leads with 50 of them buries every other story. Demoted rather
    /// than dropped: on a quiet day they're what there is.
    static func leagueFeed(from dto: NewsFeedDTO, league: League) -> [NewsStory] {
        (dto.articles?.elements ?? [])
            .compactMap { story(from: $0, league: league) }
            .sorted { lhs, rhs in
                let lhsPreview = lhs.kind == .preview, rhsPreview = rhs.kind == .preview
                if lhsPreview != rhsPreview { return rhsPreview }
                return (lhs.published ?? .distantPast) > (rhs.published ?? .distantPast)
            }
    }

    /// A player's feed (E26): the types the app shows, each once, newest
    /// first. ESPN picked these for the player, so no team filter applies.
    static func playerFeed(from dto: AthleteOverviewNewsDTO, league: League) -> [NewsStory] {
        forYou([(dto.news?.elements ?? []).compactMap { story(from: $0, league: league) }])
    }

    /// The fewest real stories a league page can show before it asks for
    /// more. Below it, the feed is a preview flood rather than a news day.
    static let floodFloor = 10

    /// Whether a league page is drowning in previews: fewer than
    /// `floodFloor` stories that aren't one.
    static func isFlooded(_ stories: [NewsStory]) -> Bool {
        stories.filter { $0.kind != .preview }.count < floodFloor
    }

    /// A flooded league page, topped up with the ranked teams' own stories
    /// (E26). Each story once, newest first, previews still last.
    static func toppedUp(_ feed: [NewsStory], with teamFeeds: [[NewsStory]]) -> [NewsStory] {
        var seen: Set<String> = []
        return ([feed] + teamFeeds).joined()
            .filter { seen.insert($0.id).inserted }
            .sorted { lhs, rhs in
                let lhsPreview = lhs.kind == .preview, rhsPreview = rhs.kind == .preview
                if lhsPreview != rhsPreview { return rhsPreview }
                return (lhs.published ?? .distantPast) > (rhs.published ?? .distantPast)
            }
    }

    /// For you (E26): every followed team's own stories in one list, each
    /// story once — a recap tags both teams, and a user may follow both —
    /// newest first. Follows carry no order of their own (the Teams tab
    /// lists them alphabetically), so time is the only honest ranking.
    static func forYou(_ feeds: [[NewsStory]]) -> [NewsStory] {
        var seen: Set<String> = []
        return feeds.joined()
            .filter { seen.insert($0.id).inserted }
            .sorted { ($0.published ?? .distantPast) > ($1.published ?? .distantPast) }
    }

    /// A byline wins; else the wire, shortened where it has a short name.
    static func attribution(byline: String?, source: String?) -> String? {
        let byline = byline?.trimmingCharacters(in: .whitespaces)
        if let byline, !byline.isEmpty { return byline }
        switch source?.trimmingCharacters(in: .whitespaces) {
        case nil, "": return nil
        case "Associated Press": return "AP"
        case let source?: return source
        }
    }

    /// AP deks open with the same stray dash the dateline carries
    /// ("— Karl-Anthony Towns had 26 points…"); it isn't part of the dek.
    private static func dek(_ description: String?) -> String? {
        guard let description else { return nil }
        let trimmed = description
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "—– "))
        return trimmed.isEmpty ? nil : StoryText.decodingEntities(trimmed)
    }
}
