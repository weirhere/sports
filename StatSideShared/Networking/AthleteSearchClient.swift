import Foundation

/// ESPN's own search, which is how athletes reach the search box.
///
/// Its own client rather than a method on `ESPNClient`, because that type is
/// league-scoped by construction — it builds a base URL per league in `init`
/// — and this endpoint is league-agnostic: one request answers for all four
/// at once. Hanging it off a league-scoped client would mean either four
/// identical requests or a league parameter that does nothing.
///
/// **Why this exists at all.** Search's other corpora are already in memory
/// (the team directory, the conference registry, the slate), which is why
/// typing costs nothing. Athletes have no such corpus: the roster endpoint
/// is per team, so covering four leagues means ~228 fetches for an index
/// that goes stale weekly. This endpoint is the one request that does it,
/// and it was confirmed live on 2026-09-21 before a line of this was
/// written — `scripts/probe-athlete.sh`, three names across three leagues,
/// three candidate paths, all 200.
nonisolated struct AthleteSearchClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Athletes matching `query`, in the four leagues this app covers.
    ///
    /// Returns `[]` rather than throwing on an empty or whitespace query, so
    /// a cleared search field costs no request.
    /// `@concurrent` so the request and the decode leave the caller's actor.
    /// Under approachable concurrency a plain `nonisolated async` func runs
    /// on whoever called it, which from `SearchScreen` is the main thread —
    /// decoding a search payload per debounced keystroke, mid-typing
    /// (2026-09-24).
    @concurrent
    func athletes(matching query: String, limit: Int = 10) async throws -> [PlayerIdentity] {
        try await search(matching: query, limit: limit).athletes
    }

    /// The people and the stories one query found (E26). The response
    /// already carries both, so Search's News scope costs no request of
    /// its own.
    @concurrent
    func search(matching query: String, limit: Int = 10) async throws
        -> (athletes: [PlayerIdentity], stories: [NewsStory]) {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return ([], []) }

        var components = URLComponents(
            string: "https://site.web.api.espn.com/apis/search/v2")!
        components.queryItems = [
            URLQueryItem(name: "region", value: "us"),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components.url else { return ([], []) }

        let (data, _) = try await session.data(from: url)
        let payload = try decoder.decode(SearchResponseDTO.self, from: data)
        return (Self.athletes(in: payload), Self.stories(in: payload))
    }

    /// The response carries articles and clips beside the people. Only the
    /// `player` group is people, and an unknown group type is skipped
    /// rather than guessed at.
    static func athletes(in payload: SearchResponseDTO) -> [PlayerIdentity] {
        contents(of: "player", in: payload).compactMap(PlayerIdentity.init(searchResult:))
    }

    /// The `article` group, in the order ESPN ranked it for the query.
    /// Clips and replays are video, which N10 keeps out of every list.
    static func stories(in payload: SearchResponseDTO) -> [NewsStory] {
        var seen: Set<String> = []
        return contents(of: "article", in: payload)
            .compactMap(NewsMapper.story(fromSearchResult:))
            .filter { seen.insert($0.id).inserted }
    }

    private static func contents(of type: String, in payload: SearchResponseDTO) -> [SearchContentDTO] {
        (payload.results ?? []).filter { $0.type == type }.flatMap { $0.contents ?? [] }
    }
}

// MARK: - DTOs

nonisolated struct SearchResponseDTO: Decodable {
    let results: [SearchGroupDTO]?
}

nonisolated struct SearchGroupDTO: Decodable {
    let type: String?
    let contents: [SearchContentDTO]?
}

nonisolated struct SearchContentDTO: Decodable {
    /// `s:70~l:90~a:3895074`. **The athlete id lives here and nowhere
    /// convenient.** The sibling `id` is a GUID
    /// (`8e2e22e8-01b6-8acb-8a50-47f4941b52c6`) that no other ESPN endpoint
    /// accepts, so a page built from it would fetch nothing — verified
    /// against a live payload 2026-09-21, which is the whole reason the DTO
    /// rule says probe before decoding.
    let uid: String?
    let displayName: String?
    /// The team, as a display string — "Edmonton Oilers". Search does not
    /// carry a team id, so a result cannot resolve to a `Team`.
    let subtitle: String?
    /// `college-football`, `nfl`, `nba`, `nhl` — and `wnba`, `mlb` and the
    /// rest, which is why this is filtered rather than trusted.
    let defaultLeagueSlug: String?
    let image: SearchImageDTO?
    /// An article's story id (`50039929`), the one the content API takes.
    /// A person's is the GUID above.
    let id: String?
    /// An article's ESPN type, lowercased here: `headlinenews`, `story`,
    /// `recap`, `preview`.
    let type: String?
    let link: SearchLinkDTO?
    /// An article's byline, or its wire: "Associated Press", "ESPN".
    let byline: String?
    let date: String?
}

nonisolated struct SearchLinkDTO: Decodable {
    /// `https://www.espn.com/nba/story/_/id/…`. The path's first segment is
    /// the only league an article hit carries.
    let web: String?
}

nonisolated struct SearchImageDTO: Decodable {
    let `default`: URL?
}

nonisolated extension PlayerIdentity {
    /// A search hit, as far as it goes.
    ///
    /// `nil` for anyone outside the four leagues — ESPN indexes every sport
    /// it covers, so a query for a common surname returns soccer and
    /// baseball players this app has no page for. Dropping them is the only
    /// honest answer: a row that opens an empty page is worse than no row.
    init?(searchResult content: SearchContentDTO) {
        guard let uid = content.uid,
              let athleteId = Self.athleteId(fromUID: uid),
              let name = content.displayName,
              let slug = content.defaultLeagueSlug,
              let league = League.allCases.first(where: { $0.pathSegment == slug })
        else { return nil }

        self.init(athleteId: athleteId,
                  name: name,
                  league: league,
                  teamName: content.subtitle,
                  teamLogoURL: nil)
        // Search serves a headshot and no team mark; the page's team badge
        // fills in once the roster row behind it loads.
        headshotURL = content.image?.default
    }

    /// Pulls `3895074` out of `s:70~l:90~a:3895074`.
    ///
    /// Tilde-separated `key:value` pairs. Parsed rather than pattern-matched
    /// so an extra or reordered segment can't shift the answer.
    static func athleteId(fromUID uid: String) -> String? {
        uid.split(separator: "~")
            .first { $0.hasPrefix("a:") }
            .map { String($0.dropFirst(2)) }
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}

// MARK: - Athlete profile

/// The facts behind a player page, for the door that arrives without them.
///
/// A player reached from a roster already carries height, weight, position
/// and the rest — the roster row had them, and `PlayerIdentity` brings them
/// through the push. A player reached from **search** carries a name, a
/// league, a club and a headshot, and nothing else: ESPN's search index does
/// not serve a body. So the page opened empty (Andy, 2026-09-21: *"the
/// player page has no information"*).
///
/// This is the fetch that fills it. `web/src/lib/player-profile.ts` says in
/// its own header that no athlete endpoint had been proved out — that was
/// true when it was written and stopped being true on 2026-09-21, when
/// `scripts/probe-athlete.sh` finally ran and answered 200 in every league.
/// The web twin can drop its caveat whenever someone ports this.
nonisolated struct AthleteProfileClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fills in everything a search result couldn't carry. Returns the
    /// identity unchanged on any failure: a page that shows a name and a
    /// club is the state we started from, and an error banner over it would
    /// be louder than the thing it is apologising for.
    /// Returns the team id alongside the player: the payload names the club
    /// by id, and only the app's directory can turn that into a `Team` the
    /// hero badge can push to. This type has no directory and shouldn't.
    /// `@concurrent` for the reason `athletes(matching:)` gives: off the
    /// caller's actor, so the profile decode doesn't land on the main
    /// thread during the player page's push.
    @concurrent
    func filling(_ player: PlayerIdentity) async -> (player: PlayerIdentity, teamId: String?) {
        let league = player.league
        let url = URL(string: "https://site.web.api.espn.com/apis/common/v3/sports/"
                      + "\(league.sportSegment)/\(league.pathSegment)/athletes/\(player.athleteId)")
        guard let url else { return (player, nil) }
        guard let (data, _) = try? await session.data(from: url),
              let payload = try? decoder.decode(AthleteProfileResponseDTO.self, from: data),
              let athlete = payload.athlete
        else { return (player, nil) }

        var filled = player
        filled.age = filled.age ?? athlete.age
        filled.jersey = filled.jersey ?? athlete.jersey
        filled.position = filled.position ?? athlete.position?.abbreviation
        filled.positionName = filled.positionName ?? athlete.position?.displayName
        filled.height = filled.height ?? athlete.displayHeight
        filled.weight = filled.weight ?? athlete.displayWeight
        filled.headshotURL = filled.headshotURL ?? athlete.headshot?.href
        // `status` is the roster's injury line in the other door's data, and
        // ESPN says "Active" here for everyone who isn't hurt — which is not
        // a fact worth a row of its own.
        if let status = athlete.status?.type, status != "active" {
            filled.injuryStatus = filled.injuryStatus ?? athlete.status?.name
        }
        return (filled, athlete.team?.id)
    }
}

nonisolated struct AthleteProfileResponseDTO: Decodable {
    let athlete: ProfileAthleteDTO?
}

nonisolated struct ProfileAthleteDTO: Decodable {
    /// Present for the pro leagues; nil for college football, whose roster
    /// metric is the class year rather than an age, so nothing is lost.
    let age: Int?
    let team: ProfileTeamDTO?
    let jersey: String?
    let displayHeight: String?
    let displayWeight: String?
    let position: ProfilePositionDTO?
    let headshot: ProfileHeadshotDTO?
    let status: ProfileStatusDTO?
}

nonisolated struct ProfileTeamDTO: Decodable {
    let id: String?
}

nonisolated struct ProfilePositionDTO: Decodable {
    let abbreviation: String?
    let displayName: String?
}

nonisolated struct ProfileHeadshotDTO: Decodable {
    let href: URL?
}

nonisolated struct ProfileStatusDTO: Decodable {
    let name: String?
    let type: String?
}

nonisolated extension NewsMapper {
    /// A search hit as a story (E26), or nil: an unshown type, no headline,
    /// or a league the app doesn't cover. Search sends no teams, no dek
    /// and no text, so the reader asks the content API by id.
    static func story(fromSearchResult content: SearchContentDTO) -> NewsStory? {
        guard let kind = NewsStory.Kind(espnType: content.type),
              let id = content.id, !id.isEmpty, id.allSatisfy(\.isNumber),
              let headline = content.displayName?.trimmingCharacters(in: .whitespacesAndNewlines),
              !headline.isEmpty,
              let league = league(fromStoryLink: content.link?.web),
              let bodyURL = URL(string: "https://content.core.api.espn.com/v1/sports/news/\(id)")
        else { return nil }
        return NewsStory(
            id: id,
            kind: kind,
            league: league,
            headline: StoryText.decodingEntities(headline),
            dek: nil,
            // The field is a byline or a wire, and nothing says which.
            attribution: attribution(byline: nil, source: content.byline),
            published: searchDate(content.date),
            gameId: gameId(fromStoryLink: content.link?.web),
            teams: [],
            body: nil,
            bodyURL: bodyURL
        )
    }

    /// Search's dates carry milliseconds (`2026-09-27T05:09:02.000+00:00`),
    /// which the feeds' parser doesn't read.
    private static func searchDate(_ string: String?) -> Date? {
        guard let string else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return formatter.date(from: string) ?? ESPNDate.parse(string)
    }

    /// `https://www.espn.com/college-football/story/…` → college football.
    /// AP's recaps and previews link through ESPN's older paths
    /// (`/ncf/recap?gameId=…`), where college football is `ncf`.
    static func league(fromStoryLink link: String?) -> League? {
        guard let link, let url = URL(string: link),
              let segment = url.pathComponents.dropFirst().first
        else { return nil }
        if segment == "ncf" { return .collegeFootball }
        return League.allCases.first { $0.pathSegment == segment }
    }

    /// A recap's or preview's game, from that older path's query.
    static func gameId(fromStoryLink link: String?) -> String? {
        guard let link else { return nil }
        return URLComponents(string: link)?.queryItems?
            .first { $0.name == "gameId" }?.value
            .flatMap { $0.isEmpty ? nil : $0 }
    }
}
