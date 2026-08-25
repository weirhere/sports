import Foundation
import Testing
@testable import StatSide

private struct StubProvider: ScoresProviding {
    let scoreboard: Scoreboard

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?) async throws -> Scoreboard {
        scoreboard
    }

    func rankings() async throws -> [Poll] { [] }
    func fbsConferences() async throws -> [ConferenceTeams] { [] }
    func conferenceStandings(year: Int?) async throws -> [ConferenceStandings] { [] }
    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        TeamSchedule(team: nil, record: nil, standing: nil, year: year, games: [])
    }
    func gameSummary(eventId: String) async throws -> GameSummary {
        throw ESPNError.invalidURL
    }
}

private func team(_ id: String, conference: Int?) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: conference)
}

private func game(_ id: String, home: Team, away: Team,
                  homeRank: Int? = nil, awayRank: Int? = nil,
                  live: Bool = false, date: Date? = .init(timeIntervalSince1970: 0)) -> Game {
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

        // SEC leads Big Ten here: the followed team's conference floats up.
        let sections = store.sections(followingIds: ["1"])
        #expect(sections.map(\.id) == [GameSection.followingId, GameSection.top25Id, "conf-SEC", "conf-Big Ten"])
        #expect(sections.allSatisfy { $0.games.map(\.id) == ["g1"] })
    }

    @Test func followingHiddenWhenFollowingNobody() async {
        let store = await makeStore(games: [game("g1", home: team("1", conference: 8),
                                                 away: team("2", conference: 8))])
        let sections = store.sections(followingIds: [])
        #expect(!sections.contains { $0.id == GameSection.followingId })
        #expect(sections.map(\.id) == ["conf-SEC"])
    }

    @Test func fcsVisitorStaysInHostConferenceOnly() async {
        // FCS opponents carry FCS conference ids (unknown to our FBS
        // table). The game belongs to the host's section; it must NOT
        // also pile into Other — Week 1 has ~48 of these.
        let store = await makeStore(games: [game("g1", home: team("1", conference: 8),
                                                 away: team("2", conference: 424242))])
        let sections = store.sections(followingIds: [])
        #expect(sections.map(\.id) == ["conf-SEC"])
    }

    @Test func gameWithNoPlaceableSideBucketsIntoOther() async {
        // Only when neither side has a known conference does Other claim
        // the game — the never-lose-a-game backstop.
        let store = await makeStore(games: [game("g1", home: team("1", conference: 424242),
                                                 away: team("2", conference: nil))])
        let sections = store.sections(followingIds: [])
        #expect(sections.map(\.id) == ["conf-Other"])
    }

    @Test func conferenceFollowPutsItsGamesInFollowing() async {
        let store = await makeStore(games: [
            game("sec", home: team("1", conference: 8), away: team("2", conference: 8)),
            game("acc", home: team("3", conference: 1), away: team("4", conference: 1)),
        ])
        // Following the SEC with zero team follows still produces a
        // Following section, containing only SEC games.
        let sections = store.sections(followingIds: [], followedConferenceIds: [8])
        let following = sections.first { $0.id == GameSection.followingId }
        #expect(following?.games.map(\.id) == ["sec"])
    }

    @Test func fcsVisitorJoinsFollowingViaItsFBSHost() async {
        // An SEC host with an FCS visitor (unknown conference id on the
        // away side): following the SEC still claims the game.
        let store = await makeStore(games: [game("g1", home: team("1", conference: 8),
                                                 away: team("2", conference: 424242))])
        let sections = store.sections(followingIds: [], followedConferenceIds: [8])
        #expect(sections.first?.id == GameSection.followingId)
        #expect(sections.first?.games.map(\.id) == ["g1"])
    }

    @Test func followedConferenceFloatsItsSection() async {
        let store = await makeStore(games: [
            game("g1", home: team("1", conference: 5), away: team("2", conference: 5)),
            game("g2", home: team("3", conference: 17), away: team("4", conference: 17)),
        ])
        // Big Ten (power4) normally leads; following Mountain West floats
        // it above, mirroring the followed-team float.
        let ids = store.sections(followingIds: [], followedConferenceIds: [17]).map(\.id)
        #expect(ids == [GameSection.followingId, "conf-Mountain West", "conf-Big Ten"])
    }

    @Test func conferenceIdStampedOnlyOnConferenceSections() async {
        let sec = team("1", conference: 8)
        let store = await makeStore(games: [game("g1", home: sec,
                                                 away: team("2", conference: 5), homeRank: 3)])
        let sections = store.sections(followingIds: ["1"])
        let byId = Dictionary(uniqueKeysWithValues: sections.map { ($0.id, $0.conferenceId) })
        #expect(byId[GameSection.followingId] == .some(nil))
        #expect(byId[GameSection.top25Id] == .some(nil))
        #expect(byId["conf-SEC"] == 8)
        #expect(byId["conf-Big Ten"] == 5)
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

    @Test func selectingPastSeasonLandsOnFinalSlot() async {
        // 2024 calendar: Week 1 in Aug 2024, CFP ending Jan 2025. Season
        // year omitted from the response, so the store derives it from the
        // calendar's first slot.
        let slots = [
            WeekSlot(label: "Week 1", shortLabel: "Week 1", seasonType: 2, value: 1,
                     startDate: Date(timeIntervalSince1970: 1_724_457_600),   // 2024-08-24
                     endDate: Date(timeIntervalSince1970: 1_725_235_200)),    // 2024-09-02
            WeekSlot(label: "CFP", shortLabel: "CFP", seasonType: 3, value: 999,
                     startDate: Date(timeIntervalSince1970: 1_735_689_600),   // 2025-01-01
                     endDate: Date(timeIntervalSince1970: 1_737_763_200)),    // 2025-01-25
        ]
        let scoreboard = Scoreboard(seasonYear: nil, seasonType: nil, currentWeekNumber: nil,
                                    weeks: slots, games: [])
        let store = ScoreboardStore(client: StubProvider(scoreboard: scoreboard))
        await store.loadInitial()
        #expect(store.currentSeasonYear == 2024)
        #expect(store.availableSeasons.first == 2024)
        #expect(store.availableSeasons.last == 2014)

        await store.select(season: 2023)
        #expect(store.seasonYear == 2023)
        #expect(store.selectedWeek?.id == "3-999")
    }

    @Test func adjacentWeekStepsAlongTheStrip() async {
        // Three-slot calendar with ESPN's current week in the middle. Slot
        // dates sit in 1970 so the Sunday rollover rule can never match
        // "yesterday" and the test stays deterministic on any weekday.
        let slots = (1...3).map { number in
            WeekSlot(label: "Week \(number)", shortLabel: "Week \(number)",
                     seasonType: 2, value: number,
                     startDate: Date(timeIntervalSince1970: Double(number) * 604_800),
                     endDate: Date(timeIntervalSince1970: Double(number + 1) * 604_800))
        }
        let scoreboard = Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 2,
                                    weeks: slots, games: [])
        let store = ScoreboardStore(client: StubProvider(scoreboard: scoreboard))
        await store.loadInitial()
        #expect(store.selectedWeek?.id == "2-2")

        // Forward and back from the middle; nil past either end.
        #expect(store.adjacentWeek(offset: 1)?.id == "2-3")
        #expect(store.adjacentWeek(offset: -1)?.id == "2-1")
        #expect(store.adjacentWeek(offset: 2) == nil)
        #expect(store.adjacentWeek(offset: -2) == nil)

        await store.select(week: slots[2])
        #expect(store.adjacentWeek(offset: 1) == nil)
        #expect(store.adjacentWeek(offset: -1)?.id == "2-2")
    }

    @Test func adjacentWeekIsNilBeforeAnyLoad() {
        let scoreboard = Scoreboard(seasonYear: nil, seasonType: nil, currentWeekNumber: nil,
                                    weeks: [], games: [])
        let store = ScoreboardStore(client: StubProvider(scoreboard: scoreboard))
        #expect(store.adjacentWeek(offset: 1) == nil)
        #expect(store.adjacentWeek(offset: -1) == nil)
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

    // MARK: - Date grouping

    /// Expected section id for a date, built the same way the store builds
    /// it: local-calendar day components.
    private func dayId(for date: Date) -> String {
        let parts = Calendar.current.dateComponents([.year, .month, .day],
                                                    from: Calendar.current.startOfDay(for: date))
        return String(format: "%@%04d-%02d-%02d", GameSection.dayPrefix,
                      parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    @Test func dateModePinsFollowingThenGroupsByDay() async {
        // Ten days apart so the two games land on distinct local days in
        // any timezone. The ranked, followed game must appear in Following
        // AND its day — no dedupe — and no Top 25 / conference sections.
        let dayOne = Date(timeIntervalSince1970: 0)
        let dayTwo = Date(timeIntervalSince1970: 864_000)
        let store = await makeStore(games: [
            game("g2", home: team("3", conference: 5), away: team("4", conference: 5), date: dayTwo),
            game("g1", home: team("1", conference: 8), away: team("2", conference: 8),
                 homeRank: 3, date: dayOne),
        ])
        let sections = store.sections(followingIds: ["1"], grouping: .date)
        #expect(sections.map(\.id) == [GameSection.followingId, dayId(for: dayOne), dayId(for: dayTwo)])
        #expect(sections[0].games.map(\.id) == ["g1"])
        #expect(sections[1].games.map(\.id) == ["g1"])
        #expect(sections[2].games.map(\.id) == ["g2"])
    }

    @Test func dateModeBucketsUndatedGamesIntoTrailingTBD() async {
        let store = await makeStore(games: [
            game("tbd", home: team("1", conference: 8), away: team("2", conference: 8), date: nil),
            game("dated", home: team("3", conference: 8), away: team("4", conference: 8)),
        ])
        let sections = store.sections(followingIds: [], grouping: .date)
        #expect(sections.count == 2)
        #expect(sections.last?.id == GameSection.tbdDayId)
        #expect(sections.last?.title == "TBD")
        #expect(sections.last?.games.map(\.id) == ["tbd"])
    }

    @Test func dateModeGamesWithinADayAreChronological() async {
        let store = await makeStore(games: [
            game("late", home: team("1", conference: 8), away: team("2", conference: 8),
                 date: Date(timeIntervalSince1970: 5000)),
            game("early", home: team("3", conference: 8), away: team("4", conference: 8),
                 date: Date(timeIntervalSince1970: 1000)),
        ])
        let sections = store.sections(followingIds: [], grouping: .date)
        #expect(sections.count == 1)
        #expect(sections[0].games.map(\.id) == ["early", "late"])
    }

    @Test func liveToggleComposesWithDateMode() async {
        let dayOne = Date(timeIntervalSince1970: 0)
        let dayTwo = Date(timeIntervalSince1970: 864_000)
        let store = await makeStore(games: [
            game("pre", home: team("1", conference: 8), away: team("2", conference: 8), date: dayOne),
            game("live", home: team("3", conference: 1), away: team("4", conference: 1),
                 live: true, date: dayTwo),
        ])
        store.liveOnly = true
        let sections = store.sections(followingIds: [], grouping: .date)
        #expect(sections.map(\.id) == [dayId(for: dayTwo)])
        #expect(sections[0].games.map(\.id) == ["live"])
    }
}
