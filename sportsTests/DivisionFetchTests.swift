import Foundation
import Testing
@testable import StatSide

private func competitor(_ id: String, conference: Int?, isHome: Bool) -> Competitor {
    Competitor(
        team: Team(id: id, location: id, name: nil, abbreviation: nil,
                   displayName: nil, shortDisplayName: nil, logoURL: nil,
                   conferenceId: conference),
        score: nil, record: nil, rank: nil, isHome: isHome, winner: nil
    )
}

private func game(_ id: String, home: Int?, away: Int?) -> Game {
    Game(id: id, date: nil, name: nil, shortName: nil, weekNumber: 1,
         status: .pre(detail: nil),
         home: competitor("h-\(id)", conference: home, isHome: true),
         away: competitor("a-\(id)", conference: away, isHome: false),
         broadcast: nil)
}

private func board(_ games: [Game], weeks: [WeekSlot] = []) -> Scoreboard {
    Scoreboard(seasonYear: 2026, seasonType: 2, currentWeekNumber: 1,
               weeks: weeks, games: games)
}

private let slot = WeekSlot(label: "Week 1", shortLabel: "Wk 1", seasonType: 2,
                            value: 1, startDate: nil, endDate: nil)

/// E8's data layer. The overlap is real duplication at the source — every
/// FCS-at-FBS game ships in both group 80 and group 81 (37 of them in
/// Week 2 2026) — so the union has to dedupe by event id, and the FBS-only
/// path has to come out of the change untouched.
@Suite struct DivisionFetchTests {
    @Test func aMergedWeekContainsEachOverlappingEventExactlyOnce() {
        let shared = game("overlap", home: 8, away: 20)
        let merged = ESPNMapper.merged(
            board([game("fbs-only", home: 8, away: 1), shared]),
            with: [board([shared, game("fcs-only", home: 20, away: 21)])]
        )
        #expect(merged.games.map(\.id) == ["fbs-only", "overlap", "fcs-only"])
        #expect(merged.games.filter { $0.id == "overlap" }.count == 1)
    }

    @Test func theBaseDivisionsCopyOfAnOverlapWins() {
        // Both payloads describe the same event; the FBS copy is canonical
        // so the slate can't flicker between two renderings of one game.
        let fbs = game("overlap", home: 8, away: 20)
        let fcs = Game(id: "overlap", date: nil, name: "the group 81 rendering",
                       shortName: nil, weekNumber: 1, status: .pre(detail: nil),
                       home: fbs.home, away: fbs.away, broadcast: nil)
        let merged = ESPNMapper.merged(board([fbs]), with: [board([fcs])])
        #expect(merged.games.count == 1)
        #expect(merged.games[0].name == nil)
    }

    @Test func mergingNothingIsIdentity() {
        let base = board([game("a", home: 8, away: 1)], weeks: [slot])
        let merged = ESPNMapper.merged(base, with: [])
        #expect(merged.games.map(\.id) == ["a"])
        #expect(merged.weeks == base.weeks)
        #expect(merged.seasonYear == 2026)
    }

    /// ESPN serves group 81 the byte-identical calendar, so the base's
    /// weeks are simply kept. The fallback matters only if a base payload
    /// arrives calendar-less, which the offseason really does do.
    @Test func weekMetadataComesFromTheBaseWithAFallback() {
        let merged = ESPNMapper.merged(board([], weeks: []), with: [board([], weeks: [slot])])
        #expect(merged.weeks == [slot])

        let kept = ESPNMapper.merged(board([], weeks: [slot]), with: [board([], weeks: [])])
        #expect(kept.weeks == [slot])
    }

    @Test func divisionGroupIdsAreESPNsOwn() {
        #expect(Conference.Division.fbs.groupId == 80)
        #expect(Conference.Division.fcs.groupId == 81)
        #expect(Conference.Division.allCases.count == 2)
    }
}

/// Scope (b)'s actual promise: FCS costs a request only when someone asks
/// for it. This is the rule that keeps an ordinary Saturday at one poll.
@Suite struct DivisionOptInTests {
    @Test func theDefaultSlateIsFBSAlone() {
        #expect(ScoreboardStore.divisions(filter: nil, followedConferenceIds: []) == [.fbs])
        #expect(ScoreboardStore.divisions(filter: .top25, followedConferenceIds: []) == [.fbs])
        #expect(ScoreboardStore.divisions(filter: .conference(8),
                                          followedConferenceIds: [1, 17]) == [.fbs])
    }

    @Test func filteringToAnFCSConferenceOptsIn() {
        #expect(ScoreboardStore.divisions(filter: .conference(20),
                                          followedConferenceIds: []) == [.fbs, .fcs])
    }

    @Test func followingAnFCSConferenceOptsIn() {
        // Following has to work without a filter — a followed conference's
        // games appear in Following on every week, not just a filtered one.
        #expect(ScoreboardStore.divisions(filter: nil,
                                          followedConferenceIds: [21]) == [.fbs, .fcs])
        #expect(ScoreboardStore.divisions(filter: .top25,
                                          followedConferenceIds: [8, 179]) == [.fbs, .fcs])
    }

    @Test func fbsNeverLeavesTheSlate() {
        // Even filtered to one FCS conference: Following, Top 25 and the
        // conference sections are all still FBS-shaped underneath.
        let divisions = ScoreboardStore.divisions(filter: .conference(31),
                                                  followedConferenceIds: [31])
        #expect(divisions.contains(.fbs))
    }

    @Test func anUnknownConferenceIdDoesNotOptIn() {
        #expect(ScoreboardStore.divisions(filter: .conference(999),
                                          followedConferenceIds: [424_242]) == [.fbs])
    }
}
