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

/// An NFL game — the preseason cards are league-specific, since only the
/// NFL opens its preseason with a Hall of Fame Game.
private func nflGame(_ id: String, week: Int?, seasonType: Int?,
                     day: DateComponents, calendar: Calendar = .current) -> Game {
    var parts = day
    parts.hour = 12
    let side = Team(id: "2", location: "Buffalo", name: nil, abbreviation: nil,
                    displayName: nil, shortDisplayName: nil, logoURL: nil,
                    conferenceId: 4, league: .nfl)
    let other = Team(id: "17", location: "New England", name: nil, abbreviation: nil,
                     displayName: nil, shortDisplayName: nil, logoURL: nil,
                     conferenceId: 4, league: .nfl)
    return Game(id: id, date: calendar.date(from: parts), name: nil, shortName: nil,
                weekNumber: week, seasonType: seasonType, status: .pre(detail: nil),
                home: Competitor(team: side, score: nil, record: nil,
                                 rank: nil, isHome: true, winner: nil),
                away: Competitor(team: other, score: nil, record: nil,
                                 rank: nil, isHome: false, winner: nil),
                broadcast: nil)
}

/// The preseason's week numbers restart just like the postseason's, so a
/// Hall of Fame Game and an opening Thursday were sharing a card headed
/// "Week 1" (Andy, 2026-09-06).
@MainActor
@Suite struct PreseasonGroupingTests {
    private let slate = [
        nflGame("hof", week: 1, seasonType: 1,
                day: DateComponents(year: 2026, month: 7, day: 30)),
        nflGame("pre1", week: 2, seasonType: 1,
                day: DateComponents(year: 2026, month: 8, day: 8)),
        nflGame("pre3", week: 4, seasonType: 1,
                day: DateComponents(year: 2026, month: 8, day: 22)),
        nflGame("wk1", week: 1, seasonType: 2,
                day: DateComponents(year: 2026, month: 9, day: 10)),
        nflGame("sb", week: 5, seasonType: 3,
                day: DateComponents(year: 2027, month: 2, day: 14)),
    ]

    @Test func thePreseasonLeadsAndNeverSharesTheRegularSeasonsWeeks() {
        let groups = ConferenceSlate.groups(from: slate, by: .week)

        #expect(groups.map(\.id)
                == ["preseason-1", "preseason-2", "preseason-4", "week-1", "week-postseason"])
        #expect(groups.first { $0.id == "week-1" }?.games.map(\.id) == ["wk1"])
    }

    /// ESPN numbers the preseason from the Hall of Fame Game, so the cards
    /// read the way a fan says them: the opener by name, then weeks 1–3.
    @Test func preseasonCardsAreNamedTheWayFansCountThem() {
        let groups = ConferenceSlate.groups(from: slate, by: .week)

        #expect(Array(groups.map(\.title).prefix(3))
                == ["Hall of Fame Game", "Preseason Week 1", "Preseason Week 3"])
    }

    /// The grouping's ids stay a pure function of one game — the invariant
    /// the week cards have always kept.
    @Test func everyPreseasonCardIsTheOneWeekIdNames() {
        for group in ConferenceSlate.groups(from: slate, by: .week) {
            #expect(group.games.allSatisfy { ConferenceSlate.weekId(for: $0) == group.id })
        }
    }

    /// College football plays no Hall of Fame Game, so a preseason week
    /// there keeps its own number.
    @Test func anotherLeaguesPreseasonKeepsItsOwnNumbers() {
        #expect(ConferenceSlate.preseasonTitle(week: 1, league: .collegeFootball)
                == "Preseason Week 1")
        #expect(ConferenceSlate.preseasonTitle(week: nil, league: .nfl) == "Preseason")
    }

    /// Day grouping is untouched: a preseason game is a day like any other.
    @Test func dayGroupingIgnoresTheSeasonTypeEntirely() {
        let groups = ConferenceSlate.groups(from: slate, by: .day)

        #expect(groups.first?.games.map(\.id) == ["hof"])
        #expect(groups.count == 5)
    }
}

@MainActor
@Suite struct SlateFilterTests {

    /// A weekday and a date are enough while the year is obvious. On a
    /// past season it isn't — the whole point of the pane is that these
    /// games are not from now.
    @Test func aDateInAnotherYearSaysWhichYear() {
        let calendar = Calendar.current
        func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day)) ?? .now
        }
        let now = day(2026, 9, 9)

        let thisYear = ConferenceSlate.dayTitle(for: day(2026, 10, 2),
                                                calendar: calendar, now: now)
        #expect(!thisYear.contains("2026"))

        let lastYear = ConferenceSlate.dayTitle(for: day(2025, 10, 2),
                                                calendar: calendar, now: now)
        #expect(lastYear.contains("2025"))

        // A season that runs into the next year says so too, which is the
        // same question asked from the other side.
        let nextYear = ConferenceSlate.dayTitle(for: day(2027, 1, 12),
                                                calendar: calendar, now: now)
        #expect(nextYear.contains("2027"))
    }

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

/// Where a Games tab opens mid-season: the played cards folded behind one
/// row, so the first card on screen holds the next game (Andy, 2026-09-08).
@MainActor
@Suite struct SlateFoldTests {
    private let calendar = Calendar.current

    /// Noon on the given day — the same convention the grouping tests use,
    /// so a day token is stable in every time zone.
    private func day(_ month: Int, _ dayOfMonth: Int) -> DateComponents {
        DateComponents(year: 2026, month: month, day: dayOfMonth)
    }

    private func noon(_ month: Int, _ dayOfMonth: Int) -> Date {
        var parts = day(month, dayOfMonth)
        parts.hour = 12
        return calendar.date(from: parts)!
    }

    /// Weeks 1–3 played, week 4 to come: the fold splits at week 4 and the
    /// three behind it come back in one piece, in order.
    @Test func theFoldSplitsAtTheFirstCardWithFootballLeftInIt() {
        let slate = (1...5).map { week in
            game("w\(week)", week: week, day: day(9, 5 + (week - 1) * 7))
        }
        let fold = ConferenceSlate.fold(ConferenceSlate.groups(from: slate, by: .week),
                                        now: noon(9, 26), calendar: calendar)
        #expect(fold.earlier.map(\.id) == ["week-1", "week-2", "week-3"])
        #expect(fold.upcoming.map(\.id) == ["week-4", "week-5"])
    }

    /// A season with nothing left folds nothing: every past season, and
    /// this one once the last whistle blows. There is no next game to open
    /// on, and hiding the whole slate answers a question nobody asked.
    @Test func aFinishedSeasonFoldsNothing() {
        let slate = (1...3).map { week in
            game("w\(week)", week: week, day: day(9, 5 + (week - 1) * 7))
        }
        let fold = ConferenceSlate.fold(ConferenceSlate.groups(from: slate, by: .week),
                                        now: noon(12, 25), calendar: calendar)
        #expect(fold.earlier.isEmpty)
        #expect(fold.upcoming.count == 3)
    }

    /// Nothing played yet — preseason, and the whole app in July.
    @Test func aSeasonThatHasntStartedFoldsNothing() {
        let slate = (1...3).map { week in
            game("w\(week)", week: week, day: day(9, 5 + (week - 1) * 7))
        }
        let fold = ConferenceSlate.fold(ConferenceSlate.groups(from: slate, by: .week),
                                        now: noon(8, 1), calendar: calendar)
        #expect(fold.earlier.isEmpty)
        #expect(fold.upcoming.map(\.id) == ["week-1", "week-2", "week-3"])
    }

    /// The day's own card stays out of the fold all day, whatever the
    /// clock says — `GameSelection.isSpent`'s rule, which is what keeps a
    /// Saturday's results in place through Saturday night.
    @Test func todaysCardIsNeverFoldedAway() {
        let slate = [game("w1", week: 1, day: day(9, 5)),
                     game("w2", week: 2, day: day(9, 12))]
        let groups = ConferenceSlate.groups(from: slate, by: .week)
        // 11pm on week 2's own Saturday: every kickoff is hours gone.
        var lateNight = day(9, 12)
        lateNight.hour = 23
        let fold = ConferenceSlate.fold(groups, now: calendar.date(from: lateNight)!,
                                        calendar: calendar)
        #expect(fold.earlier.map(\.id) == ["week-1"])
        #expect(fold.upcoming.map(\.id) == ["week-2"])
    }

    /// The fold is a prefix, never a scan: a spent card *behind* a live one
    /// stays where the calendar put it. Rearranging a season is the one
    /// thing this must never do.
    @Test func theFoldOnlyEverTakesAPrefix() {
        // Week 1 played, week 2 postponed into October, week 3 played.
        let slate = [game("w1", week: 1, day: day(9, 5)),
                     game("w2", week: 2, day: day(10, 31)),
                     game("w3", week: 3, day: day(9, 19))]
        let fold = ConferenceSlate.fold(ConferenceSlate.groups(from: slate, by: .week),
                                        now: noon(9, 26), calendar: calendar)
        #expect(fold.earlier.map(\.id) == ["week-1"])
        #expect(fold.upcoming.map(\.id) == ["week-2", "week-3"])
    }

    /// A card ESPN never dated — a TBD bowl slot — can't fold away on a
    /// guess, so it stops the fold where it stands.
    @Test func anUndatedCardIsNeverSpent() {
        let slate = [game("w1", week: 1, day: day(9, 5)),
                     game("tbd", week: nil, seasonType: 3, dated: false)]
        let fold = ConferenceSlate.fold(ConferenceSlate.groups(from: slate, by: .week),
                                        now: noon(12, 25), calendar: calendar)
        #expect(fold.earlier.map(\.id) == ["week-1"])
        #expect(fold.upcoming.map(\.id) == ["week-postseason"])
    }

    /// Days fold exactly as weeks do — the split reads cards, not clocks.
    @Test func dayGroupingFoldsTheSameWay() {
        let slate = [game("a", week: 1, day: day(9, 5)),
                     game("b", week: 2, day: day(9, 12)),
                     game("c", week: 3, day: day(9, 19))]
        let fold = ConferenceSlate.fold(ConferenceSlate.groups(from: slate, by: .day),
                                        now: noon(9, 12), calendar: calendar)
        #expect(fold.earlier.count == 1)
        #expect(fold.upcoming.count == 2)
    }

    /// Both toggles off is one card holding the whole season, and a card
    /// with the season's future in it is never spent — so the ungrouped
    /// view folds nothing, which is the only honest answer for it.
    @Test func theUngroupedCardNeverFolds() {
        let slate = [game("w1", week: 1, day: day(9, 5)),
                     game("w2", week: 2, day: day(9, 12))]
        let fold = ConferenceSlate.fold(ConferenceSlate.groups(from: slate, by: .none),
                                        now: noon(9, 8), calendar: calendar)
        #expect(fold.earlier.isEmpty)
        #expect(fold.upcoming.count == 1)
    }
}
