import Foundation
import Testing
@testable import StatSide

// 2026-09-24, Coard Miller: the spread and the total are how a fan picks
// which games to follow. The line is read out of the summary the game page
// already fetches, narrowed to those two numbers, and shown before kickoff
// only.

private final class GameLineFixtureToken {}

private func summaryJSON(_ name: String) throws -> [String: Any] {
    let url = try #require(
        Bundle(for: GameLineFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    let object = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
    return try #require(object as? [String: Any])
}

private func summary(from json: [String: Any]) throws -> GameSummary {
    let data = try JSONSerialization.data(withJSONObject: json)
    return ESPNMapper.gameSummary(from: try JSONDecoder().decode(SummaryResponseDTO.self, from: data))
}

/// The fixture with its header status rewritten, since every captured
/// summary we hold is a final.
private func withState(_ state: String, _ json: [String: Any]) throws -> [String: Any] {
    var json = json
    var header = try #require(json["header"] as? [String: Any])
    var competitions = try #require(header["competitions"] as? [[String: Any]])
    var status = try #require(competitions[0]["status"] as? [String: Any])
    var type = try #require(status["type"] as? [String: Any])
    type["state"] = state
    status["type"] = type
    competitions[0]["status"] = status
    header["competitions"] = competitions
    json["header"] = header
    return json
}

private func game(status: GameStatus) -> Game {
    func team(_ id: String) -> Team {
        Team(id: id, location: "Team \(id)", name: nil, abbreviation: "T\(id)",
             displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 8)
    }
    return Game(id: "g", date: nil, name: nil, shortName: nil, weekNumber: 1, status: status,
                home: Competitor(team: team("1"), score: nil, record: nil, rank: nil, isHome: true, winner: nil),
                away: Competitor(team: team("2"), score: nil, record: nil, rank: nil, isHome: false, winner: nil),
                broadcast: nil)
}

@Suite struct GameLineTests {
    // MARK: - Decoding, all three leagues that ship one

    @Test func footballReadsTheSpreadAndTheTotal() throws {
        let line = try #require(try summary(from: summaryJSON("summary-final-live")).line)
        #expect(line.details == "IU -7.5")
        #expect(line.overUnder == 47.5)
        #expect(line.text == "IU -7.5 · O/U 47.5")
    }

    @Test func basketballReadsTheSpreadAndTheTotal() throws {
        let line = try #require(try summary(from: summaryJSON("nba-summary")).line)
        #expect(line.text == "NY -18.5 · O/U 214.5")
    }

    /// Hockey's headline line is the moneyline, and it is rendered as
    /// ESPN leads with it rather than swapped for the puck line.
    @Test func hockeyKeepsESPNsHeadlineLine() throws {
        let line = try #require(try summary(from: summaryJSON("nhl-summary")).line)
        #expect(line.text == "ANA -185 · O/U 6.5")
    }

    @Test func noPickcenterMeansNoLine() throws {
        var json = try summaryJSON("summary-final-live")
        json["pickcenter"] = nil
        #expect(try summary(from: json).line == nil)
        json["pickcenter"] = [Any]()
        #expect(try summary(from: json).line == nil)
    }

    @Test func eitherHalfStandsAlone() throws {
        var json = try summaryJSON("summary-final-live")
        json["pickcenter"] = [["details": "IU -7.5"]]
        #expect(try summary(from: json).line?.text == "IU -7.5")
        json["pickcenter"] = [["overUnder": 47.0]]
        #expect(try summary(from: json).line?.text == "O/U 47")
        json["pickcenter"] = [["details": "  "]]
        #expect(try summary(from: json).line == nil)
    }

    @Test func spokenWithoutTheSlash() throws {
        let line = try #require(GameLine(details: "IU -7.5", overUnder: 47.5))
        #expect(line.accessibilityText == "IU -7.5, over under 47.5")
    }

    // MARK: - The row's gate: before kickoff only

    @Test func showsBeforeKickoff() throws {
        let summary = try summary(from: withState("pre", summaryJSON("summary-final-live")))
        let line = KickoffInfoRows.line(game: game(status: .pre(detail: nil)), summary: summary,
                                        showsLines: true)
        #expect(line?.text == "IU -7.5 · O/U 47.5")
    }

    /// Off by default, and off means nowhere.
    @Test func hiddenUnlessSwitchedOnInSettings() throws {
        let summary = try summary(from: withState("pre", summaryJSON("summary-final-live")))
        #expect(KickoffInfoRows.line(game: game(status: .pre(detail: nil)), summary: summary,
                                     showsLines: false) == nil)
    }

    /// ESPN keeps shipping `pickcenter` on a final; the card outlives the
    /// kickoff, the line doesn't.
    @Test func hidesOnceTheGameHasStarted() throws {
        let final = try summary(from: summaryJSON("summary-final-live"))
        #expect(KickoffInfoRows.line(game: game(status: .final(detail: "Final")), summary: final,
                                     showsLines: true) == nil)

        let live = try summary(from: withState("in", summaryJSON("summary-final-live")))
        #expect(KickoffInfoRows.line(game: game(status: .final(detail: "Final")), summary: live,
                                     showsLines: true) == nil)
    }
}

// The Scores row's line, off the scoreboard's `odds` (2026-09-24).
@Suite struct ScoreboardLineTests {
    private func scoreboard(_ name: String) throws -> Scoreboard {
        let url = try #require(
            Bundle(for: GameLineFixtureToken.self).url(forResource: name, withExtension: "json"))
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: Data(contentsOf: url))
        return ESPNMapper.scoreboard(from: dto)
    }

    @Test func readsTheLineAndWhoIsFavored() throws {
        let game = try #require(try scoreboard("scoreboard-live").games.first { $0.id == "401856766" })
        let line = try #require(game.line)
        #expect(line.text == "TCU -6.5 · O/U 49.5")
        #expect(line.favoriteIsHome == true)
    }

    @Test func aboutHalfTheCollegeSlateCarriesOne() throws {
        let games = try scoreboard("scoreboard-live").games
        #expect(games.filter { $0.line != nil }.count == 51)
    }

    @Test func theRowPrintsItPregameAndOnlyWhenSwitchedOn() throws {
        let game = try #require(try scoreboard("scoreboard-live").games.first { $0.id == "401856766" })
        #expect(GameRow.line(for: game, showsLines: true)?.details == "TCU -6.5")
        #expect(GameRow.line(for: game, showsLines: false) == nil)

        let final = Game(id: game.id, date: game.date, name: game.name, shortName: game.shortName,
                     weekNumber: game.weekNumber, status: .final(detail: "Final"),
                     home: game.home, away: game.away, broadcast: game.broadcast, line: game.line)
        #expect(GameRow.line(for: final, showsLines: true) == nil)
    }

    @Test func aPickEmFavorsNobody() {
        let odds = OddsDTO(details: "EVEN", overUnder: 44.5,
                           homeTeamOdds: TeamOddsDTO(favorite: false),
                           awayTeamOdds: TeamOddsDTO(favorite: false))
        #expect(ESPNMapper.line(from: odds)?.favoriteIsHome == nil)
    }
}
