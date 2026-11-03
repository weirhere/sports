import Foundation
import Testing
@testable import StatSide

/// The series bracket (2026-11-03): MLB, the NBA, the NHL and the WNBA
/// play best-of series, so each round draws one card per series — its
/// scores the series wins, its winner the series winner — and the
/// single-game bracket's results-only wiring does the rest.
@Suite struct SeriesBracketTests {
    private func team(_ id: String, league: League) -> Team {
        Team(id: id, location: id, name: nil, abbreviation: id, displayName: id,
             shortDisplayName: id, logoURL: nil, conferenceId: nil, league: league)
    }

    private func day(_ day: Int) -> Date {
        var components = DateComponents(year: 2026, month: 10, day: day, hour: 19)
        components.timeZone = TimeZone(identifier: "America/New_York")
        return Calendar(identifier: .gregorian).date(from: components)!
    }

    /// One game of a series, with ESPN's record as it stood after it.
    private func game(_ id: String, _ headline: String, home: String, away: String, day: Int,
                      winner: String? = nil, live: Bool = false, wins: [String: Int],
                      length: Int = 3, completed: Bool = false, summary: String? = nil,
                      league: League = .mlb) -> Game {
        let status: GameStatus = live
            ? .live(displayClock: nil, period: 5, detail: "Top 5th", phase: .playing, possessionTeamId: nil)
            : winner == nil ? .pre(detail: nil) : .final(detail: "Final")
        return Game(id: id, date: self.day(day), name: nil, shortName: nil, weekNumber: nil,
                    seasonType: Postseason.seasonType, headline: headline,
                    series: PlayoffSeries(length: length, summary: summary, completed: completed, wins: wins),
                    status: status,
                    home: Competitor(team: team(home, league: league), score: winner == nil ? nil : 3,
                                     record: nil, rank: nil, isHome: true,
                                     winner: winner.map { $0 == home }),
                    away: Competitor(team: team(away, league: league), score: winner == nil ? nil : 2,
                                     record: nil, rank: nil, isHome: false,
                                     winner: winner.map { $0 == away }),
                    broadcast: nil)
    }

    @Test func roundsAreNamedOffEachLeaguesHeadlines() {
        let cases: [(League, String, String)] = [
            (.mlb, "NLWC - Game 1", "Wild Card"), (.mlb, "ALWC - Game 2", "Wild Card"),
            (.mlb, "ALDS - Game 3", "Division Series"), (.mlb, "NLCS - Game 4", "Championship Series"),
            (.mlb, "World Series - Game 5", "World Series"),
            (.nba, "East 1st Round - Game 2", "First Round"),
            (.nba, "West Semifinals - Game 1", "Conference Semifinals"),
            (.nba, "West Finals - Game 2", "Conference Finals"), (.nba, "NBA Finals - Game 2", "NBA Finals"),
            (.nhl, "East 1st Round - Game 2", "First Round"), (.nhl, "West 2nd Round - Game 2", "Second Round"),
            (.nhl, "West Final - Game 1", "Conference Finals"),
            (.nhl, "Stanley Cup Final - Game 3", "Stanley Cup Final"),
            (.wnba, "First Round - Game 2", "First Round"), (.wnba, "WNBA Semifinals - Game 3", "Semifinals"),
            (.wnba, "WNBA Finals - Game 7", "Finals"),
        ]
        for (league, headline, round) in cases {
            #expect(Postseason.seriesName(headline: headline, league: league) == round, "\(headline)")
        }
        // A round nobody has seen yet still shows; no headline is no round.
        #expect(Postseason.seriesName(headline: "Something New - Game 1", league: .nba) == "Playoffs")
        #expect(Postseason.seriesName(headline: nil, league: .nba) == nil)
    }

    /// Three games of a best-of-three are one card: 2-1, Atlanta through,
    /// opening the game that decided it.
    @Test func aSeriesIsOneCard() {
        let games = [
            game("1", "NLWC - Game 1", home: "ATL", away: "SD", day: 1, winner: "ATL", wins: ["ATL": 1, "SD": 0]),
            game("2", "NLWC - Game 2", home: "ATL", away: "SD", day: 2, winner: "SD", wins: ["ATL": 1, "SD": 1]),
            game("3", "NLWC - Game 3", home: "ATL", away: "SD", day: 3, winner: "ATL",
                 wins: ["ATL": 2, "SD": 1], completed: true, summary: "ATL wins series 2-1"),
        ]
        let rounds = Postseason.rounds(from: games, league: .mlb)
        #expect(rounds.map(\.name) == ["Wild Card"])
        let card = rounds[0].games[0]
        #expect(rounds[0].games.count == 1)
        #expect(card.home.score == 2 && card.away.score == 1)
        #expect(card.winnerTeamId == "ATL")
        #expect(card.status.isFinal)
        #expect(rounds[0].opens[card.id]?.id == "3")
    }

    /// Mid-series and on the air: the card is live and opens the live game.
    @Test func aSeriesBeingPlayedOpensTheLiveGame() {
        let games = [
            game("1", "ALDS - Game 1", home: "NYY", away: "CHW", day: 4, winner: "NYY",
                 wins: ["NYY": 1, "CHW": 0], length: 5),
            game("2", "ALDS - Game 2", home: "NYY", away: "CHW", day: 5, live: true,
                 wins: ["NYY": 1, "CHW": 0], length: 5),
            game("3", "ALDS - Game 3", home: "CHW", away: "NYY", day: 7, wins: ["NYY": 0, "CHW": 0], length: 5),
        ]
        let round = Postseason.rounds(from: games, league: .mlb)[0]
        let card = round.games[0]
        #expect(card.isLive)
        #expect(card.winnerTeamId == nil)
        #expect(card.home.score == 1 && card.away.score == 0)
        #expect(round.opens[card.id]?.id == "2")
    }

    /// A series nobody has played yet has no score and opens Game 1.
    @Test func anUnplayedSeriesOpensGameOne() {
        let games = [
            game("9", "World Series - Game 1", home: "MIL", away: "TOR", day: 24,
                 wins: ["MIL": 0, "TOR": 0], length: 7),
            game("10", "World Series - Game 2", home: "MIL", away: "TOR", day: 25,
                 wins: ["MIL": 0, "TOR": 0], length: 7),
        ]
        let round = Postseason.rounds(from: games, league: .mlb)[0]
        let card = round.games[0]
        #expect(card.home.score == nil && card.away.score == nil)
        #expect(round.opens[card.id]?.id == "9")
    }

    /// The bracket wires series the way it wires games: the Wild Card
    /// winner turns up in the Division Series, and the seed that sat the
    /// Wild Card out is its bye.
    @Test func seriesWinnersFeedTheNextRound() {
        let games = [
            game("1", "NLWC - Game 1", home: "ATL", away: "SD", day: 1, winner: "ATL",
                 wins: ["ATL": 1, "SD": 0]),
            game("2", "NLWC - Game 2", home: "ATL", away: "SD", day: 2, winner: "ATL",
                 wins: ["ATL": 2, "SD": 0], completed: true, summary: "ATL wins series 2-0"),
            game("3", "NLDS - Game 1", home: "LAD", away: "ATL", day: 4, wins: ["LAD": 0, "ATL": 0], length: 5),
        ]
        let rounds = Postseason.rounds(from: games, league: .mlb)
        #expect(rounds.map(\.name) == ["Wild Card", "Division Series"])
        let pairing = Postseason.pairing(round: rounds[0].games, next: rounds[1].games)
        #expect(pairing != nil)
        #expect(pairing?.sources.count == 2)
        if case .bye(let team) = pairing?.sources.first { #expect(team.id == "LAD") } else {
            Issue.record("expected LAD's bye first")
        }
    }

    /// Only a playoff series is decoded, and only with team ids to key on.
    @Test func onlyAPlayoffSeriesDecodes() throws {
        let json = #"""
        {"type": "playoff", "summary": "MIL wins series 4-1", "completed": true, "totalCompetitions": 7,
         "competitors": [{"id": "30", "wins": 1}, {"id": "8", "wins": 4}]}
        """#
        let dto = try JSONDecoder().decode(SeriesDTO.self, from: Data(json.utf8))
        let series = ESPNMapper.series(from: dto)
        #expect(series?.wins == ["30": 1, "8": 4])
        #expect(series?.completed == true && series?.length == 7)
        #expect(series?.summary == "MIL wins series 4-1")

        let season = try JSONDecoder().decode(SeriesDTO.self, from: Data(#"{"type": "season", "competitors": [{"id": "1", "wins": 2}]}"#.utf8))
        #expect(ESPNMapper.series(from: season) == nil)
    }

    /// The college and NFL brackets are untouched: single games stay cards.
    @Test func singleGameLeaguesKeepTheirGames() {
        #expect(!League.nfl.playsSeries && !League.mensCollegeBasketball.playsSeries)
        #expect(League.mlb.playsSeries && League.nba.playsSeries && League.nhl.playsSeries
                && League.wnba.playsSeries)
    }
}

@Suite struct SeriesSettlingTests {
    /// The NHL's 2026 first round, as the slate served it: Minnesota–Dallas
    /// with no Game 6, stuck at 3-2, and Minnesota playing in round two.
    /// The card settles to Minnesota 4-2 rather than reading undecided.
    @Test func aSeriesWhoseWinnerPlaysOnIsSettled() {
        func team(_ id: String) -> Team {
            Team(id: id, location: id, name: nil, abbreviation: id, displayName: id,
                 shortDisplayName: id, logoURL: nil, conferenceId: nil, league: .nhl)
        }
        func card(_ id: String, _ a: String, _ b: String, wins: [String: Int], winner: String? = nil) -> Game {
            Game(id: id, date: nil, name: nil, shortName: nil, weekNumber: nil,
                 seasonType: Postseason.seasonType, headline: nil,
                 series: PlayoffSeries(length: 7, summary: nil, completed: winner != nil, wins: wins),
                 status: winner == nil ? .pre(detail: nil) : .final(detail: nil),
                 home: Competitor(team: team(a), score: wins[a], record: nil, rank: nil, isHome: true,
                                  winner: winner.map { $0 == a }),
                 away: Competitor(team: team(b), score: wins[b], record: nil, rank: nil, isHome: false,
                                  winner: winner.map { $0 == b }),
                 broadcast: nil)
        }
        let rounds = [
            PostseasonRound(name: "First Round", games: [card("s1", "DAL", "MIN", wins: ["DAL": 2, "MIN": 3])]),
            PostseasonRound(name: "Second Round", games: [card("s2", "COL", "MIN", wins: ["COL": 4, "MIN": 1],
                                                               winner: "COL")]),
        ]
        let settled = Postseason.settled(rounds)[0].games[0]
        #expect(settled.winnerTeamId == "MIN")
        #expect(settled.away.score == 4 && settled.home.score == 2)
        #expect(settled.series?.summary == "MIN wins series 4-2")
        #expect(settled.status.isFinal)
        // The last round has nobody playing on, so it is left alone.
        #expect(Postseason.settled(rounds)[1].games[0].winnerTeamId == "COL")
    }
}
