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
