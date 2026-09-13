import Foundation
import Testing
@testable import StatSide

// MARK: - Fixtures

private func team(_ id: String, _ location: String,
                  league: League = .collegeFootball) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: nil, displayName: location,
         shortDisplayName: location, logoURL: nil, conferenceId: nil, league: league)
}

private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    Calendar.current.date(from: DateComponents(year: year, month: month, day: day))!
}

/// One meeting. `homeScore`/`awayScore` nil leaves the result to the
/// `winner` flags, which is the older-payload shape the tally has to cope
/// with.
private func meeting(_ id: String, on when: Date?,
                     home: String, away: String,
                     homeScore: Int? = nil, awayScore: Int? = nil,
                     homeWon: Bool? = nil,
                     final: Bool = true, seasonType: Int = 2,
                     league: League = .collegeFootball) -> Game {
    Game(id: id, date: when, name: nil, shortName: nil, weekNumber: nil,
         seasonType: seasonType,
         status: final ? .final(detail: nil) : .pre(detail: nil),
         home: Competitor(team: team(home, "Team \(home)", league: league),
                          score: homeScore, record: nil, rank: nil, isHome: true,
                          winner: homeWon),
         away: Competitor(team: team(away, "Team \(away)", league: league),
                          score: awayScore, record: nil, rank: nil, isHome: false,
                          winner: homeWon.map { !$0 }),
         broadcast: nil)
}

/// The game the series is built for: Away (2) at Home (1), September 2026.
private func anchorGame(league: League = .collegeFootball,
                        on when: Date? = date(2026, 9, 5)) -> Game {
    meeting("anchor", on: when, home: "1", away: "2", final: false, league: league)
}

// MARK: - The series itself

@Suite struct HeadToHeadTests {
    /// Only games these two played against each other, and only the ones
    /// that were actually played.
    @Test func keepsOnlyCompletedMeetingsBetweenTheTwoTeams() {
        let games = [
            meeting("m1", on: date(2025, 9, 6), home: "1", away: "2", homeScore: 24, awayScore: 17),
            // Team 1 against somebody else entirely.
            meeting("other", on: date(2025, 9, 13), home: "1", away: "9", homeScore: 31, awayScore: 3),
            // A meeting that hasn't happened yet.
            meeting("future", on: date(2027, 9, 4), home: "2", away: "1", final: false),
            // And one that was postponed into nothing.
            Game(id: "off", date: date(2024, 10, 5), name: nil, shortName: nil,
                 weekNumber: nil, status: .other(detail: "Canceled"),
                 home: Competitor(team: team("1", "Team 1"), score: nil, record: nil,
                                  rank: nil, isHome: true, winner: nil),
                 away: Competitor(team: team("2", "Team 2"), score: nil, record: nil,
                                  rank: nil, isHome: false, winner: nil),
                 broadcast: nil),
        ]
        let series = HeadToHead.make(from: games, anchor: anchorGame(), earliestSeason: 2017)
        #expect(series.meetings.map(\.id) == ["m1"])
    }

    /// The game you're looking at is not part of its own history — even
    /// once it's final and turns up in the schedule it was fetched from.
    @Test func excludesTheAnchorGameItself() {
        let played = meeting("anchor", on: date(2026, 9, 5), home: "1", away: "2",
                             homeScore: 10, awayScore: 7)
        let series = HeadToHead.make(from: [played], anchor: anchorGame(),
                                     earliestSeason: 2017)
        #expect(series.isEmpty)
    }

    /// Open a 2019 game and the series is what it was in 2019. What these
    /// two have done since is not history that page can have known about.
    @Test func excludesMeetingsAfterTheAnchor() {
        let anchor = anchorGame(on: date(2019, 9, 7))
        let games = [
            meeting("before", on: date(2018, 9, 8), home: "1", away: "2",
                    homeScore: 21, awayScore: 14),
            meeting("after", on: date(2020, 9, 12), home: "1", away: "2",
                    homeScore: 35, awayScore: 7),
        ]
        let series = HeadToHead.make(from: games, anchor: anchor, earliestSeason: 2010)
        #expect(series.meetings.map(\.id) == ["before"])
    }

    /// The tally follows the team, not the fixture: a win on the road
    /// counts for the same side as a win at home.
    @Test func tallyFollowsTheTeamNotTheVenue() {
        let games = [
            // Away side (2) wins at home.
            meeting("a", on: date(2025, 9, 6), home: "2", away: "1", homeScore: 28, awayScore: 10),
            // Away side (2) wins on the road too.
            meeting("b", on: date(2024, 9, 7), home: "1", away: "2", homeScore: 3, awayScore: 30),
            // Home side (1) takes one back.
            meeting("c", on: date(2023, 9, 2), home: "1", away: "2", homeScore: 17, awayScore: 14),
        ]
        let series = HeadToHead.make(from: games, anchor: anchorGame(), earliestSeason: 2017)
        #expect(series.awayWins == 2)
        #expect(series.homeWins == 1)
        #expect(series.ties == 0)
        #expect(series.leader == .away)
    }

    /// Newest first — the last meeting is the one anybody asks about.
    @Test func meetingsRunNewestFirst() {
        let games = [
            meeting("old", on: date(2019, 9, 7), home: "1", away: "2", homeScore: 7, awayScore: 3),
            meeting("new", on: date(2025, 9, 6), home: "1", away: "2", homeScore: 24, awayScore: 17),
            meeting("mid", on: date(2022, 9, 3), home: "1", away: "2", homeScore: 14, awayScore: 10),
        ]
        let series = HeadToHead.make(from: games, anchor: anchorGame(), earliestSeason: 2017)
        #expect(series.meetings.map(\.id) == ["new", "mid", "old"])
    }

    /// A payload with no scores still has a result in it — the older
    /// schedules are where the `winner` flag earns its keep.
    @Test func fallsBackToTheWinnerFlagWhenScoresAreMissing() {
        let games = [
            meeting("a", on: date(2025, 9, 6), home: "1", away: "2", homeWon: true),
            meeting("b", on: date(2024, 9, 7), home: "2", away: "1", homeWon: true),
        ]
        let series = HeadToHead.make(from: games, anchor: anchorGame(), earliestSeason: 2017)
        #expect(series.homeWins == 1)
        #expect(series.awayWins == 1)
        #expect(series.leader == nil)
    }

    /// A drawn game is counted as drawn rather than quietly dropped —
    /// the one bug in a tally nobody would ever see.
    @Test func countsTies() {
        let games = [
            meeting("a", on: date(2025, 9, 6), home: "1", away: "2", homeScore: 21, awayScore: 21),
            meeting("b", on: date(2024, 9, 7), home: "1", away: "2", homeScore: 10, awayScore: 7),
        ]
        let series = HeadToHead.make(from: games, anchor: anchorGame(), earliestSeason: 2017)
        #expect(series.ties == 1)
        #expect(series.homeWins == 1)
        #expect(series.meetings.count == 2)
    }

    /// The caption that keeps the number honest. Football names a season by
    /// the year it opens; hockey and basketball by the pair.
    @Test func windowLabelNamesTheSeasonFloor() {
        let football = HeadToHead.make(from: [], anchor: anchorGame(), earliestSeason: 2017)
        #expect(football.windowLabel == "Since 2017")

        let hockey = HeadToHead.make(from: [], anchor: anchorGame(league: .nhl),
                                     earliestSeason: 2024)
        #expect(hockey.windowLabel == "Since 2024-25")
    }

    /// VoiceOver hears the series as a sentence, window and all.
    @Test func summarySentenceCarriesTheWindow() {
        let away = team("2", "Georgia"), home = team("1", "Tennessee")
        let games = [
            meeting("a", on: date(2025, 9, 6), home: "1", away: "2", homeScore: 10, awayScore: 24),
        ]
        let series = HeadToHead.make(from: games, anchor: anchorGame(), earliestSeason: 2017)
        #expect(series.summarySentence(away: away, home: home)
            == "Georgia leads 1-0 since 2017")

        let empty = HeadToHead.make(from: [], anchor: anchorGame(), earliestSeason: 2017)
        #expect(empty.summarySentence(away: away, home: home) == "No meetings since 2017")
    }

    /// The window is sized in meetings and expressed in seasons, so a
    /// league that plays four times a year needs far fewer of them.
    @Test func windowDepthFollowsHowOftenTwoTeamsMeet() {
        #expect(League.collegeFootball.headToHeadSeasons == 10)
        #expect(League.nfl.headToHeadSeasons == 6)
        #expect(League.nba.headToHeadSeasons == 3)
        #expect(League.nhl.headToHeadSeasons == 3)
    }
}

// MARK: - The walk

/// One team's seasons, keyed by the year asked for. A year that isn't in
/// the map throws, which is how a partial outage is modelled.
private struct SeriesStub: ScoresProviding {
    nonisolated var league: League { .collegeFootball }
    let seasons: [Int: [Game]]

    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        guard let year, let games = seasons[year] else { throw ESPNError.badStatus(404) }
        return TeamSchedule(team: nil, record: nil, standing: nil, year: year, games: games)
    }

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        Scoreboard(seasonYear: nil, seasonType: nil, currentWeekNumber: nil, weeks: [], games: [])
    }
    func scoreboard(days: ClosedRange<Date>,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        try await scoreboard(weekValue: nil, seasonType: nil, year: nil, divisions: divisions)
    }
    func rankings(year: Int?) async throws -> [Poll] { [] }
    func conferences(in division: Conference.Division) async throws -> [ConferenceTeams] { [] }
    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] { [] }
    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game] { [] }
    func gameSummary(eventId: String) async throws -> GameSummary { throw ESPNError.invalidURL }
}

@Suite struct HeadToHeadFetchTests {
    /// The anchor's own season leads the window and the depth sets its
    /// floor — ten seasons of college football lands on 2017 for a 2026
    /// game.
    @Test func walksTheAnchorSeasonAndNine() async throws {
        var seasons: [Int: [Game]] = [:]
        for year in 2017...2026 { seasons[year] = [] }
        seasons[2024] = [meeting("m", on: date(2024, 11, 30), home: "1", away: "2",
                                 homeScore: 20, awayScore: 13)]
        let series = try await SeriesStub(seasons: seasons).headToHead(for: anchorGame())
        #expect(series.earliestSeason == 2017)
        #expect(series.meetings.map(\.id) == ["m"])
        #expect(series.homeWins == 1)
    }

    /// An exhibition has never counted in a head-to-head record, and the
    /// fetch is where it stops counting in ours.
    @Test func exhibitionsDoNotCount() async throws {
        var seasons: [Int: [Game]] = [:]
        for year in 2017...2026 { seasons[year] = [] }
        seasons[2023] = [
            meeting("pre", on: date(2023, 8, 12), home: "1", away: "2",
                    homeScore: 17, awayScore: 10, seasonType: 1),
            meeting("real", on: date(2023, 10, 14), home: "1", away: "2",
                    homeScore: 7, awayScore: 28),
        ]
        let series = try await SeriesStub(seasons: seasons).headToHead(for: anchorGame())
        #expect(series.meetings.map(\.id) == ["real"])
        #expect(series.awayWins == 1)
        #expect(series.homeWins == 0)
    }

    /// A season that failed is dropped rather than failing the series.
    @Test func survivesSeasonsThatFailed() async throws {
        let seasons = [2024: [meeting("m", on: date(2024, 11, 30), home: "1", away: "2",
                                      homeScore: 20, awayScore: 13)]]
        let series = try await SeriesStub(seasons: seasons).headToHead(for: anchorGame())
        #expect(series.meetings.map(\.id) == ["m"])
    }

    /// But a series where every request failed throws, because "no
    /// meetings since 2017" and "we couldn't ask" look identical on screen
    /// and only one of them is true.
    @Test func throwsWhenNothingCouldBeFetched() async {
        await #expect(throws: (any Error).self) {
            try await SeriesStub(seasons: [:]).headToHead(for: anchorGame())
        }
    }
}

// MARK: - The row a series is listed with

@MainActor
@Suite struct HeadToHeadRowTests {
    private var meetingIn2024: Game {
        meeting("m", on: date(2024, 11, 30), home: "1", away: "2",
                homeScore: 20, awayScore: 13)
    }

    /// A slate row says "Sat, 11/30" because the screen around it already
    /// says which week that is. Nothing around an H2H row does.
    @Test func aSeasonSpanningRowSpeaksTheYear() {
        let row = GameRow(game: meetingIn2024, showsYear: true)
        #expect(row.accessibilitySummary.contains("2024"))
    }

    /// And every other row is left exactly as it was — the year is opt-in,
    /// so no existing surface's sentence moves.
    @Test func everyOtherRowIsUnchanged() {
        let row = GameRow(game: meetingIn2024)
        #expect(row.accessibilitySummary == "Team 2 13, Team 1 20, final")
    }
}
