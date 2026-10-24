import Foundation

/// The game page's Standings tab (2026-10-24): every table either side of
/// the matchup sits in, at the scope the chip picks, fetched when the tab
/// first opens and kept for the visit.
///
/// The team page's Standings tab is the template — the same fetches, the
/// same scopes, the same `StandingsList` — widened from one team to two.
/// It lives in a model rather than in the screen's own state because the
/// pane is rebuilt on every tab flip (`.id(tab)`), and a table that
/// re-fetched each time the user came back to it would be the polite-guest
/// rule broken by a swipe.
@Observable
final class GameStandingsModel {
    enum State: Equatable {
        case loading
        case failed
        case loaded([ConferenceStandings])
    }

    /// How wide the tables are. Conference to start, the team page's
    /// default: the matchup's two teams sit in the middle of their own
    /// hierarchy, and the division and the whole league are one tap
    /// either side of it.
    private(set) var scope: StandingsScope = .conference

    /// Which game the tables below were fetched for — the screen's
    /// `loadedKey` guard, a fourth time.
    private var key: String?
    /// The league's conference tables (or college football's conferences,
    /// across every division either side plays in). League scope is built
    /// from these, so it costs nothing extra.
    private var conferences: [ConferenceStandings]?
    /// The divisional tables, fetched only once the chip asks for them —
    /// ESPN's shipped standings response stops at the conferences.
    private var divisions: [ConferenceStandings]?
    private var conferencesFailed = false
    private var divisionsFailed = false
    private var isLoadingConferences = false
    private var isLoadingDivisions = false

    /// The scopes a league can offer. Every pro league nests a conference
    /// and its divisions under one league table, so all three; college
    /// football keeps no 136-team table and nests no divisions, so none,
    /// and the chip hides — the team page's rule.
    static func scopes(in league: League) -> [StandingsScope] {
        Conference.leagueWideId(in: league) == nil ? [] : StandingsScope.allCases
    }

    func select(scope value: StandingsScope) {
        scope = value
    }

    /// What the pane draws for `game` at the current scope.
    func state(for game: Game) -> State {
        guard key == game.routeKey else { return .loading }
        let league = game.home.team.league
        // College football has no scopes, so it reads its conferences
        // whatever the property says.
        let shownScope: StandingsScope? = Self.scopes(in: league).isEmpty ? nil : self.scope
        if shownScope == .division {
            guard let divisions else { return divisionsFailed ? .failed : .loading }
            return .loaded(Self.tables(at: .division, conferences: [], divisions: divisions,
                                       league: league, awayId: game.away.team.id,
                                       homeId: game.home.team.id))
        }
        guard let conferences else { return conferencesFailed ? .failed : .loading }
        return .loaded(Self.tables(at: shownScope, conferences: conferences, divisions: [],
                                   league: league, awayId: game.away.team.id,
                                   homeId: game.home.team.id))
    }

    /// The tables a matchup shows at a scope: the one league table, or
    /// each table either side sits in — away's first, the header's order,
    /// and a shared table once.
    ///
    /// Found by membership rather than by the teams' `conferenceId`: the
    /// table that lists a team is the one it is in, whatever the scoreboard
    /// did or didn't send, which is how `MatchupStandings` finds its two
    /// rows too. A conference's own table beats one of its divisions where
    /// a response carries both, so Conference scope never quietly shows a
    /// division.
    nonisolated static func tables(at scope: StandingsScope?,
                                   conferences: [ConferenceStandings],
                                   divisions: [ConferenceStandings],
                                   league: League,
                                   awayId: String,
                                   homeId: String) -> [ConferenceStandings] {
        let pool: [ConferenceStandings]
        switch scope {
        case .league:
            return conferences.leagueTable(in: league).map { [$0] } ?? []
        case .division:
            pool = divisions.filter { $0.league == league }
        case .conference, nil:
            let own = conferences.filter { $0.league == league }
            pool = own.filter { $0.parentId == nil } + own.filter { $0.parentId != nil }
        }
        var shown: [ConferenceStandings] = []
        for id in [awayId, homeId] where !id.isEmpty {
            guard let table = pool.first(where: { $0.entries.contains { $0.team.id == id } }),
                  !shown.contains(table) else { continue }
            shown.append(table)
        }
        return shown
    }

    /// The season the game belongs to, on its league's clock — what a
    /// past game's tables are asked for, and what the title-game cut is
    /// judged against.
    static func seasonYear(for game: Game) -> Int {
        let league = game.home.team.league
        return game.date.map { SeasonYear.year(for: league, now: $0) }
            ?? SeasonYear.year(for: league)
    }

    /// Fetches what the current scope needs and nothing else. Idempotent:
    /// a seen game at a seen scope is a no-op, so the screen can call this
    /// on every tab appearance and every scope change.
    func load(for game: Game, client: any ScoresProviding, force: Bool = false) async {
        let gameKey = game.routeKey
        if key != gameKey {
            key = gameKey
            scope = .conference
            conferences = nil
            divisions = nil
            conferencesFailed = false
            divisionsFailed = false
        }
        let league = game.home.team.league
        let year = Self.seasonYear(for: game)
        // Nil for the current season keeps the shipped request shape; a
        // past game's page reads that season's tables, membership included.
        let askedYear = year == SeasonYear.year(for: league) ? nil : year
        if scope == .division, !Self.scopes(in: league).isEmpty {
            await loadDivisions(key: gameKey, year: askedYear, client: client, force: force)
        } else {
            await loadConferences(key: gameKey, game: game, year: askedYear,
                                  client: client, force: force)
        }
    }

    private func loadConferences(key gameKey: String, game: Game, year: Int?,
                                 client: any ScoresProviding, force: Bool) async {
        guard force || conferences == nil, !isLoadingConferences else { return }
        isLoadingConferences = true
        defer { isLoadingConferences = false }
        conferencesFailed = false
        // College football's standings come one division at a time, so an
        // FCS visitor needs FCS's tables beside FBS's. The pro leagues
        // ignore the division and answer the whole league once.
        let league = game.home.team.league
        let wanted = league == .collegeFootball
            ? Array(Set([game.away.team, game.home.team].map {
                Conference.division(for: $0.conferenceId, in: league) ?? .fbs
            })).sorted { $0.rawValue < $1.rawValue }
            : [Conference.Division.fbs]
        var fetched: [ConferenceStandings] = []
        var answered = false
        for division in wanted {
            if let tables = try? await client.conferenceStandings(year: year, division: division) {
                fetched += tables
                answered = true
            }
        }
        guard key == gameKey else { return }
        if answered {
            conferences = fetched
        } else if conferences == nil {
            conferencesFailed = true
        }
    }

    private func loadDivisions(key gameKey: String, year: Int?,
                               client: any ScoresProviding, force: Bool) async {
        guard force || divisions == nil, !isLoadingDivisions else { return }
        isLoadingDivisions = true
        defer { isLoadingDivisions = false }
        divisionsFailed = false
        do {
            let tables = try await client.divisionStandings(year: year)
            guard key == gameKey else { return }
            divisions = tables
        } catch {
            guard key == gameKey else { return }
            if divisions == nil { divisionsFailed = true }
        }
    }
}
