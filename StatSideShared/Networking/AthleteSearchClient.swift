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
    func athletes(matching query: String, limit: Int = 10) async throws -> [PlayerIdentity] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }

        var components = URLComponents(
            string: "https://site.web.api.espn.com/apis/search/v2")!
        components.queryItems = [
            URLQueryItem(name: "region", value: "us"),
            URLQueryItem(name: "lang", value: "en"),
            URLQueryItem(name: "query", value: trimmed),
            URLQueryItem(name: "limit", value: String(limit)),
        ]
        guard let url = components.url else { return [] }

        let (data, _) = try await session.data(from: url)
        let payload = try decoder.decode(SearchResponseDTO.self, from: data)

        // The response carries articles and clips beside the people. Only
        // the `player` group is ours, and an unknown group type is skipped
        // rather than guessed at.
        return payload.results?
            .filter { $0.type == "player" }
            .flatMap { $0.contents ?? [] }
            .compactMap(PlayerIdentity.init(searchResult:)) ?? []
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
