import Foundation
import Testing
@testable import sports

private struct StubProvider: ScoresProviding {
    let scoreboard: Scoreboard

    func scoreboard(weekValue: Int?, seasonType: Int?) async throws -> Scoreboard {
        scoreboard
    }

    func rankings() async throws -> [Poll] { [] }
}

private func team(_ id: String, conference: Int?) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: conference)
}

private func game(_ id: String, home: Team, away: Team,
                  homeRank: Int? = nil, awayRank: Int? = nil,
                  live: Bool = false, date: Date = .init(timeIntervalSince1970: 0)) -> Game {
    Game(id: id, date: date, name: nil, shortName: nil, weekNumber: 1,
         status: live
            ? .live(displayClock: "5:00", period: 2, detail: nil, possessionTeamId: nil)
            : .pre(detail: nil),
         home: Competitor(team: home, score: nil, record: nil, rank: homeRank, isHome: true, winner: nil),
         away: Competitor(team: away, score: nil, record: nil, rank: awayRank, isHome: false, winner: nil),
         broadcast: nil)
}

@MainActor
@Suite struct ScoreboardStoreTests {
    private func makeStore(games: [Game]) async -> ScoreboardStore {
        let scoreboard = Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 1,
                                    weeks: [], games: games)
        let store = ScoreboardStore(client: StubProvider(scoreboard: scoreboard))
        await store.refresh()
        return store
    }

    @Test func gameAppearsInEverySectionItBelongsTo() async {
        // A ranked SEC team followed by the user, playing a Big Ten team:
        // the game must appear in Following, Top 25, SEC, and Big Ten.
        let sec = team("1", conference: 8)
        let bigTen = team("2", conference: 5)
        let store = await makeStore(games: [game("g1", home: sec, away: bigTen, homeRank: 3)])

        let sections = store.sections(followingIds: ["1"])
        #expect(sections.map(\.id) == [GameSection.followingId, GameSection.top25Id, "conf-Big Ten", "conf-SEC"])
        #expect(sections.allSatisfy { $0.games.map(\.id) == ["g1"] })
    }

    @Test func followingHiddenWhenFollowingNobody() async {
        let store = await makeStore(games: [game("g1", home: team("1", conference: 8),
                                                 away: team("2", conference: 8))])
        let sections = store.sections(followingIds: [])
        #expect(!sections.contains { $0.id == GameSection.followingId })
        #expect(sections.map(\.id) == ["conf-SEC"])
    }

    @Test func unknownConferenceBucketsIntoOther() async {
        // FCS opponents come back with no/unknown conference ids.
        let store = await makeStore(games: [game("g1", home: team("1", conference: 8),
                                                 away: team("2", conference: 424242))])
        let sections = store.sections(followingIds: [])
        #expect(sections.map(\.id) == ["conf-SEC", "conf-Other"])
    }

    @Test func liveToggleFiltersAndHidesEmptySections() async {
        let sec1 = team("1", conference: 8)
        let sec2 = team("2", conference: 8)
        let acc1 = team("3", conference: 1)
        let acc2 = team("4", conference: 1)
        let store = await makeStore(games: [
            game("pre", home: sec1, away: sec2),
            game("live", home: acc1, away: acc2, live: true),
        ])

        store.liveOnly = true
        let liveSections = store.sections(followingIds: [])
        #expect(liveSections.map(\.id) == ["conf-ACC"])
        #expect(liveSections[0].games.map(\.id) == ["live"])

        store.liveOnly = false
        #expect(store.sections(followingIds: []).count == 2)
        #expect(store.hasLiveGames)
    }

    @Test func conferenceOrderIsPower4ThenGroup5ThenIndependentsThenOther() async {
        let store = await makeStore(games: [
            game("g1", home: team("1", conference: 424242), away: team("2", conference: 424242)),
            game("g2", home: team("3", conference: 18), away: team("4", conference: 18)),
            game("g3", home: team("5", conference: 15), away: team("6", conference: 15)),
            game("g4", home: team("7", conference: 5), away: team("8", conference: 5)),
        ])
        let ids = store.sections(followingIds: []).map(\.id)
        #expect(ids == ["conf-Big Ten", "conf-MAC", "conf-Independents", "conf-Other"])
    }

    @Test func sectionsAreChronological() async {
        let sec1 = team("1", conference: 8)
        let sec2 = team("2", conference: 8)
        let sec3 = team("3", conference: 8)
        let sec4 = team("4", conference: 8)
        let later = Date(timeIntervalSince1970: 5000)
        let earlier = Date(timeIntervalSince1970: 1000)
        let store = await makeStore(games: [
            game("late", home: sec1, away: sec2, date: later),
            game("early", home: sec3, away: sec4, date: earlier),
        ])
        let sec = store.sections(followingIds: []).first
        #expect(sec?.games.map(\.id) == ["early", "late"])
    }
}
