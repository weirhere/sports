import Foundation
import Testing
@testable import StatSide

private struct StubProvider: ScoresProviding {
    let scoreboard: Scoreboard

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        scoreboard
    }

    func rankings() async throws -> [Poll] { [] }
    func fbsConferences() async throws -> [ConferenceTeams] { [] }
    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] { [] }
    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game] { [] }
    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        TeamSchedule(team: nil, record: nil, standing: nil, year: year, games: [])
    }
    func gameSummary(eventId: String) async throws -> GameSummary {
        throw ESPNError.invalidURL
    }
}

/// A provider whose slate depends on the divisions asked for, mirroring
/// ESPN: group 80 alone, or the union with group 81's extra games.
private struct DivisionProvider: ScoresProviding {
    let slots: [WeekSlot]

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        var games = [Game(id: "fbs", date: nil, name: nil, shortName: nil, weekNumber: 1,
                          status: .pre(detail: nil),
                          home: Competitor(team: Team(id: "h", location: "H", name: nil,
                                                      abbreviation: nil, displayName: nil,
                                                      shortDisplayName: nil, logoURL: nil,
                                                      conferenceId: 8),
                                           score: nil, record: nil, rank: nil,
                                           isHome: true, winner: nil),
                          away: Competitor(team: Team(id: "a", location: "A", name: nil,
                                                      abbreviation: nil, displayName: nil,
                                                      shortDisplayName: nil, logoURL: nil,
                                                      conferenceId: 1),
                                           score: nil, record: nil, rank: nil,
                                           isHome: false, winner: nil),
                          broadcast: nil)]
        if divisions.contains(.fcs) {
            games.append(Game(id: "fcs", date: nil, name: nil, shortName: nil, weekNumber: 1,
                              status: .pre(detail: nil),
                              home: Competitor(team: Team(id: "fh", location: "FH", name: nil,
                                                          abbreviation: nil, displayName: nil,
                                                          shortDisplayName: nil, logoURL: nil,
                                                          conferenceId: 20),
                                               score: nil, record: nil, rank: nil,
                                               isHome: true, winner: nil),
                              away: Competitor(team: Team(id: "fa", location: "FA", name: nil,
                                                          abbreviation: nil, displayName: nil,
                                                          shortDisplayName: nil, logoURL: nil,
                                                          conferenceId: 21),
                                               score: nil, record: nil, rank: nil,
                                               isHome: false, winner: nil),
                              broadcast: nil))
        }
        return Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 2,
                          weeks: slots, games: games)
    }

    func rankings() async throws -> [Poll] { [] }
    func fbsConferences() async throws -> [ConferenceTeams] { [] }
    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] { [] }
    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game] { [] }
    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        TeamSchedule(team: nil, record: nil, standing: nil, year: year, games: [])
    }
    func gameSummary(eventId: String) async throws -> GameSummary { throw ESPNError.invalidURL }
}

/// A provider driven by a closure, so tests can key responses off the
/// requested week/year — the week cache is invisible to a fixed stub.
private struct ClosureProvider: ScoresProviding {
    let provide: @MainActor (Int?, Int?, Int?) throws -> Scoreboard

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?,
                    divisions: Set<Conference.Division>) async throws -> Scoreboard {
        try await provide(weekValue, seasonType, year)
    }

    func rankings() async throws -> [Poll] { [] }
    func fbsConferences() async throws -> [ConferenceTeams] { [] }
    func conferenceStandings(year: Int?,
                             division: Conference.Division) async throws -> [ConferenceStandings] { [] }
    func conferenceGames(conferenceId: Int, year: Int?) async throws -> [Game] { [] }
    func teamSchedule(teamId: String, year: Int?) async throws -> TeamSchedule {
        TeamSchedule(team: nil, record: nil, standing: nil, year: year, games: [])
    }
    func gameSummary(eventId: String) async throws -> GameSummary {
        throw ESPNError.invalidURL
    }
}

/// Flips the closure provider into throwing mid-test.
private final class FailSwitch {
    var shouldFail = false
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
            ? .live(displayClock: "5:00", period: 2, detail: nil, phase: .playing, possessionTeamId: nil)
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

    @Test func aRealFCSConferenceStillDoesNotGetItsOwnSection() async {
        // The sibling of the test above, and the one that actually bites:
        // 20 is the Big Sky, which the registry now knows by name (E8's
        // first item). Knowing it must not surface it — scope (b) keeps
        // the default slate FBS-shaped until the user opts in, or one
        // visitor at an FBS school would spawn a Big Sky section on a
        // Saturday nobody asked for.
        let store = await makeStore(games: [game("g1", home: team("1", conference: 8),
                                                 away: team("2", conference: 20))])
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

        let liveSections = store.sections(followingIds: [], liveOnly: true)
        #expect(liveSections.map(\.id) == ["conf-ACC"])
        #expect(liveSections[0].games.map(\.id) == ["live"])

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
        let sections = store.sections(followingIds: [], grouping: .date, liveOnly: true)
        #expect(sections.map(\.id) == [dayId(for: dayTwo)])
        #expect(sections[0].games.map(\.id) == ["live"])
    }

    @Test func conferenceFilterKeepsEitherSidesGamesAndHidesTheRest() async {
        // The SEC filter claims the conference game, the cross-conference
        // game, and the FCS visitor's game at an SEC host — the same rules
        // as the SEC section itself.
        let store = await makeStore(games: [
            game("sec", home: team("1", conference: 8), away: team("2", conference: 8)),
            game("cross", home: team("3", conference: 8), away: team("4", conference: 5)),
            game("fcs", home: team("5", conference: 8), away: team("6", conference: nil)),
            game("acc", home: team("7", conference: 1), away: team("8", conference: 1)),
        ])
        let sections = store.sections(followingIds: [], filter: .conference(8))
        #expect(sections.map(\.id) == ["conf-Big Ten", "conf-SEC"])
        #expect(sections[0].games.map(\.id) == ["cross"])
        #expect(Set(sections[1].games.map(\.id)) == ["sec", "cross", "fcs"])
    }

    @Test func top25FilterKeepsRankedMatchupsOnly() async {
        let store = await makeStore(games: [
            game("ranked", home: team("1", conference: 8), away: team("2", conference: 5), homeRank: 3),
            game("unranked", home: team("3", conference: 8), away: team("4", conference: 8)),
        ])
        let sections = store.sections(followingIds: [], grouping: .date, filter: .top25)
        #expect(sections.count == 1)
        #expect(sections[0].games.map(\.id) == ["ranked"])
    }

    @Test func scoreFilterFiltersFollowingAndComposesWithLive() async {
        // Following a Big Ten team while filtered to the SEC: the Following
        // section vanishes with the game — sections are complete within the
        // active filters, the Live chip's precedent.
        let store = await makeStore(games: [
            game("bigten", home: team("1", conference: 5), away: team("2", conference: 5), live: true),
            game("secLive", home: team("3", conference: 8), away: team("4", conference: 8), live: true),
            game("secPre", home: team("5", conference: 8), away: team("6", conference: 8)),
        ])
        let sections = store.sections(followingIds: ["1"], grouping: .date,
                                      liveOnly: true, filter: .conference(8))
        #expect(sections.count == 1)
        #expect(sections[0].games.map(\.id) == ["secLive"])

        let restored = store.sections(followingIds: ["1"], grouping: .date, liveOnly: true)
        #expect(restored.first?.id == GameSection.followingId)
    }

    // MARK: - Week cache & prefetch

    private func weekSlot(_ value: Int) -> WeekSlot {
        WeekSlot(label: "Week \(value)", shortLabel: "Week \(value)",
                 seasonType: 2, value: value,
                 startDate: Date(timeIntervalSince1970: Double(value) * 604_800),
                 endDate: Date(timeIntervalSince1970: Double(value + 1) * 604_800))
    }

    /// Three-week 2026 strip, current week 2; every response's games are
    /// keyed by the requested week so cache entries are distinguishable.
    private func weekKeyedStore(failSwitch: FailSwitch = FailSwitch()) -> ScoreboardStore {
        let slots = (1...3).map(weekSlot)
        return ScoreboardStore(client: ClosureProvider { weekValue, _, _ in
            if failSwitch.shouldFail { throw ESPNError.invalidURL }
            let week = weekValue ?? 2
            return Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 2,
                              weeks: slots,
                              games: [game("w\(week)",
                                           home: team("h\(week)", conference: 8),
                                           away: team("a\(week)", conference: 8))])
        })
    }

    /// Prefetches are fire-and-forget tasks; give them bounded room to
    /// land instead of hanging a failing test.
    private func drainPrefetch(_ store: ScoreboardStore, for slots: [WeekSlot]) async {
        for _ in 0..<100 {
            if slots.allSatisfy({ store.cachedGames(for: $0) != nil }) { return }
            try? await Task.sleep(for: .milliseconds(10))
        }
    }

    @Test func prefetchWarmsBothNeighborsAfterLoad() async {
        let store = weekKeyedStore()
        await store.loadInitial()
        #expect(store.selectedWeek?.id == "2-2")
        await drainPrefetch(store, for: [weekSlot(1), weekSlot(3)])
        #expect(store.cachedGames(for: weekSlot(1))?.map(\.id) == ["w1"])
        #expect(store.cachedGames(for: weekSlot(3))?.map(\.id) == ["w3"])
    }

    @Test func selectCachesTheFetchedWeek() async {
        let store = weekKeyedStore()
        await store.loadInitial()
        await store.select(week: weekSlot(3))
        #expect(store.cachedGames(for: weekSlot(3))?.map(\.id) == ["w3"])
    }

    @Test func selectSeedsFromCacheWhenTheFetchFails() async {
        let failSwitch = FailSwitch()
        let store = weekKeyedStore(failSwitch: failSwitch)
        await store.loadInitial()
        await drainPrefetch(store, for: [weekSlot(3)])
        failSwitch.shouldFail = true
        await store.select(week: weekSlot(3))
        // The fresh fetch died; the cached slate stands in for the old
        // blank screen.
        #expect(store.games.map(\.id) == ["w3"])
        #expect(store.lastError != nil)
    }

    @Test func theStoreAsksForFBSOnlyUntilSomeoneOptsIn() async {
        // E8 scope (b): the 30s poll stays one request on an ordinary
        // Saturday. This is the assertion that the plumbing didn't quietly
        // turn the union on for everybody.
        let store = ScoreboardStore(client: DivisionProvider(slots: (1...3).map(weekSlot)))
        #expect(store.divisions == [.fbs])
        await store.loadInitial()
        #expect(store.games.map(\.id) == ["fbs"])
    }

    @Test func aDivisionSwitchCannotServeTheStaleSlate() async {
        // The cache key carries the divisions that produced the entry, so
        // an FBS-only week and a union week can't collide under one
        // WeekSlot.id — the swipe preview reads straight out of here.
        let store = ScoreboardStore(client: DivisionProvider(slots: (1...3).map(weekSlot)))
        await store.loadInitial()
        await drainPrefetch(store, for: [weekSlot(1), weekSlot(3)])
        #expect(store.cachedGames(for: weekSlot(2))?.map(\.id) == ["fbs"])

        await store.select(divisions: [.fbs, .fcs])
        // The selected week refetched as a union, and the neighbours the
        // old key had warmed are gone rather than standing in narrower.
        #expect(store.games.map(\.id) == ["fbs", "fcs"])
        #expect(store.cachedGames(for: weekSlot(2))?.map(\.id) == ["fbs", "fcs"])
    }

    @Test func settingTheSameDivisionsKeepsTheCache() async {
        let store = ScoreboardStore(client: DivisionProvider(slots: (1...3).map(weekSlot)))
        await store.loadInitial()
        await store.select(divisions: [.fbs])
        #expect(store.cachedGames(for: weekSlot(2))?.map(\.id) == ["fbs"])
    }

    @Test func seasonSwitchClearsTheCache() async {
        // The cache key spells "seasonType-value" with no year, so 2023's
        // calendar reuses 2026's ids — stale entries would collide.
        let slots = (1...3).map(weekSlot)
        let store = ScoreboardStore(client: ClosureProvider { weekValue, _, year in
            if year == 2023 {
                return Scoreboard(seasonYear: 2023, seasonType: 2, currentWeekNumber: nil,
                                  weeks: [self.weekSlot(1)],
                                  games: [game("y2023",
                                               home: team("1", conference: 8),
                                               away: team("2", conference: 8))])
            }
            let week = weekValue ?? 2
            return Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 2,
                              weeks: slots,
                              games: [game("w\(week)",
                                           home: team("h\(week)", conference: 8),
                                           away: team("a\(week)", conference: 8))])
        })
        await store.loadInitial()
        await drainPrefetch(store, for: [weekSlot(1), weekSlot(3)])

        await store.select(season: 2023)
        #expect(store.cachedGames(for: weekSlot(1))?.map(\.id) == ["y2023"])
        #expect(store.cachedGames(for: weekSlot(2)) == nil)
        #expect(store.cachedGames(for: weekSlot(3)) == nil)
    }

    @Test func sectionsFromGamesMatchesTheStoreSections() async {
        let games = [game("g1", home: team("1", conference: 8),
                          away: team("2", conference: 5), homeRank: 3)]
        let store = await makeStore(games: games)
        #expect(store.sections(from: games, followingIds: ["1"])
            == store.sections(followingIds: ["1"]))
    }

    @Test func repeatedSectionCallsServeUpdatedGameContent() async {
        // The sections pipeline memoizes (ScoresScreen re-asks on every
        // frame of the interactive week drag). The memo must key on game
        // content, never ids alone — a poll tick that only moves a score
        // or clock keeps the same ids and still has to invalidate.
        let home = team("1", conference: 8)
        let away = team("2", conference: 8)
        let before = game("g1", home: home, away: away, live: true)
        let store = await makeStore(games: [before])
        _ = store.sections(followingIds: [])

        let after = Game(id: "g1", date: before.date, name: nil, shortName: nil,
                         weekNumber: 1,
                         status: .live(displayClock: "2:00", period: 4, detail: nil,
                                       phase: .playing, possessionTeamId: nil),
                         home: Competitor(team: home, score: 21, record: nil, rank: nil,
                                          isHome: true, winner: nil),
                         away: Competitor(team: away, score: 17, record: nil, rank: nil,
                                          isHome: false, winner: nil),
                         broadcast: nil)
        let sections = store.sections(from: [after], followingIds: [])
        #expect(sections.first?.games.first?.home.score == 21)
        #expect(sections.first?.games.first?.away.score == 17)
    }

    @Test func selectCurrentWeekReturnsToTheRolloverSlot() async {
        // The Live toggle's jump home: browsing another week, then
        // selecting the current one, lands back on the rollover slot.
        func slot(_ value: Int) -> WeekSlot {
            WeekSlot(label: "Week \(value)", shortLabel: "Week \(value)",
                     seasonType: 2, value: value, startDate: nil, endDate: nil)
        }
        let scoreboard = Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 1,
                                    weeks: [slot(1), slot(2), slot(3)], games: [])
        let store = ScoreboardStore(client: StubProvider(scoreboard: scoreboard))
        await store.loadInitial()
        let home = store.currentWeekSlot
        #expect(home != nil)
        #expect(store.selectedWeek?.id == home?.id)

        await store.select(week: slot(3))
        #expect(store.selectedWeek?.id == "2-3")

        await store.selectCurrentWeek()
        #expect(store.selectedWeek?.id == home?.id)
    }
}
