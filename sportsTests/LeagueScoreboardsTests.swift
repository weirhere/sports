import Foundation
import Testing
@testable import StatSide

private struct LeagueStub: ScoresProviding {
    nonisolated let league: League
    let board: Scoreboard

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard { board }
    func rankings() async throws -> [Poll] { [] }
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

private func game(_ id: String, home: Team, away: Team, live: Bool = false) -> Game {
    Game(id: id, date: Date(timeIntervalSince1970: 0), name: nil, shortName: nil,
         weekNumber: 1,
         status: live ? .live(displayClock: "5:00", period: 2, detail: nil,
                              phase: .playing, possessionTeamId: nil)
                      : .pre(detail: nil),
         home: Competitor(team: home, score: live ? 7 : nil, record: nil, rank: nil,
                          isHome: true, winner: nil),
         away: Competitor(team: away, score: live ? 3 : nil, record: nil, rank: nil,
                          isHome: false, winner: nil),
         broadcast: nil)
}

private let week = WeekSlot(label: "Week 1", shortLabel: "Wk 1", seasonType: 2,
                            value: 1, startDate: nil, endDate: nil)

private func board(_ games: [Game]) -> Scoreboard {
    Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 1,
               weeks: [week], games: games)
}

@MainActor
private func makeScoreboards(cfb: [Game], nfl: [Game],
                             selected: League = .collegeFootball) async -> LeagueScoreboards {
    let stores: [League: ScoreboardStore] = [
        .collegeFootball: ScoreboardStore(
            league: .collegeFootball,
            client: LeagueStub(league: .collegeFootball, board: board(cfb))),
        .nfl: ScoreboardStore(
            league: .nfl, client: LeagueStub(league: .nfl, board: board(nfl))),
    ]
    let scoreboards = LeagueScoreboards(selected: selected, stores: stores)
    await scoreboards.loadInitial()
    return scoreboards
}

private func makeFollowing() -> FollowingStore {
    let name = "test.leaguescoreboards.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: name)!
    defaults.removePersistentDomain(forName: name)
    return FollowingStore(defaults: defaults)
}

@MainActor
@Suite struct LeagueScoreboardsTests {
    private let bruins = team("26", in: .collegeFootball)
    private let seahawks = team("26", in: .nfl)

    /// Each league keeps its own store, so the same ESPN id can mean two
    /// different teams without the two slates ever mixing.
    @Test func eachLeagueKeepsItsOwnSlate() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl))])

        #expect(scoreboards.store(for: .collegeFootball).games.map(\.id) == ["c1"])
        #expect(scoreboards.store(for: .nfl).games.map(\.id) == ["n1"])
        #expect(scoreboards.selected.league == .collegeFootball)
    }

    // MARK: - Cross-league Following

    /// "My games" shouldn't care which sport they belong to.
    @Test func followingReachesIntoTheOtherLeague() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl))])
        let following = makeFollowing()
        following.toggle(bruins)
        following.toggle(seahawks)

        let elsewhere = scoreboards.followedGamesElsewhere(than: .collegeFootball,
                                                           following: following)
        #expect(elsewhere.map(\.id) == ["n1"])

        let sections = scoreboards.selected.sections(
            followingIds: following.teamKeys, extraFollowingGames: elsewhere)
        let followingSection = sections.first { $0.id == GameSection.followingId }
        #expect(followingSection?.games.map(\.id) == ["c1", "n1"])
        // Mixed leagues, so the rows tag which is which.
        #expect(followingSection?.spansLeagues == true)
    }

    /// A single-league Following section tags nothing — the screen's own
    /// scope already says which league you're looking at.
    @Test func aSingleLeagueFollowingSectionIsUntagged() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl))])
        let following = makeFollowing()
        following.toggle(bruins)

        let sections = scoreboards.selected.sections(followingIds: following.teamKeys)
        #expect(sections.first { $0.id == GameSection.followingId }?.spansLeagues == false)
    }

    /// The tag reaches VoiceOver too, so a cross-league section is legible
    /// without sight of it.
    @Test func aTaggedRowSpeaksItsLeagueFirst() {
        let nflGame = game("n1", home: seahawks, away: team("25", in: .nfl))
        let tagged = GameRow(game: nflGame, leagueTag: .nfl)
        let untagged = GameRow(game: nflGame)

        #expect(tagged.spokenLabel == "NFL, \(untagged.accessibilitySummary)")
        // An untagged row says exactly what it always did.
        #expect(untagged.spokenLabel == untagged.accessibilitySummary)
    }

    /// Following an id in one league must not pull the other league's team
    /// of the same id in — the collision this whole axis exists for.
    @Test func aCollidingIdInTheOtherLeagueIsNotFollowed() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl))])
        let following = makeFollowing()
        following.toggle(bruins)   // UCLA only

        #expect(scoreboards.followedGamesElsewhere(than: .collegeFootball,
                                                   following: following).isEmpty)
    }

    /// Browsing to another week is time navigation inside one league; the
    /// other league's games have no honest place there, since the two
    /// calendars don't line up at all.
    @Test func aPastWeekDropsTheCrossLeagueGames() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl))])
        let following = makeFollowing()
        following.toggle(seahawks)

        #expect(!scoreboards.followedGamesElsewhere(than: .collegeFootball,
                                                    following: following).isEmpty)

        let other = WeekSlot(label: "Week 9", shortLabel: "Wk 9", seasonType: 2,
                             value: 9, startDate: nil, endDate: nil)
        await scoreboards.store(for: .collegeFootball).select(week: other)

        #expect(scoreboards.followedGamesElsewhere(than: .collegeFootball,
                                                   following: following).isEmpty)
    }

    // MARK: - Auto-pick

    /// Opens on whichever league is actually playing.
    @Test func exactlyOneLiveLeagueWinsTheColdLaunch() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl), live: true)])

        #expect(scoreboards.autoSelectLiveLeague() == .nfl)
        #expect(scoreboards.selectedLeague == .nfl)
    }

    /// Ambiguity leaves the saved preference alone — an app that
    /// rearranges itself is a surprise.
    @Test func bothLiveOrNeitherLiveChangesNothing() async {
        let bothLive = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball), live: true)],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl), live: true)])
        #expect(bothLive.autoSelectLiveLeague() == nil)
        #expect(bothLive.selectedLeague == .collegeFootball)

        let neitherLive = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl))],
            selected: .nfl)
        #expect(neitherLive.autoSelectLiveLeague() == nil)
        #expect(neitherLive.selectedLeague == .nfl)
    }

    /// An explicit choice this session is never overridden.
    @Test func anExplicitPickBeatsTheAutoPick() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl), live: true)])

        scoreboards.select(.collegeFootball)
        #expect(scoreboards.autoSelectLiveLeague() == nil)
        #expect(scoreboards.selectedLeague == .collegeFootball)
    }

    /// A restored preference is not an explicit choice — the auto-pick is
    /// still allowed to move off it, which is the whole point.
    @Test func aRestoredPreferenceStillYieldsToLiveGames() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl), live: true)])

        scoreboards.restore(.collegeFootball)
        #expect(scoreboards.autoSelectLiveLeague() == .nfl)
    }

    /// It fires once per launch, not on every scene activation.
    @Test func theAutoPickOnlyEverFiresOnce() async {
        let scoreboards = await makeScoreboards(
            cfb: [game("c1", home: bruins, away: team("2", in: .collegeFootball))],
            nfl: [game("n1", home: seahawks, away: team("25", in: .nfl), live: true)])

        #expect(scoreboards.autoSelectLiveLeague() == .nfl)
        #expect(scoreboards.autoSelectLiveLeague() == nil)
    }
}

@Suite struct NFLSectionGroupingTests {
    /// ESPN's NFL scoreboard ships no `conferenceId`, so without the
    /// registry fallback every NFL game would land in "Other".
    @Test func theRegistrySuppliesTheDivisionTheScoreboardOmits() {
        #expect(Conference.division(forTeamId: "26", in: .nfl) == 3)      // Seattle → NFC West
        #expect(Conference.division(forTeamId: "12", in: .nfl) == 6)      // KC → AFC West
        #expect(Conference.division(forTeamId: "999", in: .nfl) == nil)
        // College football carries its own id inline and needs no table.
        #expect(Conference.division(forTeamId: "26", in: .collegeFootball) == nil)
    }

    /// Every NFL team resolves to a division, so no NFL game can fall into
    /// the "Other" bucket for want of a group.
    @Test func everyNFLTeamHasADivision() {
        let ids = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15, 16,
                   17, 18, 19, 20, 21, 22, 23, 24, 25, 26, 27, 28, 29, 30, 33, 34]
        for id in ids {
            let division = Conference.division(forTeamId: String(id), in: .nfl)
            #expect(division != nil, "team \(id) has no division")
            #expect(Conference.tier(for: division, in: .nfl) == .nflDivision)
        }
    }
}
