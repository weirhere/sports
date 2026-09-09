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
private func makeScoreboards(cfb: [Game] = [], nfl: [Game] = [],
                             nba: [Game] = [], nhl: [Game] = []) async -> LeagueScoreboards {
    // A store for *every* league, not just the ones a case names.
    // `LeagueScoreboards.store(for:)` falls back to the college-football
    // store for a league it has none for, so a partial dictionary made
    // `all` return that one store several times over and quietly
    // multiplied every count this suite asserts.
    let games: [League: [Game]] = [.collegeFootball: cfb, .nfl: nfl, .nba: nba, .nhl: nhl]
    let stores: [League: ScoreboardStore] = Dictionary(
        uniqueKeysWithValues: League.allCases.map { league in
            (league, ScoreboardStore(league: league,
                                     client: LeagueStub(league: league,
                                                        games: games[league] ?? [])))
        })
    let scoreboards = LeagueScoreboards(stores: stores)
    await scoreboards.loadInitial()
    return scoreboards
}

@MainActor
private func makeFollowing(_ teams: [Team] = [],
                           conferences: [ConferenceID] = [],
                           polls: [League] = []) -> FollowingStore {
    let name = "test.leaguescoreboards.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name) ?? .standard
    defaults.removePersistentDomain(forName: name)
    let store = FollowingStore(defaults: defaults)
    for team in teams { store.toggle(team) }
    for conference in conferences { store.toggleConference(conference) }
    for league in polls { store.togglePoll(in: league) }
    return store
}

/// The Scores id for a conference section — "conf-cfb-8".
private func confSection(_ id: ConferenceID) -> String {
    GameSection.conferencePrefix + id.token
}

private let otherSection = GameSection.otherPrefix + League.collegeFootball.rawValue

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

    @Test func collegeFootballBreaksDownByConferenceAndTheNFLDoesNot() async {
        // Andy, 2026-09-06: "switch back to the conference (big 10, sec)
        // but nfl can remain as is."
        let cfb = [game("sec", home: team("1", in: .collegeFootball, conference: 8),
                        away: team("2", in: .collegeFootball, conference: 8)),
                   game("b1g", home: team("3", in: .collegeFootball, conference: 5),
                        away: team("4", in: .collegeFootball, conference: 5))]
        let nfl = [game("n1", home: team("26", in: .nfl, conference: 4),
                        away: team("27", in: .nfl, conference: 6)),
                   game("n2", home: team("1", in: .nfl, conference: 11),
                        away: team("2", in: .nfl, conference: 4))]
        let scoreboards = await makeScoreboards(cfb: cfb, nfl: nfl)

        let sections = scoreboards.sections(followingIds: [])
        #expect(sections.map(\.id) == [confSection(.cfb(5)), confSection(.cfb(8)),
                                       GameSection.id(for: .nfl)])
        #expect(sections.map(\.title) == ["Big Ten", "SEC", "NFL"])
        #expect(sections.last?.games.map(\.id) == ["n1", "n2"])
        #expect(sections.allSatisfy { $0.league != nil })
    }

    @Test func aCrossConferenceGameLandsInBothSections() async {
        // Sections are complete, never deduplicated.
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 5))])

        let sections = scoreboards.sections(followingIds: [])
        #expect(sections.map(\.id) == [confSection(.cfb(5)), confSection(.cfb(8))])
        #expect(sections.allSatisfy { $0.games.map(\.id) == ["c1"] })
    }

    @Test func conferencesSortByTierThenName() async {
        // P4 → G5 → Independents → Other.
        let scoreboards = await makeScoreboards(
            cfb: [game("g5", home: team("1", in: .collegeFootball, conference: 15),
                       away: team("2", in: .collegeFootball, conference: 15)),
                  game("p4", home: team("3", in: .collegeFootball, conference: 8),
                       away: team("4", in: .collegeFootball, conference: 8)),
                  game("indep", home: team("5", in: .collegeFootball, conference: 18),
                       away: team("6", in: .collegeFootball, conference: 18)),
                  game("unknown", home: team("7", in: .collegeFootball, conference: nil),
                       away: team("8", in: .collegeFootball, conference: nil))])

        #expect(scoreboards.sections(followingIds: []).map(\.id)
                == [confSection(.cfb(8)), confSection(.cfb(15)),
                    confSection(.cfb(18)), otherSection])
    }

    @Test func anFCSVisitorStaysInItsHostsConference() async {
        // Or Week 1's ~48 FCS matchups pile into Other as duplicates. The
        // slate is FBS-only unless someone opts in, so the visitor's own
        // conference spawns no section either way.
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("99", in: .collegeFootball, conference: 20))])

        #expect(scoreboards.sections(followingIds: []).map(\.id) == [confSection(.cfb(8))])
    }

    @Test func aLeagueWithNoGamesGetsNoSection() async {
        let cfb = game("c1", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 8))
        let scoreboards = await makeScoreboards(cfb: [cfb], nfl: [])

        #expect(scoreboards.sections(followingIds: []).map(\.id) == [confSection(.cfb(8))])
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
            cfb: [game("c1", home: team("1", in: .collegeFootball, conference: 1),
                       away: team("2", in: .collegeFootball, conference: 1))])
        #expect(scoreboards.sections(followingIds: []).first?.id
                == confSection(.cfb(1)))
    }

    // MARK: - Followed tables

    @Test func aFollowedConferenceHoistsItsSectionAndStaysOutOfFollowing() async {
        // Andy, 2026-09-06: a table follow moves that table up the page,
        // it does not pour its whole slate into "my games".
        let scoreboards = await makeScoreboards(
            cfb: [game("sec", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 8)),
                  game("acc", home: team("3", in: .collegeFootball, conference: 1),
                       away: team("4", in: .collegeFootball, conference: 1))])
        let following = makeFollowing(conferences: [.cfb(8)])

        let sections = scoreboards.sections(followingIds: following.teamKeys,
                                            followedTables: following.orderedTables)
        // No Following section at all — nothing is followed by team.
        #expect(sections.map(\.id) == [confSection(.cfb(8)), confSection(.cfb(1))])
        #expect(sections.first?.games.map(\.id) == ["sec"])
    }

    @Test func aHoistedConferenceIsMovedNotCloned() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("sec", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 8))])
        let following = makeFollowing(conferences: [.cfb(8)])

        let sections = scoreboards.sections(followingIds: following.teamKeys,
                                            followedTables: following.orderedTables)
        #expect(sections.map(\.id) == [confSection(.cfb(8))])
    }

    @Test func followedTablesFollowTheUsersDraggedOrder() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("sec", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 8)),
                  game("b1g", home: team("3", in: .collegeFootball, conference: 5),
                       away: team("4", in: .collegeFootball, conference: 5))])
        // Followed SEC first, then the Big Ten: a new follow lands at the
        // end, because the list is a priority order and promoting one
        // nobody placed there would scramble it.
        let following = makeFollowing(conferences: [.cfb(8), .cfb(5)])
        #expect(scoreboards.sections(followingIds: [],
                                     followedTables: following.orderedTables).map(\.id)
                == [confSection(.cfb(8)), confSection(.cfb(5))])

        following.move(.conference(.cfb(5)), onto: .conference(.cfb(8)))
        #expect(scoreboards.sections(followingIds: [],
                                     followedTables: following.orderedTables).map(\.id)
                == [confSection(.cfb(5)), confSection(.cfb(8))])
    }

    @Test func aFollowedNFLConferenceGetsASectionTheStackDoesNotHave() async {
        // The NFL stays one accordion, so a followed AFC has no counterpart
        // to move — it earns a section, and its games stay in the NFL's too.
        let scoreboards = await makeScoreboards(
            nfl: [game("afc", home: team("2", in: .nfl, conference: 4),
                       away: team("7", in: .nfl, conference: 6)),
                  game("nfc", home: team("6", in: .nfl, conference: 1),
                       away: team("3", in: .nfl, conference: 10))])
        let following = makeFollowing(conferences: [.nfl(8)])

        let sections = scoreboards.sections(followingIds: following.teamKeys,
                                            followedTables: following.orderedTables)
        #expect(sections.map(\.id) == ["conf-nfl-8", GameSection.id(for: .nfl)])
        #expect(sections.first?.title == "AFC")
        #expect(sections.first?.games.map(\.id) == ["afc"])
        #expect(sections.last?.games.map(\.id) == ["afc", "nfc"])
    }

    @Test func followingTheWholeNFLHoistsItsOwnSection() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("sec", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 8))],
            nfl: [game("n1", home: team("2", in: .nfl, conference: 4),
                       away: team("7", in: .nfl, conference: 6))])
        let following = makeFollowing(conferences: [.nfl(9)])

        #expect(scoreboards.sections(followingIds: [],
                                     followedTables: following.orderedTables).map(\.id)
                == [GameSection.id(for: .nfl), confSection(.cfb(8))])
    }

    @Test func aFollowedPollGetsARankedSection() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("ranked", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 8), homeRank: 3),
                  game("plain", home: team("3", in: .collegeFootball, conference: 8),
                       away: team("4", in: .collegeFootball, conference: 8))])
        let following = makeFollowing(polls: [.collegeFootball])

        let sections = scoreboards.sections(followingIds: [],
                                            followedTables: following.orderedTables)
        #expect(sections.map(\.id) == ["poll-cfb", confSection(.cfb(8))])
        #expect(sections.first?.title == "Top 25")
        #expect(sections.first?.games.map(\.id) == ["ranked"])
    }

    @Test func aFollowedTableWithNoGamesTodayGetsNoSection() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("acc", home: team("1", in: .collegeFootball, conference: 1),
                       away: team("2", in: .collegeFootball, conference: 1))])
        let following = makeFollowing(conferences: [.cfb(8)])

        #expect(scoreboards.sections(followingIds: [],
                                     followedTables: following.orderedTables).map(\.id)
                == [confSection(.cfb(1))])
    }

    @Test func teamFollowsStillLeadWithTheirOwnSection() async {
        let mine = team("1", in: .collegeFootball, conference: 8)
        let scoreboards = await makeScoreboards(
            cfb: [game("mine", home: mine, away: team("2", in: .collegeFootball, conference: 8)),
                  game("theirs", home: team("3", in: .collegeFootball, conference: 5),
                       away: team("4", in: .collegeFootball, conference: 5))])
        let following = makeFollowing([mine], conferences: [.cfb(5)])

        let sections = scoreboards.sections(followingIds: following.teamKeys,
                                            followedTables: following.orderedTables)
        #expect(sections.map(\.id) == [GameSection.followingId, confSection(.cfb(5)),
                                       confSection(.cfb(8))])
        #expect(sections.first?.games.map(\.id) == ["mine"])
    }

    // MARK: - Filters

    @Test func liveOnlyNarrowsEveryLeagueAndHidesTheEmpties() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c-live", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 8), live: true),
                  game("c-pre", home: team("3", in: .collegeFootball, conference: 5),
                       away: team("4", in: .collegeFootball, conference: 5))],
            nfl: [game("n-pre", home: team("26", in: .nfl, conference: 4),
                       away: team("27", in: .nfl, conference: 6))])

        let sections = scoreboards.sections(followingIds: [], liveOnly: true)
        #expect(sections.map(\.id) == [confSection(.cfb(8))])
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

        // The SEC's game is an ACC game too, so it keeps both sections —
        // the filter narrows which games are on the page, and the sections
        // are still complete over what's left.
        let sections = scoreboards.sections(followingIds: [],
                                            filter: .conference(.cfb(8)))
        #expect(sections.map(\.id) == [confSection(.cfb(1)), confSection(.cfb(8))])
        #expect(sections.allSatisfy { $0.games.map(\.id) == ["c-sec"] })
    }

    @Test func top25HidesTheNFLWhichHasNoPoll() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("ranked", home: team("1", in: .collegeFootball, conference: 8),
                       away: team("2", in: .collegeFootball, conference: 8), homeRank: 3),
                  game("unranked", home: team("3", in: .collegeFootball, conference: 8),
                       away: team("4", in: .collegeFootball, conference: 8))],
            nfl: [game("n1", home: team("26", in: .nfl, conference: 4),
                       away: team("27", in: .nfl, conference: 6))])

        let sections = scoreboards.sections(followingIds: [], filter: .top25)
        #expect(sections.map(\.id) == [confSection(.cfb(8))])
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

    /// The day strip reads `selectedDay`, and a swipe has to move it on the
    /// frame the thumb lifts — so the move and the fetch are separable
    /// (Andy, 2026-09-07: "no delay").
    @Test func showingADayMovesTheStripBeforeTheFetch() async {
        let calendar = Calendar.current
        let later = calendar.date(byAdding: .day, value: 10, to: today()) ?? today()
        let scoreboards = await makeScoreboards(
            cfb: [game("c-today", home: team("1", in: .collegeFootball),
                       away: team("2", in: .collegeFootball)),
                  game("c-later", home: team("3", in: .collegeFootball),
                       away: team("4", in: .collegeFootball), at: later)])

        // Synchronous: the day is already the new one, with nothing awaited.
        #expect(scoreboards.show(day: later))
        #expect(scoreboards.selectedDay == calendar.startOfDay(for: later))
        #expect(!scoreboards.selectedDayIsLoaded)
        // Idempotent — a day that didn't move reports it, so `select(day:)`
        // can skip the fetch.
        #expect(!scoreboards.show(day: later))

        await scoreboards.loadSelectedDay()
        #expect(scoreboards.selectedDayIsLoaded)
        #expect(scoreboards.sections(followingIds: []).first?.games.map(\.id) == ["c-later"])
    }

    /// A settling swipe asks for its neighbours from the day still on
    /// screen, not the one it just committed to.
    @Test func adjacentDayCanCountFromAnyDay() async {
        let calendar = Calendar.current
        let scoreboards = await makeScoreboards()
        // Counted from the season's opening rather than today, so the day
        // either side of it is inside the span whenever the suite runs.
        let span = SeasonSpan.days(year: scoreboards.seasonYear)
        let later = calendar.date(byAdding: .day, value: 10,
                                  to: calendar.startOfDay(for: span.lowerBound)) ?? span.lowerBound

        #expect(scoreboards.adjacentDay(offset: 1, from: later)
                    == calendar.date(byAdding: .day, value: 1, to: later))
        #expect(scoreboards.adjacentDay(offset: -1, from: later)
                    == calendar.date(byAdding: .day, value: -1, to: later))
        // Still bounded by the season, whatever day it counts from.
        #expect(scoreboards.adjacentDay(offset: 1, from: span.upperBound) == nil)
    }

    @Test func theTodayJumpWaitsUntilTheTodayChipIsOffTheStrip() async {
        let calendar = Calendar.current
        let scoreboards = await makeScoreboards()
        #expect(!scoreboards.showsTodayJump)

        // Inside the reach the chip is still on screen, so the floating
        // button would only say it twice.
        for offset in [1, -1, 2, -2] {
            let day = calendar.date(byAdding: .day, value: offset, to: today()) ?? today()
            await scoreboards.select(day: day)
            #expect(scoreboards.canJumpToToday)
            #expect(scoreboards.todayIsOnStrip())
            #expect(!scoreboards.showsTodayJump)
        }

        for offset in [3, -3, 30] {
            let day = calendar.date(byAdding: .day, value: offset, to: today()) ?? today()
            await scoreboards.select(day: day)
            #expect(!scoreboards.todayIsOnStrip())
            #expect(scoreboards.showsTodayJump)
        }
    }

    @Test func aPastSeasonHasNoTodayChipHoweverCloseTheDatesLook() async {
        let scoreboards = await makeScoreboards()
        await scoreboards.select(season: 2019)

        #expect(!scoreboards.todayIsOnStrip())
        #expect(scoreboards.showsTodayJump)
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

    /// The widget lists games a fortnight out and the screen holds five
    /// days, so a tap on next week's kickoff finds nothing in memory. The
    /// link's day is what sends the strip to fetch it (Andy, 2026-09-07).
    @Test func openingADayBringsAFarOffGameIntoMemory() async {
        let calendar = Calendar.current
        let nextWeek = calendar.date(byAdding: .day, value: 9, to: today()) ?? today()
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: team("1", in: .collegeFootball),
                       away: team("2", in: .collegeFootball))],
            nfl: [game("far", home: team("26", in: .nfl), away: team("27", in: .nfl),
                       at: nextWeek)])

        #expect(scoreboards.game(id: "far") == nil)

        await scoreboards.open(day: nextWeek)

        #expect(scoreboards.game(id: "far")?.id == "far")
        #expect(scoreboards.selectedDay == calendar.startOfDay(for: nextWeek))
    }

    /// A link's day can belong to a season the strip isn't bound to, and a
    /// selected day with no chip is a screen with no way back.
    @Test func openingADayRebindsTheStripToItsSeason() async {
        let scoreboards = await makeScoreboards()
        let october2019 = Calendar.current.date(from: DateComponents(year: 2019, month: 10, day: 12))

        await scoreboards.open(day: october2019 ?? .now)

        #expect(scoreboards.seasonYear == 2019)
        #expect(scoreboards.days().contains { $0.date == october2019 })
    }
}

@Suite struct SeasonSpanTests {
    @Test func aSeasonRunsFromTheFirstLeagueToOpenToTheLastToFinish() {
        let calendar = Calendar.current
        let span = SeasonSpan.days(year: 2026)
        #expect(calendar.component(.year, from: span.lowerBound) == 2026)
        // The NFL's July opens the app's season — the Hall of Fame Game is
        // the first football of the year, and an August floor cut it off
        // (Andy, 2026-09-06).
        #expect(calendar.component(.month, from: span.lowerBound) == 7)
        // June closes it: the NBA Finals and the Stanley Cup are the last
        // games of the season that opened in July. This was February until
        // basketball and hockey arrived, when the app stopped having an
        // offseason at all.
        #expect(calendar.component(.year, from: span.upperBound) == 2027)
        #expect(calendar.component(.month, from: span.upperBound) == 6)
    }

    /// The union is every league at once; each league still keeps its own.
    @Test func theWinterLeaguesOpenInSeptemberAndCloseInJune() {
        let calendar = Calendar.current
        for league in [League.nba, .nhl] {
            let span = SeasonSpan.days(of: league, year: 2026)
            #expect(calendar.component(.month, from: span.lowerBound) == 9)
            #expect(calendar.component(.year, from: span.upperBound) == 2027)
            #expect(calendar.component(.month, from: span.upperBound) == 6)
        }
    }

    /// The rollover rule takes the *latest* month any league runs into, so
    /// adding a June-rollover league moves the boundary for everyone. Every
    /// month still resolves to the season it belongs to — which is the
    /// whole reason the rule is derived rather than per-league.
    @Test func everyMonthResolvesToItsOwnSeason() {
        let calendar = Calendar.current
        func season(_ year: Int, _ month: Int) -> Int {
            SeasonSpan.year(containing:
                calendar.date(from: DateComponents(year: year, month: month, day: 15)) ?? .now)
        }
        // July opens a season (the Hall of Fame Game) through December.
        for month in 7...12 { #expect(season(2026, month) == 2026) }
        // January and February are still football's — the CFP and the
        // Super Bowl. March through June are basketball's and hockey's.
        for month in 1...6 { #expect(season(2027, month) == 2026) }
        // And the next July starts over.
        #expect(season(2027, 7) == 2027)
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
