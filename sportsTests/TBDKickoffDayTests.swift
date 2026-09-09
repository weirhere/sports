import Foundation
import Testing
@testable import StatSide

/// The 2026-09-08 field report: games Andy (Eastern) saw on Saturday showed
/// under **Friday** for a tester in Central.
///
/// ESPN parks an unannounced kickoff at midnight *Eastern* of the game's own
/// day — a sentinel, not an instant — and the app buckets games by the
/// reader's local calendar day. Midnight ET is the previous calendar day in
/// Central, Mountain, Pacific, Alaska and Hawaii, so every TBD game filed a
/// day early for four of the six US zones.
///
/// Verified live that day against `groups=80&dates=20260924-20260928`: 41 of
/// 71 events carried the identical instant `2026-09-26T04:00Z`, including
/// both games in the report (SC @ ALA `401856696`, JMU @ ODU `401869961`).
/// The 30 games with announced kickoffs were unaffected — none of them
/// differ between the Eastern and Central calendar day.
///
/// Why the existing suites can't catch this: `ScoreboardStoreTests` and
/// `LeagueScoreboardsTests` both anchor their fixtures at noon local
/// *specifically so games never drift between buckets*, which is the one
/// case that is immune.
@Suite struct TBDKickoffDayTests {

    /// The sentinel from the field report, and the day it actually names.
    private static let sentinel = Date(timeIntervalSince1970: 1_790_395_200) // 2026-09-26T04:00Z
    private static let realDay = (year: 2026, month: 9, day: 26)

    private func calendar(_ identifier: String) throws -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try #require(TimeZone(identifier: identifier))
        return calendar
    }

    // MARK: - The rule itself

    /// Every US zone reads the sentinel as the same day, and gets that day's
    /// own local midnight back. Explicit calendars, because this is the only
    /// layer that can be tested independently of wherever the tests run.
    @Test(arguments: [
        "America/New_York",   // unaffected — this is the zone the bug hid in
        "America/Chicago",    // the field report
        "America/Denver",
        "America/Los_Angeles",
        "Pacific/Honolulu",   // the widest offset, and no DST
    ])
    func placeholderKickoffLandsOnTheEasternDay(zone: String) throws {
        let calendar = try calendar(zone)
        let anchored = DayFormat.placeholderKickoff(Self.sentinel, calendar: calendar)

        let parts = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: anchored)
        #expect(parts.year == Self.realDay.year)
        #expect(parts.month == Self.realDay.month)
        #expect(parts.day == Self.realDay.day)
        // Midnight, not noon: a TBD game keeps sorting first within its day.
        #expect(parts.hour == 0)
        #expect(parts.minute == 0)

        #expect(DayFormat.id(for: anchored, calendar: calendar) == "2026-09-26")
    }

    /// Without the re-anchoring, four of these five zones read the sentinel
    /// as the 25th. This is the bug, pinned — if it ever stops being true,
    /// ESPN changed the sentinel and the rule needs revisiting.
    @Test func rawSentinelIsADayEarlyWestOfEastern() throws {
        #expect(DayFormat.id(for: Self.sentinel,
                             calendar: try calendar("America/New_York")) == "2026-09-26")
        for zone in ["America/Chicago", "America/Denver",
                     "America/Los_Angeles", "Pacific/Honolulu"] {
            #expect(DayFormat.id(for: Self.sentinel, calendar: try calendar(zone)) == "2026-09-25",
                    "\(zone) should read the raw sentinel as the previous day")
        }
    }

    // MARK: - The mapper boundary

    /// The scoreboard path — the one that produced the field report.
    @Test func scoreboardTBDKickoffIsAnchoredToItsLocalDay() throws {
        let event = try JSONDecoder().decode(EventDTO.self, from: Self.scoreboardJSON)
        let game = try #require(ESPNMapper.game(from: event))
        #expect(game.timeTBD)
        try expectAnchored(game)
    }

    /// The team-schedule path carries the same placeholder and needs the
    /// same treatment — a team page's schedule rows read their own day.
    @Test func teamScheduleTBDKickoffIsAnchoredToItsLocalDay() throws {
        let event = try JSONDecoder().decode(ScheduleEventDTO.self, from: Self.scheduleJSON)
        let game = try #require(ESPNMapper.game(from: event))
        #expect(game.timeTBD)
        try expectAnchored(game)
    }

    /// An announced kickoff is a real instant and must survive untouched —
    /// the fix is for the sentinel, and nothing else.
    @Test func announcedKickoffIsLeftAlone() throws {
        let json = Data("""
        {
            "id": "401856704", "date": "2026-09-26T16:00Z",
            "status": {"type": {"state": "pre"}},
            "competitions": [{
                "timeValid": true,
                "competitors": [
                    {"homeAway": "home", "team": {"id": "2633"}},
                    {"homeAway": "away", "team": {"id": "251"}}
                ]
            }]
        }
        """.utf8)
        let event = try JSONDecoder().decode(EventDTO.self, from: json)
        let game = try #require(ESPNMapper.game(from: event))
        #expect(!game.timeTBD)
        // Noon ET on the 26th, to the second.
        #expect(game.date == Date(timeIntervalSince1970: 1_790_438_400))
    }

    // MARK: -

    /// The mapper's half of the contract: whatever the ambient zone, a TBD
    /// kickoff comes out of the mapper having been through the rule above.
    ///
    /// **These two are blind on an Eastern machine** — there, midnight ET
    /// *is* local midnight, so the anchored and unanchored values are the
    /// same instant and nothing here can tell them apart. That is exactly
    /// how the bug survived to ship. `placeholderKickoffLandsOnTheEasternDay`
    /// is the guard that holds everywhere; this pair pins the wiring, and
    /// bites on any machine west of Eastern.
    private func expectAnchored(_ game: Game) throws {
        let date = try #require(game.date)
        #expect(date == DayFormat.placeholderKickoff(Self.sentinel))
        #expect(DayFormat.id(for: date) == "2026-09-26")
        #expect(Calendar.current.startOfDay(for: date) == date,
                "a placeholder kickoff should be anchored to local midnight")
    }

    private static let scoreboardJSON = Data("""
    {
        "id": "401856696", "date": "2026-09-26T04:00Z",
        "status": {"type": {"state": "pre"}},
        "competitions": [{
            "timeValid": false,
            "competitors": [
                {"homeAway": "home", "team": {"id": "333"}},
                {"homeAway": "away", "team": {"id": "2579"}}
            ]
        }]
    }
    """.utf8)

    private static let scheduleJSON = Data("""
    {
        "id": "401869961", "date": "2026-09-26T04:00Z",
        "competitions": [{
            "timeValid": false,
            "status": {"type": {"state": "pre"}},
            "competitors": [
                {"homeAway": "home", "team": {"id": "295"}},
                {"homeAway": "away", "team": {"id": "256"}}
            ]
        }]
    }
    """.utf8)
}
