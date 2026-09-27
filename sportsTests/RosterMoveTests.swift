import Foundation
import Testing
@testable import StatSide

private final class RosterMoveFixtureToken {}

private func loadPage(_ name: String, _ league: League, team: Team? = nil) throws -> RosterMovesClient.Page {
    let url = try #require(
        Bundle(for: RosterMoveFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    let dto = try JSONDecoder().decode(TransactionsResponseDTO.self, from: Data(contentsOf: url))
    return RosterMovesMapper.page(from: dto, league: league, team: team)
}

private func makeMove(_ text: String, day: Date? = nil) -> RosterMove {
    RosterMove(id: text, day: day, team: nil, text: text)
}

private func verbs(_ move: RosterMove) -> [String] {
    move.verbRanges.map { String(move.text[$0]) }
}

/// Captured live on 2026-09-27 from `site.web.api.espn.com`: the NBA's
/// league-wide wire, the Chiefs' own (`?team=12`, which drops the team
/// object from every row), and college football's, which is empty.
@Suite struct RosterMoveTests {

    // MARK: Mapping

    @Test func aLeaguePageCarriesEachRowsTeamAndThePageCount() throws {
        let page = try loadPage("nba-transactions", .nba)
        #expect(page.moves.count == 6)
        #expect(page.pageIndex == 1)
        #expect(page.pageCount == 59)
        #expect(page.moves.first?.team?.abbreviation == "CHA")
        #expect(page.moves.first?.team?.league == .nba)
        #expect(page.moves.first?.text == "Acquired G Rob Dillingham from Chicago Bulls for G Buddy Hield.")
    }

    /// A trade is each side's own row, in its own words — never merged.
    @Test func aTradeArrivesAsBothSidesRows() throws {
        let moves = try loadPage("nba-transactions", .nba).moves
        #expect(moves[0].team?.abbreviation == "CHA")
        #expect(moves[1].team?.abbreviation == "CHI")
        #expect(moves[1].text.hasPrefix("Acquired G Buddy Hield from Charlotte"))
    }

    @Test func aTeamScopedPageBorrowsThePagesTeam() throws {
        let chiefs = Team(id: "12", location: "Kansas City", name: "Chiefs", abbreviation: "KC",
                          displayName: "Kansas City Chiefs", shortDisplayName: nil, logoURL: nil,
                          conferenceId: nil, league: .nfl)
        let page = try loadPage("nfl-team-transactions", .nfl, team: chiefs)
        #expect(page.moves.count == 6)
        #expect(page.moves.allSatisfy { $0.team?.id == "12" })
    }

    @Test func collegeFootballHasNoWire() throws {
        let page = try loadPage("cfb-transactions-empty", .collegeFootball)
        #expect(page.moves.isEmpty)
        #expect(page.pageCount == 0)
    }

    /// `T07:00Z` is ESPN's placeholder, midnight Pacific. The calendar date
    /// is the fact, wherever the reader is — Honolulu included, where the
    /// instant falls on the evening before.
    @Test func aMovesDayIsItsCalendarDateInEveryZone() throws {
        for zone in ["America/New_York", "America/Los_Angeles", "Pacific/Honolulu", "Asia/Tokyo"] {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = try #require(TimeZone(identifier: zone))
            let day = try #require(RosterMovesMapper.day(from: "2026-09-27T07:00Z", calendar: calendar))
            let parts = calendar.dateComponents([.year, .month, .day, .hour], from: day)
            #expect(parts.year == 2026 && parts.month == 9 && parts.day == 27 && parts.hour == 0,
                    "wrong day in \(zone)")
        }
    }

    // MARK: Reading the sentence

    @Test func eachMoveInASentenceHasItsVerb() {
        let move = makeMove("Waived G DJ Armstrong and C Tre Carroll. Acquired Gs Buddy Hield, Ryan Nembhard "
            + "and cash considerations from Atlanta in exchange for F Dorian Finney-Smith.")
        #expect(verbs(move) == ["Waived", "Acquired"])
        #expect(move.kind == .signingOrTrade)
    }

    /// Names are full of full stops. Only a known verb starts a new move,
    /// so "Hanson" is never set in semibold as though it were an action.
    @Test func initialsDoNotStartAMove() {
        let move = makeMove("Signed TE Thomas Odukoya. Released RD EJ Smith, QB Chris Oladokun and G C.J. "
            + "Hanson from injured reserve with an injury settlement.")
        #expect(verbs(move) == ["Signed", "Released"])
    }

    @Test func aDoubledFullStopAfterJuniorIsLeftAlone() {
        let move = makeMove("Waived Fs Gabe Levin and Tyrone Marshall Jr..")
        #expect(verbs(move) == ["Waived"])
        #expect(move.kind == .routine)
    }

    @Test func practiceSquadElevationsAreRoutine() {
        #expect(makeMove("Elevated LB Cole Christiansen and DE Tyreke Smith from the practice squad "
            + "to the active roster.").kind == .routine)
    }

    /// ESPN's typing is taken as found: "PLaced" still reads as placed.
    @Test func aMiscasedVerbStillReads() {
        #expect(makeMove("PLaced WR Rashee Rice on injured reserve.").kind == .routine)
    }

    /// One signing in a sentence of releases puts the row in the default
    /// view — the filter can hide noise but never news.
    @Test func oneSigningMakesTheRowNews() {
        #expect(makeMove("Signed DT Marcus Harris to the practice squad. Released DT Cole Brevard "
            + "from the practice squad.").kind == .signingOrTrade)
    }

    /// A verb we've never seen fails open.
    @Test func anUnknownVerbShowsByDefault() {
        #expect(makeMove("Announced the retirement of C Joe Thornton.").kind == .signingOrTrade)
        #expect(makeMove("Elevatd DB Te'Cory Couch to the active roster.").kind == .signingOrTrade)
    }

    @Test func theFilterHidesOnlyRoutineMoves() {
        let routine = makeMove("Waived G Kyle Mangas.")
        let signing = makeMove("Re-signed F Dwight Powell.")
        #expect(!RosterMove.Filter.signingsAndTrades.shows(routine))
        #expect(RosterMove.Filter.signingsAndTrades.shows(signing))
        #expect(RosterMove.Filter.all.shows(routine))
    }

    // MARK: Day cards

    @Test func daysAreNewestFirstWithTodayAndYesterdayNamed() throws {
        let calendar = Calendar.current
        let now = try #require(calendar.date(from: DateComponents(year: 2026, month: 9, day: 27, hour: 15)))
        let day = { (offset: Int) in calendar.date(byAdding: .day, value: offset,
                                                   to: calendar.startOfDay(for: now)) }
        let days = RosterMoveDays.days(from: [
            makeMove("Signed A.", day: day(-4)),
            makeMove("Signed B.", day: day(0)),
            makeMove("Signed C.", day: nil),
            makeMove("Signed D.", day: day(-1)),
            makeMove("Signed E.", day: day(0)),
        ], now: now, calendar: calendar)
        #expect(days.map(\.title).prefix(2) == ["Today", "Yesterday"])
        #expect(days.last?.title == "Date TBA")
        #expect(days.count == 4)
        #expect(days.first?.moves.map(\.text) == ["Signed B.", "Signed E."])
    }
}
