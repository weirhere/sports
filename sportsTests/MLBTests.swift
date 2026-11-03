import Foundation
import Testing
@testable import StatSide

private final class MLBFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: MLBFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

/// The 2026 World Series' Game 5 (401908046, Brewers 4, Rays 1), the
/// fixture every baseball rule here is checked against. Captured
/// 2026-11-03.
private func worldSeriesGame5() throws -> GameSummary {
    let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("mlb-summary"))
    return ESPNMapper.gameSummary(from: dto, league: .mlb)
}

/// The feed up to and including the first play whose text starts so.
private func plays(through prefix: String, in summary: GameSummary) throws -> [Play] {
    let index = try #require(summary.plays.firstIndex { $0.text?.hasPrefix(prefix) == true },
                             "no play starting \(prefix)")
    return Array(summary.plays[...index])
}

@MainActor
@Suite struct MLBLeagueTests {
    @Test func identity() {
        #expect(League.mlb.rawValue == "mlb")
        #expect(League(rawValue: "mlb") == .mlb)
        #expect(League.mlb.sportSegment == "baseball")
        #expect(League.mlb.pathSegment == "mlb")
        #expect(League.mlb.shortName == "MLB")
        #expect(League.mlb.isBaseball)
        #expect(!League.mlb.isCollege)
        #expect(!League.mlb.hasPoll)
        #expect(!League.mlb.hasWeeks)
        #expect(League.mlb.playsOnASurface)
        #expect(!League.mlb.hasGameClock)
        #expect(League.mlb.fallbackGlyph == "baseball.fill")
        #expect(League.mlb.startNoun == "First pitch")
        #expect(League.mlb.scoringCardTitle == "Scoring")
        #expect(League.mlb.collegeFeeder == nil)
    }

    @Test func displayOrderStaysAlphabetical() {
        #expect(League.displayOrder.map(\.shortName)
            == ["MLB", "NBA", "NCAAF", "NCAAM", "NCAAW", "NFL", "NHL", "WNBA"])
    }

    /// February through November, inside one calendar year.
    @Test func theSeasonIsTheCalendarYear() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func date(_ y: Int, _ m: Int) -> Date { calendar.date(from: DateComponents(year: y, month: m, day: 15))! }
        #expect(!League.mlb.seasonSpansNewYear)
        #expect(League.mlb.espnSeason(for: 2026) == 2026)
        #expect(League.mlb.seasonLabel(2026) == "2026")
        let span = SeasonSpan.days(of: .mlb, year: 2026, calendar: calendar)
        #expect(calendar.dateComponents([.year, .month, .day], from: span.lowerBound)
            == DateComponents(year: 2026, month: 2, day: 1))
        #expect(calendar.dateComponents([.year, .month, .day], from: span.upperBound)
            == DateComponents(year: 2026, month: 11, day: 30))
        // The winter still shows the season just played; spring starts the next.
        #expect(SeasonYear.year(for: .mlb, now: date(2026, 12), calendar: calendar) == 2026)
        #expect(SeasonYear.year(for: .mlb, now: date(2027, 1), calendar: calendar) == 2026)
        #expect(SeasonYear.year(for: .mlb, now: date(2027, 3), calendar: calendar) == 2027)
        // And MLB doesn't move the app's own July–June season.
        #expect(SeasonSpan.year(containing: date(2026, 9), calendar: calendar) == 2026)
    }

    /// No clock: a live line is ESPN's own words, and extra innings are
    /// innings.
    @Test func theStatusLineReadsTheInning() {
        let live = GameStatus.live(displayClock: "0:00", period: 5, detail: "Top 5th",
                                   phase: .playing, possessionTeamId: nil)
        #expect(live.liveStatusText(in: .mlb) == "Top 5th")
        #expect(GameStatus.periodLabel(10, in: .mlb) == "10th")
        #expect(GameStatus.periodLabel(11, in: .mlb) == "11th")
        #expect(GameStatus.periodLabel(21, in: .mlb) == "21st")
        // Every other league reads as it did.
        let nba = GameStatus.live(displayClock: "5:24", period: 3, detail: nil,
                                  phase: .playing, possessionTeamId: nil)
        #expect(nba.liveStatusText(in: .nba) == "5:24 • 3rd")
        #expect(GameStatus.periodLabel(5, in: .nba) == "OT")
    }

    @Test func lateAndCloseAreBaseballs() {
        #expect(League.mlb.latePeriod == 7)
        #expect(League.mlb.secondHalfPeriod == 5)
        #expect(League.mlb.oneScore == 1)
    }

    /// Six games a week would crowd every other follow out of the
    /// nearest-24 reminder window, so a baseball team starts silent.
    @Test func baseballTeamsStartWithNoReminder() {
        #expect(TeamAlertStore.defaultAlerts(for: "mlb:10").isEmpty)
        #expect(TeamAlertStore.defaultAlerts(for: "cfb:130") == [.kickoffReminder])
        #expect(TeamAlertStore.defaultAlerts(for: "wnba:5") == [.kickoffReminder])
        #expect(!TeamAlert.breakInPlay.applies(to: .mlb))
        #expect(TeamAlert.scoring.applies(to: .mlb))
    }

    @Test func followingBaseballLeavesFootballsReminder() {
        let suite = "mlb-reminder-test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = TeamAlertStore(defaults: defaults)
        let followed: Set<String> = ["mlb:10", "mlb:19", "cfb:130"]
        #expect(store.keys(receiving: .kickoffReminder, among: followed) == ["cfb:130"])
        store.toggle(.kickoffReminder, for: "mlb:10")
        #expect(store.keys(receiving: .kickoffReminder, among: followed) == ["cfb:130", "mlb:10"])
    }
}

@MainActor
@Suite struct MLBConferenceTests {
    /// The loudest id collision in the app: 1 is the ACC, the NFC East,
    /// the WNBA's Eastern Conference and the AL East.
    @Test func idOneMeansFourThings() {
        #expect(Conference.name(for: 1, in: .collegeFootball) == "ACC")
        #expect(Conference.name(for: 1, in: .nfl) == "NFC East")
        #expect(Conference.name(for: 1, in: .wnba) == "Eastern")
        #expect(Conference.name(for: 1, in: .mlb) == "AL East")
    }

    @Test func divisionsNameThemselvesWithoutAQualifier() {
        #expect(Conference.name(for: 6, in: .mlb) == "NL West")
        #expect(Conference.name(for: 7, in: .mlb) == "American League")
        #expect(Conference.slateName(for: .mlb(7)) == "American League")
        #expect(Conference.parent(of: 1, in: .mlb) == 7)
        #expect(Conference.leagueWideId(in: .mlb) == 9)
        #expect(Conference.hasDivisions(in: .mlb))
    }

    @Test func everyTeamHasADivision() {
        for id in 1...30 {
            #expect(Conference.division(forTeamId: String(id), in: .mlb) != nil, "team \(id)")
        }
        // The Yankees, the AL East; the Dodgers, the NL West.
        #expect(Conference.division(forTeamId: "10", in: .mlb) == 1)
        #expect(Conference.division(forTeamId: "19", in: .mlb) == 6)
    }

    @Test func theStandingsTablePinsAndScrolls() {
        #expect(League.mlb.standingsScrollsHorizontally)
        #expect(League.mlb.standingsColumns.map(\.caption)
            == ["W", "L", "PCT", "GB", "HOME", "AWAY", "RS", "RA", "DIFF", "STRK", "L10"])
    }

    @Test func standingsMapOntoTheSixDivisions() throws {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("mlb-standings-level3"))
        let inSeason = Calendar.current.date(from: DateComponents(year: 2026, month: 9, day: 15)) ?? .now
        let divisions = ESPNMapper.divisionStandings(from: dto, league: .mlb, now: inSeason)
        #expect(Set(divisions.compactMap(\.id)) == [1, 2, 3, 4, 5, 6])
        #expect(divisions.allSatisfy { $0.entries.count == 5 })
        let row = try #require(divisions.first?.entries.first)
        #expect(row.lastTenGames != nil)
        #expect(row.pointsFor != nil)
    }
}

@MainActor
@Suite struct MLBGamePageTests {
    @Test func theSummaryDecodes() throws {
        let summary = try worldSeriesGame5()
        #expect(summary.status.isFinal)
        #expect(summary.drives.isEmpty)
        #expect(summary.plays.count > 500)
        #expect(summary.leaders.isEmpty)
        #expect(summary.periodFormat?.regulationPeriods == 9)
    }

    /// Runs per inning, then R H E: Brewers 4-8-2, Rays 1-4-0.
    @Test func theLineScoreEndsRHE() throws {
        let summary = try worldSeriesGame5()
        let home = try #require(summary.home)  // Tampa Bay
        let away = try #require(summary.away)  // Milwaukee
        #expect(away.linescores == ["0", "1", "0", "0", "1", "2", "0", "0", "0"])
        #expect(away.score == 4)
        #expect(away.hits == 8)
        #expect(away.errors == 2)
        #expect(home.hits == 4)
        #expect(home.errors == 0)
    }

    @Test func playsCarryTheirHalfAndState() throws {
        let summary = try worldSeriesGame5()
        let first = try #require(summary.plays.first)
        #expect(first.period == 1)
        #expect(first.half == .top)
        #expect(first.baseball?.atBatId != nil)
        #expect(summary.plays.contains { $0.half == .middle })
        let pitch = try #require(summary.plays.first { $0.baseball?.isPitch == true })
        #expect(pitch.baseball?.pitchVelocity != nil)
    }

    /// One row per at-bat result, under half-inning headings, newest first.
    @Test func thePlaysTabGroupsByHalfInning() throws {
        let summary = try worldSeriesGame5()
        let list = PeriodPlayList(summary: summary, league: .mlb, scoringOnly: false)
        let segments = list.segments
        #expect(segments.count == 18)
        #expect(segments.last?.segment == .init(period: 1, half: .top))
        #expect(segments.first?.segment == .init(period: 9, half: .bottom))
        #expect(segments.reduce(0) { $0 + $1.plays.count } == 84)
        #expect(segments.allSatisfy { $0.plays.allSatisfy { $0.baseball?.isResult == true } })
        #expect(PeriodLabel.halfInning(1, half: .top) == "TOP 1ST")
        #expect(PeriodLabel.short(10, in: .mlb) == "10")
    }

    /// Football's, basketball's and hockey's plays group exactly as before.
    @Test func otherLeaguesStillGroupByPeriod() throws {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("nba-summary"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .nba)
        let segments = PeriodPlayList(summary: summary, league: .nba, scoringOnly: false).segments
        #expect(segments.allSatisfy { $0.segment.half == nil })
        #expect(segments.reduce(0) { $0 + $1.plays.count } == summary.plays.count)
    }

    @Test func theBoxScoreHasBattingAndPitching() throws {
        let summary = try worldSeriesGame5()
        let labels = summary.boxScore.first?.categories.map(\.label) ?? []
        #expect(labels == ["Batting", "Pitching"])
    }

    @Test func teamStatsReadTheGroupedPayload() throws {
        let summary = try worldSeriesGame5()
        let ids = summary.teamStats.map(\.id)
        #expect(ids.contains("hits"))
        #expect(ids.contains("errors"))
        #expect(ids.contains("runnersLeftOnBase"))
    }

    @Test func theScoringCardListsTheRuns() throws {
        let summary = try worldSeriesGame5()
        #expect(summary.scoringPlays.count >= 4)
    }
}

@MainActor
@Suite struct BaseballDiamondTests {
    /// Turang's double: a runner on second, one out, the at-bat's 1-1.
    @Test func aDoublePutsARunnerOnSecond() throws {
        let summary = try worldSeriesGame5()
        let diamond = try #require(BaseballDiamond.current(plays: plays(through: "Turang doubled", in: summary)))
        #expect(diamond.inning == 2)
        #expect(diamond.half == .top)
        #expect(!diamond.onFirst && diamond.onSecond && !diamond.onThird)
        #expect(diamond.outs == 1)
        #expect(diamond.inningText == "Top 2nd")
        #expect(diamond.battingSide == .away)
    }

    /// The bases *after* the play: Pratt's single scored Turang, sent
    /// Frelick to third, and Pratt was out at second.
    @Test func runnersAreReadAfterThePlay() throws {
        let summary = try worldSeriesGame5()
        let diamond = try #require(BaseballDiamond.current(plays: plays(through: "Pratt singled", in: summary)))
        #expect(!diamond.onFirst && !diamond.onSecond && diamond.onThird)
        #expect(diamond.outs == 2)
    }

    /// Mid at-bat: the count is the pitch's, and the outs are the last
    /// finished at-bat's, not the strikeout this one ends in.
    @Test func anAtBatInProgressKeepsTheStandingOuts() throws {
        let summary = try worldSeriesGame5()
        let diamond = try #require(BaseballDiamond.current(
            plays: plays(through: "Pitch 4 : Strike 2 Looking", in: summary)))
        #expect(diamond.balls == 2)
        #expect(diamond.strikes == 2)
        #expect(diamond.outs == 2)
        #expect(diamond.onThird)
        #expect(diamond.batterId != nil)
        #expect(diamond.pitcherId != nil)
        #expect(diamond.lastPitch?.contains("mph") == true)
    }

    @Test func theThirdOutEndsTheHalf() throws {
        let summary = try worldSeriesGame5()
        let out = try #require(BaseballDiamond.current(plays: plays(through: "Mitchell struck out", in: summary)))
        #expect(out.outs == 3)
        let middle = try #require(BaseballDiamond.current(plays: plays(through: "Middle of the 2nd", in: summary)))
        #expect(middle.isBreak)
        #expect(!middle.onFirst && !middle.onSecond && !middle.onThird)
        #expect(middle.balls == nil)
        #expect(middle.batterId == nil)
        #expect(middle.inningText == "Mid 2nd")
    }

    @Test func theCardNamesTheMatchup() throws {
        let summary = try worldSeriesGame5()
        let diamond = try #require(BaseballDiamond.current(
            plays: plays(through: "Pitch 4 : Strike 2 Looking", in: summary)))
        let content = GamecastContent.baseball(diamond: diamond, summary: summary,
                                               names: summary.athleteNames)
        #expect(content.slots.map(\.label) == ["Count", "Outs", "Pitch"])
        #expect(content.slots[0].value == "2-2")
        #expect(content.slots[1].value == "2")
        #expect(content.lastPlayLabel.contains(" vs "))
        #expect(content.lastPlayClock == "Top 2nd")
        #expect(content.accessibilitySummary.contains("runners on third"))
    }

    @Test func otherLeaguesHaveNoDiamond() throws {
        let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture("nba-summary"))
        let summary = ESPNMapper.gameSummary(from: dto, league: .nba)
        #expect(BaseballDiamond.current(plays: summary.plays) == nil)
    }
}

@MainActor
@Suite struct MLBTrophyTests {
    @Test func theWorldSeriesAndThePennants() {
        #expect(TrophyKind.from(headline: "World Series - Game 5", league: .mlb)?.singular == "World Series")
        #expect(TrophyKind.from(headline: "World Series - Game 5", league: .mlb)?.tier == .league)
        #expect(TrophyKind.from(headline: "ALCS - Game 6", league: .mlb)?.singular == "AL Pennant")
        #expect(TrophyKind.from(headline: "NLCS - Game 3", league: .mlb)?.singular == "NL Pennant")
        #expect(TrophyKind.from(headline: "ALDS - Game 1", league: .mlb) == nil)
        #expect(TrophyKind.from(headline: "NLWC - Game 2", league: .mlb) == nil)
    }

    /// Series, like the NBA's: no round named, so no bracket tab.
    @Test func seriesNameNoBracketRounds() {
        let team = { (id: String) in
            Team(id: id, location: id, name: nil, abbreviation: nil, displayName: id,
                 shortDisplayName: id, logoURL: nil, conferenceId: nil)
        }
        let game = Game(id: "ws5", date: nil, name: nil, shortName: nil, weekNumber: nil,
                        seasonType: Postseason.seasonType, headline: "World Series - Game 5",
                        status: .final(detail: nil),
                        home: Competitor(team: team("30"), score: 1, record: nil, rank: nil,
                                         isHome: true, winner: false),
                        away: Competitor(team: team("8"), score: 4, record: nil, rank: nil,
                                         isHome: false, winner: true),
                        broadcast: nil)
        #expect(Postseason.rounds(from: [game], league: .mlb).isEmpty)
    }
}
