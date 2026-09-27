import Foundation
import Testing
@testable import StatSide

private final class GamecastFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: GamecastFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private func loadSummary(_ name: String, league: League) throws -> GameSummary {
    let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture(name))
    return ESPNMapper.gameSummary(from: dto, league: league)
}

private func team(_ id: String, _ location: String, _ abbreviation: String) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: abbreviation,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil)
}

private let van = team("22", "Vancouver", "VAN")
private let col = team("17", "Colorado", "COL")
private let phi = team("20", "Philadelphia", "PHI")
private let wsh = team("27", "Washington", "WSH")

private func play(_ id: String, type: String? = nil, team: Team? = nil, period: Int = 1,
                  clock: String? = "10:00", away: Int = 0, home: Int = 0,
                  scoring: Bool = false, strength: String? = nil,
                  at spot: (Double, Double)? = nil, shooting: Bool = false) -> Play {
    Play(id: id, text: "\(id) text", downDistanceText: nil, nextDownDistanceText: nil,
         possessionText: nil, yardsToEndzone: nil, clock: clock, period: period,
         typeText: type, isScoringPlay: scoring, awayScore: away, homeScore: home,
         teamId: team?.id,
         coordinate: spot.map { PlayCoordinate(x: $0.0, y: $0.1) },
         isShootingPlay: shooting, strength: strength)
}

private func summary(away: Team, home: Team, plays: [Play]) -> GameSummary {
    GameSummary(
        home: GameSummary.Side(team: home, score: nil, record: nil, rank: nil,
                               winner: nil, linescores: []),
        away: GameSummary.Side(team: away, score: nil, record: nil, rank: nil,
                               winner: nil, linescores: []),
        status: .live(displayClock: "10:00", period: 1, detail: nil,
                      phase: .playing, possessionTeamId: nil),
        scoringPlays: [], drives: [], teamStats: [], leaders: [],
        plays: plays, venue: nil, attendance: nil)
}

/// The shot map against real ESPN feeds (the NBA and NHL fixtures, both
/// finals): every mark on the surface, each team at its own end.
@Suite struct ShotMapFixtureTests {
    @Test func noLocationSentinelIsDropped() {
        #expect(ESPNMapper.coordinate(PlayCoordinateDTO(x: -214748340, y: -214748365)) == nil)
        #expect(ESPNMapper.coordinate(PlayCoordinateDTO(x: 27, y: 1))
                == PlayCoordinate(x: 27, y: 1))
        #expect(ESPNMapper.coordinate(nil) == nil)
    }

    @Test func basketballMarksStayOnTheCourt() throws {
        let game = try loadSummary("nba-summary", league: .nba)
        let map = try #require(ShotMap.current(plays: game.plays, league: .nba,
                                               awayId: game.away?.team.id, allowsShootout: false))
        #expect(map.surface == .court)
        #expect(map.marks.count > 20)
        for mark in map.marks {
            #expect((0...94).contains(mark.x) && (0...50).contains(mark.y))
        }
        // Free throws carry no spot, so none of them is drawn.
        let freeThrows = Set(game.plays.filter { $0.typeText?.contains("Free Throw") == true }.map(\.id))
        #expect(!map.marks.contains { freeThrows.contains($0.id) })
    }

    /// ESPN folds both teams onto one half; each is unfolded to the basket
    /// it attacks, home left and away right (D6).
    @Test func basketballUnfoldsEachTeamToItsBasket() throws {
        let game = try loadSummary("nba-summary", league: .nba)
        let awayId = game.away?.team.id
        for period in 1...4 {
            let plays = game.plays.filter { ($0.period ?? 0) <= period }
            let map = try #require(ShotMap.current(plays: plays, league: .nba, awayId: awayId,
                                                   allowsShootout: false))
            let dunks = Set(plays.filter { $0.typeText?.contains("Dunk") == true }.map(\.id))
            for mark in map.marks where dunks.contains(mark.id) {
                #expect(mark.side == .home ? mark.x < 12 : mark.x > 82)
            }
        }
    }

    /// Hockey teams change ends every period; the map turns the rink so
    /// the away team always shoots right, and its goals land right of
    /// center in every period.
    @Test func hockeyAwayShootsRightEveryPeriod() throws {
        let game = try loadSummary("nhl-summary", league: .nhl)
        let awayId = game.away?.team.id
        for period in 1...3 {
            let plays = game.plays.filter { ($0.period ?? 0) <= period }
            let map = try #require(ShotMap.current(plays: plays, league: .nhl, awayId: awayId,
                                                   allowsShootout: true))
            #expect(map.period == period)
            let away = map.marks.filter { $0.side == .away && $0.outcome != .blocked }
            let home = map.marks.filter { $0.side == .home && $0.outcome != .blocked }
            let awayMean = away.map(\.x).reduce(0, +) / Double(max(away.count, 1))
            let homeMean = home.map(\.x).reduce(0, +) / Double(max(home.count, 1))
            #expect(awayMean > 100, "period \(period)")
            #expect(homeMean < 100, "period \(period)")
            for mark in map.marks {
                #expect((0...200).contains(mark.x) && (0...85).contains(mark.y))
            }
        }
    }

    @Test func aShootoutDrawsNothing() throws {
        let game = try loadSummary("nhl-summary", league: .nhl)
        #expect(game.plays.last?.period == 5)
        #expect(ShotMap.current(plays: game.plays, league: .nhl, awayId: game.away?.team.id,
                                allowsShootout: true) == nil)
    }

    @Test func footballHasNoShotMap() {
        #expect(ShotMap.current(plays: [play("a", period: 1)], league: .nfl,
                                awayId: nil, allowsShootout: false) == nil)
    }
}

/// The header columns and last play each league builds.
@Suite struct GamecastContentTests {
    @Test func hockeyClockCountsDown() {
        #expect(GamecastContent.remainingClock(elapsed: "0:29", period: 1, allowsShootout: true) == "19:31")
        #expect(GamecastContent.remainingClock(elapsed: "16:05", period: 3, allowsShootout: true) == "3:55")
        // Regular-season overtime is five minutes; a playoff one is twenty.
        #expect(GamecastContent.remainingClock(elapsed: "3:10", period: 4, allowsShootout: true) == "1:50")
        #expect(GamecastContent.remainingClock(elapsed: "3:10", period: 4, allowsShootout: false) == "16:50")
        #expect(GamecastContent.remainingClock(elapsed: nil, period: 1, allowsShootout: true) == nil)
    }

    @Test func basketballRunLeadAndChanges() throws {
        let plays = [
            play("1", team: phi, away: 2, home: 0, scoring: true),
            play("2", team: wsh, away: 2, home: 3, scoring: true),
            play("3", team: phi, away: 4, home: 3, scoring: true),
            play("4", team: phi, away: 7, home: 3, scoring: true),
            play("5", type: "Defensive Rebound", team: wsh, away: 7, home: 3),
        ]
        let content = try #require(GamecastContent.shotMap(
            summary: summary(away: phi, home: wsh, plays: plays), league: .nba, allowsShootout: false))
        #expect(content.slots.map(\.label) == ["Run", "Lead", "Lead changes"])
        #expect(content.slots.map(\.value) == ["PHI 5–0", "PHI +4", "2"])
        #expect(content.result == nil)
        #expect(content.lastPlayLabel == "Last play")
        #expect(content.accessibilitySummary
                == "Philadelphia on a 5–0 run, Philadelphia up 4, 2 lead changes, 5 text")
    }

    @Test func basketballBeforeAnyScore() throws {
        let content = try #require(GamecastContent.shotMap(
            summary: summary(away: phi, home: wsh, plays: [play("tip", type: "Jumpball")]),
            league: .nba, allowsShootout: false))
        #expect(content.slots.map(\.value) == [nil, "Tied", "0"])
    }

    /// A goal holds the header until the next faceoff, like a touchdown
    /// until the next snap (D4).
    @Test func hockeyGoalHoldsUntilTheFaceoff() throws {
        let goal = play("g", type: "Goal", team: col, clock: "16:05", away: 3, home: 3,
                        scoring: true, strength: "even-strength", at: (-68, -13))
        let before = [play("s", type: "Shot", team: van, clock: "15:00", away: 3, home: 2,
                           strength: "even-strength", at: (70, 10)), goal]
        let standing = try #require(GamecastContent.shotMap(
            summary: summary(away: van, home: col, plays: before), league: .nhl, allowsShootout: true))
        #expect(standing.result == "Goal")
        #expect(standing.resultTeam == col)
        #expect(standing.lastPlayClock == "3:55")

        let restarted = before + [play("f", type: "Face Off", team: col, clock: "16:05",
                                       away: 3, home: 3, strength: "even-strength")]
        let after = try #require(GamecastContent.shotMap(
            summary: summary(away: van, home: col, plays: restarted), league: .nhl, allowsShootout: true))
        #expect(after.result == nil)
        #expect(after.slots.map(\.value) == ["Even", "1–1", "COL 3:55"])
    }

    @Test func hockeyStrengthNamesThePowerPlay() throws {
        let pp = [play("a", type: "Shot", team: van, strength: "power-play", at: (80, 0))]
        let onPP = try #require(GamecastContent.shotMap(
            summary: summary(away: van, home: col, plays: pp), league: .nhl, allowsShootout: true))
        #expect(onPP.slots.first?.value == "VAN PP")
        #expect(onPP.lastPlayLabel == "Last play · Power play")

        // The short-handed side's play: the other side has the power play.
        let sh = [play("b", type: "Hit", team: van, strength: "short-handed")]
        let short = try #require(GamecastContent.shotMap(
            summary: summary(away: van, home: col, plays: sh), league: .nhl, allowsShootout: true))
        #expect(short.slots.first?.value == "COL PP")
    }

    /// A goal from an earlier period names the period, not a clock that
    /// would read as this one's.
    @Test func hockeyLastGoalFromAnEarlierPeriod() throws {
        let plays = [play("g", type: "Goal", team: van, period: 1, clock: "5:00", away: 1,
                          scoring: true, at: (80, 0)),
                     play("f", type: "Face Off", team: col, period: 2, clock: "0:00", away: 1)]
        let content = try #require(GamecastContent.shotMap(
            summary: summary(away: van, home: col, plays: plays), league: .nhl, allowsShootout: true))
        #expect(content.slots.last?.value == "VAN 1st")
    }

    @Test func realFeedsFillEverySlot() throws {
        for (name, league) in [("nba-summary", League.nba), ("nhl-summary", .nhl)] {
            let game = try loadSummary(name, league: league)
            let content = try #require(GamecastContent.shotMap(summary: game, league: league,
                                                               allowsShootout: league == .nhl))
            #expect(content.slots.count == 3, "\(name)")
            #expect(content.lastPlayText != nil, "\(name)")
        }
    }
}
