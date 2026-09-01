import Foundation
import Testing
@testable import StatSide

private final class FixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: FixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

@Suite struct ScoreboardDecodingTests {
    @Test func decodesLiveScoreboard() throws {
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("scoreboard-live"))
        let scoreboard = ESPNMapper.scoreboard(from: dto)

        #expect(scoreboard.games.count == 99)
        #expect(scoreboard.seasonYear == 2026)
        #expect(scoreboard.currentWeekNumber == 1)

        // 15 regular-season entries + Bowls + CFP; the Off Season period is excluded.
        #expect(scoreboard.weeks.count == 17)
        #expect(scoreboard.weeks.filter(\.isPostseason).map(\.label) == ["Bowls", "CFP"])
        #expect(scoreboard.weeks.allSatisfy { $0.startDate != nil && $0.endDate != nil })

        let game = try #require(scoreboard.games.first)
        #expect(game.home.team.id.isEmpty == false)
        #expect(game.away.team.id.isEmpty == false)
        if case .pre = game.status {} else {
            Issue.record("expected a pre-game status in the July fixture")
        }
        #expect(game.date != nil)
    }

    @Test func unannouncedKickoffMapsToTimeTBD() throws {
        // Scoreboard payloads carry `timeValid` on the competition only.
        let tbdJSON = Data("""
        {
            "id": "888", "date": "2026-10-10T04:00Z",
            "status": {"type": {"state": "pre"}},
            "competitions": [{
                "timeValid": false,
                "competitors": [
                    {"homeAway": "home", "team": {"id": "25"}},
                    {"homeAway": "away", "team": {"id": "259"}}
                ]
            }]
        }
        """.utf8)
        let event = try JSONDecoder().decode(EventDTO.self, from: tbdJSON)
        let game = try #require(ESPNMapper.game(from: event))
        #expect(game.timeTBD)

        // Every kickoff in the fixture was announced (`timeValid: true`).
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("scoreboard-live"))
        #expect(ESPNMapper.scoreboard(from: dto).games.allSatisfy { !$0.timeTBD })
    }

    @Test func malformedEventIsDroppedNotFatal() throws {
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("scoreboard-malformed"))
        let scoreboard = ESPNMapper.scoreboard(from: dto)
        // One event was corrupted; it drops, the other 98 survive.
        #expect(scoreboard.games.count == 98)
    }

    @Test func emptyWeekDecodes() throws {
        let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture("scoreboard-empty"))
        let scoreboard = ESPNMapper.scoreboard(from: dto)
        #expect(scoreboard.games.isEmpty)
        #expect(scoreboard.weeks.count == 17)
    }

    @Test func unknownConferenceFallsBackToOther() {
        #expect(Conference.name(for: 9999) == "Other")
        #expect(Conference.name(for: nil) == "Other")
        #expect(Conference.tier(for: 9999) == .other)
        #expect(Conference.name(for: 8) == "SEC")
        #expect(Conference.tier(for: 8) == .power4)
    }
}

@Suite struct LivePhaseMappingTests {
    private func status(name: String?, clock: String? = "0:00", period: Int? = 2,
                        detail: String? = nil) -> GameStatus {
        ESPNMapper.status(
            from: StatusDTO(clock: nil, displayClock: clock, period: period,
                            type: StatusTypeDTO(id: nil, name: name, state: "in",
                                                completed: false, detail: detail,
                                                shortDetail: detail)),
            situation: nil)
    }

    @Test func halftimeStatusNameMapsToHalftimePhase() {
        // Observed live 2026-08-29: STATUS_HALFTIME arrives as state "in",
        // period 2, displayClock "0:00" — the name is the only signal.
        let mapped = status(name: "STATUS_HALFTIME", detail: "Halftime")
        if case .live(_, _, _, let phase, _) = mapped {
            #expect(phase == .halftime)
        } else {
            Issue.record("expected live status")
        }
        #expect(mapped.liveStatusText == "Half")
    }

    @Test func endOfPeriodStopsClaimingARunningClock() {
        let mapped = status(name: "STATUS_END_PERIOD", period: 1,
                            detail: "End of 1st Quarter")
        if case .live(_, _, _, let phase, _) = mapped {
            #expect(phase == .endOfPeriod)
        } else {
            Issue.record("expected live status")
        }
        #expect(mapped.liveStatusText == "End Q1")
    }

    @Test func inProgressKeepsQuarterAndClock() {
        let mapped = status(name: "STATUS_IN_PROGRESS", clock: "5:24", period: 3)
        #expect(mapped.liveStatusText == "Q3 5:24")
    }

    @Test func overtimePeriodsKeepTheirLabels() {
        #expect(status(name: "STATUS_IN_PROGRESS", clock: "0:48", period: 5)
            .liveStatusText == "OT 0:48")
        #expect(status(name: "STATUS_IN_PROGRESS", clock: "0:48", period: 6)
            .liveStatusText == "2OT 0:48")
    }

    @Test func bareLiveStatusFallsBackToDetailThenCaller() {
        // Nothing to render → detail; nothing at all → nil, and every
        // surface supplies its own "Live".
        #expect(status(name: nil, clock: nil, period: nil, detail: "In Progress")
            .liveStatusText == "In Progress")
        #expect(status(name: nil, clock: nil, period: nil).liveStatusText == nil)
        #expect(GameStatus.pre(detail: nil).liveStatusText == nil)
    }
}

@Suite struct ConferenceStandingsDecodingTests {
    private func standings() throws -> [ConferenceStandings] {
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self,
                                           from: fixture("standings-with-stats"))
        return ESPNMapper.conferenceStandings(from: dto)
    }

    @Test func decodesRecordsAndKeepsStandingsOrder() throws {
        let all = try standings()
        // Tier then name: Big Ten and SEC (power4) before Sun Belt (group5).
        #expect(all.map(\.name) == ["Big Ten", "SEC", "Sun Belt"])

        let sec = try #require(all.first { $0.id == 8 })
        // ESPN's order survives the mapper — alphabetizing would put
        // Alabama first.
        #expect(sec.entries.map(\.team.location) == ["Ole Miss", "Georgia", "Alabama"])

        let oleMiss = try #require(sec.entries.first)
        #expect(oleMiss.conferenceRecord == "7-1")
        #expect(oleMiss.overallRecord == "13-2")
        #expect(oleMiss.streak == "L1")
        #expect(oleMiss.team.conferenceId == 8)
    }

    @Test func missingStatsDegradeTheRowNotTheTable() throws {
        let sec = try #require(try standings().first { $0.id == 8 })
        // Alabama's entry has no stats array at all; the row stays, its
        // records read as absent.
        let alabama = try #require(sec.entries.first { $0.team.location == "Alabama" })
        #expect(alabama.conferenceRecord == nil)
        #expect(alabama.overallRecord == nil)
        #expect(alabama.streak == nil)
    }

    @Test func malformedEntriesDropRowsNotTheResponse() throws {
        let sec = try #require(try standings().first { $0.id == 8 })
        // The fixture has 5 SEC entries: a nil team and a corrupt stats
        // shape each cost one row, the other 3 survive.
        #expect(sec.entries.count == 3)
    }

    @Test func emptyConferenceIsKeptForTheStandingsPage() throws {
        // Offseason quirk (Sun Belt, 2026-07-20): zero entries. The browse
        // mapper drops it; the standings mapper must keep it so the page
        // can say "Standings TBA".
        let sunBelt = try #require(try standings().first { $0.id == 37 })
        #expect(sunBelt.entries.isEmpty)
    }
}

@Suite struct ConferenceListModelTests {
    private func conference(_ id: Int?, _ name: String,
                            entries: [ConferenceStanding] = []) -> ConferenceStandings {
        ConferenceStandings(id: id, name: name, entries: entries)
    }

    private func standing(_ location: String, conf: String?,
                          seed: Int? = nil) -> ConferenceStanding {
        ConferenceStanding(
            team: Team(id: location, location: location, name: nil, abbreviation: nil,
                       displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil),
            conferenceRecord: conf, overallRecord: nil, streak: nil, playoffSeed: seed)
    }

    @Test func seedOrderingBeatsPayloadOrderWhenComplete() {
        // 2024's payload listed by overall record — Memphis over 7-1 Tulane.
        let payload = [standing("Memphis", conf: "6-2", seed: 4),
                       standing("Army", conf: "8-0", seed: 1),
                       standing("Tulane", conf: "7-1", seed: 2)]
        #expect(ConferenceStandings.seedOrdered(payload).map(\.team.location)
                == ["Army", "Tulane", "Memphis"])
    }

    @Test func seedOrderingKeepsPayloadOrderOnGapsAndDupes() {
        // 2024 MAC ships zero seeds — payload order is imperfect but not
        // invented, so it stands.
        let zeros = [standing("Ohio", conf: "7-1", seed: 0),
                     standing("Buffalo", conf: "6-2", seed: 2),
                     standing("Miami (OH)", conf: "7-1", seed: 3)]
        #expect(ConferenceStandings.seedOrdered(zeros).map(\.team.location)
                == ["Ohio", "Buffalo", "Miami (OH)"])
        let dupes = [standing("A", conf: "5-3", seed: 1),
                     standing("B", conf: "5-3", seed: 1),
                     standing("C", conf: "4-4", seed: 3)]
        #expect(ConferenceStandings.seedOrdered(dupes).map(\.team.location)
                == ["A", "B", "C"])
        let missing = [standing("A", conf: "5-3", seed: 1),
                       standing("B", conf: "5-3", seed: nil),
                       standing("C", conf: "4-4", seed: 3)]
        #expect(ConferenceStandings.seedOrdered(missing).map(\.team.location)
                == ["A", "B", "C"])
    }

    @Test func titleGameCutGatesByFormatEra() {
        // One-table era: top two meet in the title game.
        #expect(Conference.titleGameIsTopTwo(id: 8, year: 2024))    // SEC
        #expect(Conference.titleGameIsTopTwo(id: 5, year: 2026))    // Big Ten
        // Divisional eras must never carry the top-two claim.
        #expect(!Conference.titleGameIsTopTwo(id: 8, year: 2023))
        // The Sun Belt is the divisional holdout — one-table from 2026.
        #expect(!Conference.titleGameIsTopTwo(id: 37, year: 2024))
        #expect(Conference.titleGameIsTopTwo(id: 37, year: 2026))
        // No title game at all: Independents, unknown ids, nil.
        #expect(!Conference.titleGameIsTopTwo(id: 18, year: 2026))
        #expect(!Conference.titleGameIsTopTwo(id: 999, year: 2026))
        #expect(!Conference.titleGameIsTopTwo(id: nil, year: 2026))
    }

    @Test func pinnedFloatsFollowedKeepingRelativeOrder() {
        let list = [conference(1, "ACC"), conference(5, "Big Ten"),
                    conference(8, "SEC"), conference(17, "Mountain West")]
        let pinned = ConferenceStandings.pinned(list, followedIds: [17, 5])
        // Followed keep their own relative order (Big Ten before Mountain
        // West), the rest keep theirs.
        #expect(pinned.map(\.name) == ["Big Ten", "Mountain West", "ACC", "SEC"])
    }

    @Test func pinnedWithNoFollowsIsIdentity() {
        let list = [conference(1, "ACC"), conference(nil, "Mystery")]
        #expect(ConferenceStandings.pinned(list, followedIds: []).map(\.name)
                == ["ACC", "Mystery"])
    }

    @Test func leaderRequiresARealRecord() {
        // Preseason: ESPN carries last season's order with 0-0 records —
        // that "leader" is not information.
        #expect(conference(8, "SEC", entries: [standing("Georgia", conf: "0-0")]).leader == nil)
        #expect(conference(8, "SEC", entries: [standing("Georgia", conf: nil)]).leader == nil)
        #expect(conference(8, "SEC").leader == nil)
        let leader = conference(8, "SEC", entries: [standing("Ole Miss", conf: "7-1"),
                                                    standing("Georgia", conf: "7-1")]).leader
        #expect(leader?.team.location == "Ole Miss")
    }
}

@Suite struct RankingsDecodingTests {
    @Test func decodesRankings() throws {
        let dto = try JSONDecoder().decode(RankingsResponseDTO.self, from: fixture("rankings-live"))
        let polls = ESPNMapper.polls(from: dto)

        let ap = try #require(polls.first(where: { $0.type == "ap" }))
        #expect(ap.ranks.count == 25)

        let top = try #require(ap.ranks.first)
        #expect(top.current == 1)
        #expect(top.team.id.isEmpty == false)
        #expect(top.movement == 0)
    }
}

@Suite struct WeekLogicTests {
    private let utc = TimeZone(identifier: "UTC")!

    private var calendar: Calendar {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = utc
        return cal
    }

    private func date(_ year: Int, _ month: Int, _ day: Int, _ hour: Int = 12) -> Date {
        DateComponents(calendar: calendar, timeZone: utc,
                       year: year, month: month, day: day, hour: hour).date!
    }

    // Mirrors the 2026 calendar: weeks run Tuesday 07:00Z → Monday 06:59Z.
    private var slots: [WeekSlot] {
        [
            WeekSlot(label: "Week 1", shortLabel: "Week 1", seasonType: 2, value: 1,
                     startDate: date(2026, 8, 22, 7), endDate: date(2026, 9, 8, 7)),
            WeekSlot(label: "Week 2", shortLabel: "Week 2", seasonType: 2, value: 2,
                     startDate: date(2026, 9, 8, 7), endDate: date(2026, 9, 14, 7)),
            WeekSlot(label: "Week 3", shortLabel: "Week 3", seasonType: 2, value: 3,
                     startDate: date(2026, 9, 14, 7), endDate: date(2026, 9, 21, 7)),
        ]
    }

    @Test func weekdayUsesESPNCurrentWeek() {
        // Wednesday Sep 9, 2026 — ESPN says week 2.
        let slot = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 2, seasonType: 2,
            today: date(2026, 9, 9), calendar: calendar)
        #expect(slot?.value == 2)
    }

    @Test func sundayPinsToCompletedWeek() {
        // Sunday Sep 13, 2026: Saturday's games were week 2. Even if ESPN
        // already claims week 3, Sunday shows week 2.
        let slot = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 3, seasonType: 2,
            today: date(2026, 9, 13), calendar: calendar)
        #expect(slot?.value == 2)
    }

    @Test func mondayFlipsForward() {
        // Monday Sep 14, 2026 midday: week 3 has begun.
        let slot = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 3, seasonType: 2,
            today: date(2026, 9, 14), calendar: calendar)
        #expect(slot?.value == 3)
    }

    @Test func preseasonFallsBackToFirstSlot() {
        let slot = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: nil, seasonType: nil,
            today: date(2026, 7, 20), calendar: calendar)
        #expect(slot?.value == 1)
    }

    // MARK: - Rollover edge cases (BACKLOG E5): the wide Week 1, the
    // Army-Navy-style solo week, and the overlapping postseason ranges.
    // Dates mirror the real 2026 calendar (scoreboard-live.json): Week 15
    // ends Dec 13 07:59Z, Bowls span Dec 13 → Jan 28, CFP Dec 18 → Jan 28
    // — Bowls and CFP overlap for the entire playoff.

    private var seasonEndSlots: [WeekSlot] {
        [
            WeekSlot(label: "Week 14", shortLabel: "Week 14", seasonType: 2, value: 14,
                     startDate: date(2026, 11, 30, 8), endDate: date(2026, 12, 7, 8)),
            WeekSlot(label: "Week 15", shortLabel: "Week 15", seasonType: 2, value: 15,
                     startDate: date(2026, 12, 7, 8), endDate: date(2026, 12, 13, 8)),
            WeekSlot(label: "Bowls", shortLabel: "Bowls", seasonType: 3, value: 1,
                     startDate: date(2026, 12, 13, 8), endDate: date(2027, 1, 28, 8)),
            WeekSlot(label: "CFP", shortLabel: "CFP", seasonType: 3, value: 999,
                     startDate: date(2026, 12, 18, 8), endDate: date(2027, 1, 28, 8)),
        ]
    }

    @Test func sundayDuringPlayoffPinsESPNsSlotNotFirstContaining() {
        // Sunday Jan 3, 2027, the morning after CFP quarterfinals. Both
        // Bowls and CFP contain yesterday; ESPN says CFP. Array order must
        // not decide — the first-containing rule alone would land on Bowls.
        let slot = WeekLogic.defaultSelection(
            in: seasonEndSlots, currentWeekNumber: 999, seasonType: 3,
            today: date(2027, 1, 3), calendar: calendar)
        #expect(slot?.value == 999)
        #expect(slot?.seasonType == 3)
    }

    @Test func sundayDuringBowlsHonorsESPNBowlsSlot() {
        // Sunday Dec 20, 2026 with ESPN still calling the slot Bowls:
        // follow ESPN through the ambiguity, not the CFP just because it
        // also contains yesterday.
        let slot = WeekLogic.defaultSelection(
            in: seasonEndSlots, currentWeekNumber: 1, seasonType: 3,
            today: date(2026, 12, 20), calendar: calendar)
        #expect(slot?.value == 1)
        #expect(slot?.seasonType == 3)
    }

    @Test func sundayStillPinsCompletedWeekWhenESPNFlippedForward() {
        // The September behavior the tie-break must preserve, at the season
        // boundary: Sunday Dec 13 (Bowls began 08:00Z that morning), ESPN
        // already flipped to Bowls, but Saturday's games — Army-Navy's
        // solo-week analog — were Week 15's. ESPN's slot doesn't contain
        // yesterday, so the completed week wins.
        let slot = WeekLogic.defaultSelection(
            in: seasonEndSlots, currentWeekNumber: 1, seasonType: 3,
            today: date(2026, 12, 13, 12), calendar: calendar)
        #expect(slot?.value == 15)
        #expect(slot?.seasonType == 2)
    }

    @Test func weekdayDuringPlayoffOverlapUsesESPNCurrent() {
        // Wednesday Dec 30, 2026: inside both Bowls' and CFP's ranges.
        // ESPN's (type, value) decides, whatever the array order.
        let slot = WeekLogic.defaultSelection(
            in: seasonEndSlots, currentWeekNumber: 999, seasonType: 3,
            today: date(2026, 12, 30), calendar: calendar)
        #expect(slot?.value == 999)
        #expect(slot?.seasonType == 3)
    }

    @Test func pastSeasonLandsOnTheCFPSlot() {
        // A finished season (no current week) lands on its conclusion —
        // slots.last must be the CFP because the mapper emits postseason
        // entries after regular-season ones.
        let slot = WeekLogic.defaultSelection(
            in: seasonEndSlots, currentWeekNumber: nil, seasonType: nil,
            today: date(2027, 6, 1), calendar: calendar)
        #expect(slot?.value == 999)
        #expect(slot?.seasonType == 3)
    }

    @Test func wideWeek1CoversItsMiddleSundayAndMonday() {
        // ESPN encodes Week 0 as a Week 1 spanning two weekends (Aug 22 →
        // Sep 8 in 2026). The mid-span Sunday pins to Week 1 via yesterday,
        // and the mid-span Monday stays on Week 1 via ESPN's current week —
        // no phantom flip between the two weekends.
        let sunday = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 1, seasonType: 2,
            today: date(2026, 8, 30), calendar: calendar)
        #expect(sunday?.value == 1)
        let monday = WeekLogic.defaultSelection(
            in: slots, currentWeekNumber: 1, seasonType: 2,
            today: date(2026, 8, 31), calendar: calendar)
        #expect(monday?.value == 1)
    }
}
