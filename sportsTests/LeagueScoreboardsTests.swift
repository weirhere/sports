import Foundation
import Testing
@testable import StatSide

/// ESPN's `dates=` request, per league: a fixed pool filtered to the days
/// asked for.
private struct LeagueStub: ScoresProviding {
    nonisolated let league: League
    let games: [Game]

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        throw ESPNError.invalidURL
    }

    func scoreboard(days: ClosedRange<Date>,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        let calendar = Calendar.current
        let lower = calendar.startOfDay(for: days.lowerBound)
        let upper = calendar.date(byAdding: .day, value: 1,
                                  to: calendar.startOfDay(for: days.upperBound)) ?? days.upperBound
        return Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 1, weeks: [],
                          games: games.filter { game in
                              guard let date = game.date else { return false }
                              return date >= lower && date < upper
                          })
    }

    func rankings(year: Int?) async throws -> [Poll] { [] }
    func conferences(in division: Conference.Division) async throws -> [ConferenceTeams] { [] }
    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] { [] }
    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game] { [] }
    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        TeamSchedule(team: nil, record: nil, standing: nil, year: year, games: [])
    }
    func gameSummary(eventId: String) async throws -> GameSummary { throw ESPNError.invalidURL }
}

private func team(_ id: String, in league: League, conference: Int? = nil) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil,
         conferenceId: conference, league: league)
}

/// Today at a fixed hour, so every game lands in today's local bucket
/// wherever the test machine is.
private func today(hour: Int = 12) -> Date {
    let calendar = Calendar.current
    return calendar.date(byAdding: .hour, value: hour,
                         to: calendar.startOfDay(for: .now)) ?? .now
}

private func game(_ id: String, home: Team, away: Team, live: Bool = false,
                  homeRank: Int? = nil, awayRank: Int? = nil,
                  at date: Date? = nil) -> Game {
    Game(id: id, date: date ?? today(), name: nil, shortName: nil, weekNumber: 1,
         status: live ? .live(displayClock: "5:00", period: 2, detail: nil,
                              phase: .playing, possessionTeamId: nil)
                      : .pre(detail: nil),
         home: Competitor(team: home, score: live ? 7 : nil, record: nil, rank: homeRank,
                          isHome: true, winner: nil),
         away: Competitor(team: away, score: live ? 3 : nil, record: nil, rank: awayRank,
                          isHome: false, winner: nil),
         broadcast: nil)
}

@MainActor
private func makeScoreboards(cfb: [Game] = [], nfl: [Game] = []) async -> LeagueScoreboards {
    let stores: [League: ScoreboardStore] = [
        .collegeFootball: ScoreboardStore(
            league: .collegeFootball,
            client: LeagueStub(league: .collegeFootball, games: cfb)),
        .nfl: ScoreboardStore(league: .nfl, client: LeagueStub(league: .nfl, games: nfl)),
    ]
    let scoreboards = LeagueScoreboards(stores: stores)
    await scoreboards.loadInitial()
    return scoreboards
}

@MainActor
private func makeFollowing(_ teams: [Team] = [],
                           conferences: [ConferenceID] = []) -> FollowingStore {
    let name = "test.leaguescoreboards.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name) ?? .standard
    defaults.removePersistentDomain(forName: name)
    let store = FollowingStore(defaults: defaults)
    for team in teams { store.toggle(team) }
    for conference in conferences { store.toggleConference(conference) }
    return store
}

@MainActor
@Suite struct LeagueScoreboardsTests {

    // MARK: - Both leagues on one day

    @Test func bothLeaguesLoadTheSameDay() async {
        let cfb = game("c1", home: team("1", in: .collegeFootball),
                       away: team("2", in: .collegeFootball))
        let nfl = game("n1", home: team("26", in: .nfl), away: team("27", in: .nfl))
        let scoreboards = await makeScoreboards(cfb: [cfb], nfl: [nfl])

        #expect(scoreboards.store(for: .collegeFootball).games(on: today()).map(\.id) == ["c1"])
        #expect(scoreboards.store(for: .nfl).games(on: today()).map(\.id) == ["n1"])
        #expect(Set(scoreboards.selectedDayGames.map(\.id)) == ["c1", "n1"])
    }

    @Test func eachLeagueGetsItsOwnAccordion() async {
        let cfb = game("c1", home: team("1", in: .collegeFootball),
                       away: team("2", in: .collegeFootball))
        let nfl = game("n1", home: team("26", in: .nfl), away: team("27", in: .nfl))
        let scoreboards = await makeScoreboards(cfb: [cfb], nfl: [nfl])

        let sections = scoreboards.sections(followingIds: [])
        #expect(sections.map(\.id) == [GameSection.id(for: .collegeFootball),
                                       GameSection.id(for: .nfl)])
        #expect(sections.map(\.title) == ["College Football", "NFL"])
        #expect(sections.allSatisfy { $0.league != nil })
    }

    @Test func aLeagueWithNoGamesGetsNoSection() async {
        let cfb = game("c1", home: team("1", in: .collegeFootball),
                       away: team("2", in: .collegeFootball))
        let scoreboards = await makeScoreboards(cfb: [cfb], nfl: [])

        #expect(scoreboards.sections(followingIds: []).map(\.id)
                == [GameSection.id(for: .collegeFootball)])
    }

    // MARK: - Following

    @Test func followingLeadsAndTheGameStaysInItsLeagueToo() async {
        // Sections are complete, never deduplicated: a followed game is in
        // Following *and* in its league's list.
        let home = team("1", in: .collegeFootball)
        let cfb = game("c1", home: home, away: team("2", in: .collegeFootball))
        let scoreboards = await makeScoreboards(cfb: [cfb])
        let following = makeFollowing([home])

        let sections = scoreboards.sections(followingIds: following.teamKeys)
        #expect(sections.first?.id == GameSection.followingId)
        #expect(sections.first?.games.map(\.id) == ["c1"])
        #expect(sections.last?.games.map(\.id) == ["c1"])
    }

    @Test func followingIsCrossLeague() async {
        let cfbTeam = team("1", in: .collegeFootball)
        let nflTeam = team("26", in: .nfl)
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: cfbTeam, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: nflTeam, away: team("27", in: .nfl))])
        let following = makeFollowing([cfbTeam, nflTeam])

        let section = try! #require(scoreboards.sections(followingIds: following.teamKeys).first)
        #expect(section.id == GameSection.followingId)
        #expect(Set(section.games.map(\.id)) == ["c1", "n1"])
        // Rows tag their league when the section spans more than one —
        // the screen's own scope no longer answers for them.
        #expect(section.spansLeagues)
    }

    @Test func aSingleLeagueFollowingDoesNotTagItsRows() async {
        let cfbTeam = team("1", in: .collegeFootball)
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: cfbTeam, away: team("2", in: .collegeFootball))])
        let following = makeFollowing([cfbTeam])

        #expect(scoreboards.sections(followingIds: following.teamKeys).first?.spansLeagues == false)
    }

    @Test func followingHiddenWhenFollowingNobody() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: team("1", in: .collegeFootball),
                       away: team("2", in: .collegeFootball))])
        #expect(scoreboards.sections(followingIds: []).first?.id
                == GameSection.id(for: .collegeFootball))
    }

    @Test func aFollowedConferencePutsItsGamesInFollowing() async {
        let sec = team("1", in: .collegeFootball, conference: 8)
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: sec, away: team("2", in: .collegeFootball, conference: 1))])
        let following = makeFollowing(conferences: [.cfb(8)])

        #expect(scoreboards.sections(followingIds: following.teamKeys,
                                     followedConferenceIds: following.conferenceIds)
                .first?.games.map(\.id) == ["c1"])
    }

    @Test func anFCSVisitorJoinsFollowingViaItsFBSHost() async {
        // The visitor carries no conference; the host's claim is what puts
        // the game in a followed-conference fan's Following section.
        let host = team("1", in: .collegeFootball, conference: 8)
        let visitor = team("99", in: .collegeFootball, conference: nil)
        let scoreboards = await makeScoreboards(cfb: [game("c1", home: host, away: visitor)])
        let following = makeFollowing(conferences: [.cfb(8)])

        #expect(scoreboards.sections(followingIds: following.teamKeys,
                                     followedConferenceIds: following.conferenceIds)
                .first?.games.map(\.id) == ["c1"])
    }

    // MARK: - Filters

    @Test func liveOnlyNarrowsEveryLeagueAndHidesTheEmpties() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c-live", home: team("1", in: .collegeFootball),
                       away: team("2", in: .collegeFootball), live: true),
                  game("c-pre", home: team("3", in: .collegeFootball),
                       away: team("4", in: .collegeFootball))],
            nfl: [game("n-pre", home: team("26", in: .nfl), away: team("27", in: .nfl))])

        let sections = scoreboards.sections(followingIds: [], liveOnly: true)
        #expect(sections.map(\.id) == [GameSection.id(for: .collegeFootball)])
        #expect(sections.first?.games.map(\.id) == ["c-live"])
    }

    @Test func aConferenceFilterHidesTheLeagueItCannotSpeakFor() async {
        // "SEC" is not a question the NFL's slate can answer, so its
        // section goes away rather than showing up empty.
        let scoreboards = await makeScoreboards(
            cfb: [game("c-sec", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 1)),
                  game("c-other", home: team("3", in: .collegeFootball, conference: 4),
                       away: team("4", in: .collegeFootball, conference: 1))],
            nfl: [game("n1", home: team("26", in: .nfl, conference: 8),
                       away: team("27", in: .nfl, conference: 8))])

        let sections = scoreboards.sections(followingIds: [],
                                            filter: .conference(.cfb(8)))
        #expect(sections.map(\.id) == [GameSection.id(for: .collegeFootball)])
        #expect(sections.first?.games.map(\.id) == ["c-sec"])
    }

    @Test func top25HidesTheNFLWhichHasNoPoll() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("ranked", home: team("1", in: .collegeFootball),
                       away: team("2", in: .collegeFootball), homeRank: 3),
                  game("unranked", home: team("3", in: .collegeFootball),
                       away: team("4", in: .collegeFootball))],
            nfl: [game("n1", home: team("26", in: .nfl), away: team("27", in: .nfl))])

        let sections = scoreboards.sections(followingIds: [], filter: .top25)
        #expect(sections.map(\.id) == [GameSection.id(for: .collegeFootball)])
        #expect(sections.first?.games.map(\.id) == ["ranked"])
    }

    @Test func theSlateFilterLeavesFollowingAlone() async {
        // Narrowing "my games" to the SEC would silently empty the section
        // for a Michigan fan — the mystery state the labeled chip exists
        // to avoid. Live still composes: it is a state, not a scope.
        let big10 = team("3", in: .collegeFootball, conference: 5)
        let scoreboards = await makeScoreboards(
            cfb: [game("sec", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 8)),
                  game("mine", home: big10,
                       away: team("4", in: .collegeFootball, conference: 5))])
        let following = makeFollowing([big10])

        let sections = scoreboards.sections(followingIds: following.teamKeys,
                                            filter: .conference(.cfb(8)))
        #expect(sections.first?.id == GameSection.followingId)
        #expect(sections.first?.games.map(\.id) == ["mine"])
        #expect(sections.last?.games.map(\.id) == ["sec"])
    }

    @Test func liveComposesWithFollowing() async {
        let mine = team("1", in: .collegeFootball)
        let scoreboards = await makeScoreboards(
            cfb: [game("mine-pre", home: mine, away: team("2", in: .collegeFootball))])
        let following = makeFollowing([mine])

        #expect(scoreboards.sections(followingIds: following.teamKeys, liveOnly: true).isEmpty)
    }

    @Test func sectionsAreChronological() async {
        let calendar = Calendar.current
        let noon = today()
        let evening = calendar.date(byAdding: .hour, value: 7, to: noon) ?? noon
        let mine = team("1", in: .collegeFootball)
        let scoreboards = await makeScoreboards(
            cfb: [game("late", home: mine, away: team("2", in: .collegeFootball), at: evening),
                  game("early", home: mine, away: team("3", in: .collegeFootball), at: noon)])
        let following = makeFollowing([mine])

        let sections = scoreboards.sections(followingIds: following.teamKeys)
        #expect(sections.first?.games.map(\.id) == ["early", "late"])
        #expect(sections.last?.games.map(\.id) == ["early", "late"])
    }

    @Test func followingLeadsWithLiveAndTrailsWithFinals() async {
        let calendar = Calendar.current
        let noon = today()
        let morning = calendar.date(byAdding: .hour, value: -4, to: noon) ?? noon
        let evening = calendar.date(byAdding: .hour, value: 7, to: noon) ?? noon
        let mine = team("1", in: .collegeFootball)
        func finished(_ id: String, at date: Date) -> Game {
            var base = game(id, home: mine, away: team("x\(id)", in: .collegeFootball), at: date)
            base = Game(id: base.id, date: base.date, name: nil, shortName: nil, weekNumber: 1,
                        status: .final(detail: nil), home: base.home, away: base.away,
                        broadcast: nil)
            return base
        }
        let scoreboards = await makeScoreboards(
            cfb: [finished("final-early", at: morning),
                  game("upcoming", home: mine, away: team("2", in: .collegeFootball), at: evening),
                  finished("final-late", at: noon),
                  game("live", home: mine, away: team("3", in: .collegeFootball),
                       live: true, at: noon)])
        let following = makeFollowing([mine])

        let sections = scoreboards.sections(followingIds: following.teamKeys)
        #expect(sections.first?.games.map(\.id)
                == ["live", "upcoming", "final-early", "final-late"])
    }

    // MARK: - The day axis

    @Test func theStripOpensOnToday() async {
        let scoreboards = await makeScoreboards()
        #expect(Calendar.current.isDateInToday(scoreboards.selectedDay))
        #expect(scoreboards.isOnToday)
    }

    @Test func selectingADayMovesTheWholePage() async {
        let calendar = Calendar.current
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: today()) ?? today()
        let scoreboards = await makeScoreboards(
            cfb: [game("c-today", home: team("1", in: .collegeFootball),
                       away: team("2", in: .collegeFootball)),
                  game("c-tomorrow", home: team("3", in: .collegeFootball),
                       away: team("4", in: .collegeFootball), at: tomorrow)])

        await scoreboards.select(day: tomorrow)
        #expect(!scoreboards.isOnToday)
        #expect(scoreboards.sections(followingIds: []).first?.games.map(\.id) == ["c-tomorrow"])

        await scoreboards.selectToday()
        #expect(scoreboards.isOnToday)
        #expect(scoreboards.sections(followingIds: []).first?.games.map(\.id) == ["c-today"])
    }

    @Test func adjacentDayIsBoundedByTheSeason() async {
        let scoreboards = await makeScoreboards()
        #expect(scoreboards.adjacentDay(offset: 1) != nil)
        #expect(scoreboards.adjacentDay(offset: -1) != nil)

        // A swipe past either end of the season is a quiet no-op.
        let span = SeasonSpan.days(year: scoreboards.seasonYear)
        await scoreboards.select(day: span.upperBound)
        #expect(scoreboards.adjacentDay(offset: 1) == nil)
        await scoreboards.select(day: span.lowerBound)
        #expect(scoreboards.adjacentDay(offset: -1) == nil)
    }

    @Test func theStripSpansTheWholeSeason() async {
        let scoreboards = await makeScoreboards()
        let days = scoreboards.days()
        let span = SeasonSpan.days(year: scoreboards.seasonYear)

        #expect(days.first?.date == Calendar.current.startOfDay(for: span.lowerBound))
        #expect(days.last?.date == Calendar.current.startOfDay(for: span.upperBound))
        // Contiguous, one chip per day, no gaps.
        #expect(Set(days.map(\.id)).count == days.count)
    }

    @Test func aPastSeasonRebindsTheStrip() async {
        let scoreboards = await makeScoreboards()
        await scoreboards.select(season: 2019)

        #expect(scoreboards.seasonYear == 2019)
        #expect(!scoreboards.isOnToday)
        let span = SeasonSpan.days(year: 2019)
        #expect(scoreboards.days().first?.date == Calendar.current.startOfDay(for: span.lowerBound))
    }

    @Test func availableSeasonsRunBackToTheCFPEra() async {
        let scoreboards = await makeScoreboards()
        #expect(scoreboards.availableSeasons.first == scoreboards.currentSeasonYear)
        #expect(scoreboards.availableSeasons.last == 2014)
    }

    // MARK: - Deep links

    @Test func aGameIsFoundByIdAcrossLeagues() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: team("1", in: .collegeFootball),
                       away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: team("26", in: .nfl), away: team("27", in: .nfl))])

        #expect(scoreboards.game(id: "n1")?.id == "n1")
        #expect(scoreboards.game(id: "c1")?.id == "c1")
        #expect(scoreboards.game(id: "nope") == nil)
    }
}

@Suite struct SeasonSpanTests {
    @Test func aSeasonOpensWithTheHallOfFameGameAndClosesAfterTheSuperBowl() {
        let calendar = Calendar.current
        let span = SeasonSpan.days(year: 2026)
        #expect(calendar.component(.year, from: span.lowerBound) == 2026)
        // The NFL's July opens the app's season — the Hall of Fame Game is
        // the first football of the year, and an August floor cut it off
        // (Andy, 2026-09-06).
        #expect(calendar.component(.month, from: span.lowerBound) == 7)
        // The NFL's February closes it; college football's January would
        // have cut the Super Bowl off.
        #expect(calendar.component(.year, from: span.upperBound) == 2027)
        #expect(calendar.component(.month, from: span.upperBound) == 2)
    }

    @Test func collegeFootballOpensInAugustAndClosesInJanuary() {
        let span = SeasonSpan.days(of: .collegeFootball, year: 2026)
        #expect(Calendar.current.component(.month, from: span.lowerBound) == 8)
        #expect(Calendar.current.component(.month, from: span.upperBound) == 1)
    }

    @Test func theNFLSeasonOpensInJuly() {
        let span = SeasonSpan.days(of: .nfl, year: 2026)
        #expect(Calendar.current.component(.month, from: span.lowerBound) == 7)
        #expect(Calendar.current.component(.month, from: span.upperBound) == 2)
    }

    @Test func aRolloverMonthBelongsToThePreviousSeason() {
        let calendar = Calendar.current
        let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 12))!
        let september = calendar.date(from: DateComponents(year: 2026, month: 9, day: 12))!
        #expect(SeasonSpan.year(containing: january) == 2026)
        #expect(SeasonSpan.year(containing: september) == 2026)
    }
}
