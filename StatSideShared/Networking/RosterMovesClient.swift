import Foundation

/// A pro league's transaction wire, or one team's — the Trades tab's source.
///
/// **`site.web.api.espn.com`, deliberately.** The same path on
/// `site.api.espn.com` 403s a browser-like User-Agent behind Akamai while
/// answering URLSession's own; the web host answers both (probed
/// 2026-09-27). `TeamStatsClient` and `PlayerStatsClient` made the same
/// call for the same reason.
///
/// **Paged, and by calendar year.** `?page=` walks the year newest first and
/// the response says how many pages there are, so the truncation the
/// scoreboard can't see is visible here. `?season=` is a *calendar* year,
/// not a league season: `season=2025` answers January to December 2025.
/// `?team=` narrows to one team and drops the team object from each row.
/// College football answers `count: 0` — ESPN has no transfer portal.
///
/// Unlike the stats clients this one throws: the tab has a Retry state,
/// and "ESPN answered nothing" and "we couldn't ask" are different claims.
nonisolated struct RosterMovesClient {
    /// Well under the 500 that collapses a `limit` elsewhere (CLAUDE.md's
    /// don'ts). A team's year fits in one page; the NFL's wire is ~17.
    static let pageSize = 100

    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    struct Page: Sendable {
        let moves: [RosterMove]
        let pageIndex: Int
        let pageCount: Int
    }

    struct BadResponse: Error {}

    /// One page of `year`'s wire, or of the current year's when `year` is
    /// nil. `team` scopes the request and stands in for the team object the
    /// scoped response leaves out.
    @concurrent
    func page(league: League, team: Team?, year: Int?, page: Int) async throws -> Page {
        var components = URLComponents(
            string: "https://site.web.api.espn.com/apis/site/v2/sports/"
                + "\(league.sportSegment)/\(league.pathSegment)/transactions")
        var items = [URLQueryItem(name: "limit", value: String(Self.pageSize)),
                     URLQueryItem(name: "page", value: String(page))]
        if let team { items.append(URLQueryItem(name: "team", value: team.id)) }
        if let year { items.append(URLQueryItem(name: "season", value: String(year))) }
        components?.queryItems = items
        guard let url = components?.url else { throw BadResponse() }
        let (data, response) = try await session.data(from: url)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else { throw BadResponse() }
        let dto = try JSONDecoder().decode(TransactionsResponseDTO.self, from: data)
        return RosterMovesMapper.page(from: dto, league: league, team: team)
    }
}

// MARK: - Mapping

nonisolated enum RosterMovesMapper {
    static func page(from dto: TransactionsResponseDTO, league: League, team: Team?) -> RosterMovesClient.Page {
        let moves = (dto.transactions ?? []).compactMap { move(from: $0, league: league, team: team) }
        return RosterMovesClient.Page(moves: moves,
                                      pageIndex: dto.pageIndex ?? 0,
                                      pageCount: dto.pageCount ?? 0)
    }

    static func move(from dto: TransactionDTO, league: League, team fallback: Team?) -> RosterMove? {
        // A row with no sentence has nothing to say.
        guard let text = dto.description?.trimmingCharacters(in: .whitespacesAndNewlines),
              !text.isEmpty else { return nil }
        let team = ESPNMapper.team(from: dto.team, league: league) ?? fallback
        let id = [dto.date ?? "", team?.id ?? "", text].joined(separator: "|")
        return RosterMove(id: id, day: day(from: dto.date), team: team, text: text)
    }

    /// The move's calendar day, as a local start-of-day.
    ///
    /// ESPN stamps every move `T07:00Z` — midnight Pacific, a placeholder
    /// rather than an instant (every row in every league, 2026-09-27). Read
    /// as an instant it lands on the previous evening for Hawaii and Alaska,
    /// the kickoff placeholder's bug (`DayFormat.placeholderKickoff`). The
    /// UTC date is the real part, so that is what survives.
    static func day(from string: String?, calendar: Calendar = .current) -> Date? {
        guard let instant = ESPNDate.parse(string) else { return nil }
        var utc = Calendar(identifier: .gregorian)
        utc.timeZone = .gmt
        return calendar.date(from: utc.dateComponents([.year, .month, .day], from: instant))
    }
}

// MARK: - DTOs

nonisolated struct TransactionsResponseDTO: Decodable {
    let transactions: [TransactionDTO]?
    let pageIndex: Int?
    let pageCount: Int?
}

nonisolated struct TransactionDTO: Decodable {
    let date: String?
    let description: String?
    let team: TeamDTO?
}
