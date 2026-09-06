import Foundation
import Testing
@testable import StatSide

// The Games tab's grouping toggles (Weeks / Date) and its team filter.

private func team(_ id: String) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 1)
}

/// A game at noon local on a fixed day, so day tokens are stable wherever
/// the test runs — noon avoids every time-zone edge.
private func game(_ id: String, week: Int?, seasonType: Int? = nil,
                  home: String = "h", away: String = "a",
                  day: DateComponents? = nil, dated: Bool = true,
                  calendar: Calendar = .current) -> Game {
    var parts = day ?? DateComponents(year: 2026, month: 9, day: 5)
    parts.hour = 12
    return Game(id: id, date: dated ? calendar.date(from: parts) : nil,
                name: nil, shortName: nil, weekNumber: week, seasonType: seasonType,
                status: .pre(detail: nil),
                home: Competitor(team: team(home), score: nil, record: nil,
                                 rank: nil, isHome: true, winner: nil),
                away: Competitor(team: team(away), score: nil, record: nil,
                                 rank: nil, isHome: false, winner: nil),
                broadcast: nil)
}

@MainActor
@Suite struct SlateFilterTests {
    private let slate = [
        game("sat1", week: 1, home: "ohio", away: "texas"),
        game("sat2", week: 1, home: "duke", away: "army"),
        game("fri", week: 1, day: DateComponents(year: 2026, month: 9, day: 4)),
        game("w2", week: 2, day: DateComponents(year: 2026, month: 9, day: 12)),
        game("title", week: 1, seasonType: 3,
             day: DateComponents(year: 2027, month: 1, day: 11)),
    ]

    /// Every card the week grouping makes is a week `weekId` names, and
    /// the postseason never lands back in Week 1 despite its restarted
    /// week numbers.
    @Test func weekGroupingHeadsEveryCardItMakes() {
        let groups = ConferenceSlate.groups(from: slate, by: .week)
        #expect(groups.map(\.id) == ["week-1", "week-2", "week-postseason"])
        for group in groups {
            #expect(group.games.allSatisfy { ConferenceSlate.weekId(for: $0) == group.id })
        }
    }

    @Test func dayGroupingIsOneCardPerDayInOrder() {
        let groups = ConferenceSlate.groups(from: slate, by: .day)
        #expect(groups.map(\.id)
                == ["day-2026-09-04", "day-2026-09-05", "day-2026-09-12", "day-2027-01-11"])
        #expect(groups[1].games.map(\.id) == ["sat1", "sat2"])
        // "Saturday, September 5" — the exact wording is the locale's, so
        // this asserts the parts rather than a string.
        #expect(groups[1].title.contains("5"))
    }

    /// An undated bowl slot gets a bucket of its own at the end, never a
    /// day it isn't on.
    @Test func undatedGamesGetTheirOwnDayBucketLast() {
        let groups = ConferenceSlate.groups(
            from: slate + [game("tbd", week: nil, seasonType: 3, dated: false)], by: .day)
        #expect(groups.last?.id == "day-tbd")
        #expect(groups.last?.games.map(\.id) == ["tbd"])
    }

    /// Both toggles off: one chronological card, and no heading, because
    /// nothing is being grouped.
    @Test func noGroupingIsOneUnheadedChronologicalCard() {
        let groups = ConferenceSlate.groups(from: slate, by: .none)
        #expect(groups.count == 1)
        #expect(groups[0].title.isEmpty)
        #expect(groups[0].games.map(\.id) == ["fri", "sat1", "sat2", "w2", "title"])
        #expect(ConferenceSlate.groups(from: [], by: .none).isEmpty)
    }

    @Test func theTeamFilterIsTheOnlyNarrowingOne() {
        let mine = ConferenceSlate.games(slate, forTeamId: "ohio")
        #expect(mine.map(\.id) == ["sat1"])
        // Grouping still applies to the narrowed slate.
        #expect(ConferenceSlate.groups(from: mine, by: .week).map(\.id) == ["week-1"])
        // A nil selection is the absence of a filter, not a value.
        #expect(ConferenceSlate.games(slate, forTeamId: nil).count == slate.count)
    }
}
