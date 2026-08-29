import Foundation
import Testing
@testable import StatSide

// The Games tab's week grouping: regular weeks ascending, postseason
// last despite its restarted week numbers, chronology within a group.

private func team(_ id: String) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 1)
}

private func game(_ id: String, week: Int?, seasonType: Int? = nil,
                  daysFromEpoch: Int = 0, final: Bool = false) -> Game {
    Game(id: id, date: Date(timeIntervalSince1970: TimeInterval(daysFromEpoch) * 86_400),
         name: nil, shortName: nil, weekNumber: week, seasonType: seasonType,
         status: final ? .final(detail: "Final") : .pre(detail: nil),
         home: Competitor(team: team("h\(id)"), score: nil, record: nil,
                          rank: nil, isHome: true, winner: nil),
         away: Competitor(team: team("a\(id)"), score: nil, record: nil,
                          rank: nil, isHome: false, winner: nil),
         broadcast: nil)
}

@MainActor
@Suite struct ConferenceSlateTests {
    @Test func weeksOrderAscendingAndPostseasonTrailsDespiteWeekOne() {
        // The title game is week 1 of season type 3 — it must land in
        // "Postseason", never back in "Week 1".
        let groups = ConferenceSlate.groups(from: [
            game("title", week: 1, seasonType: 3, daysFromEpoch: 100),
            game("w2", week: 2, daysFromEpoch: 10),
            game("w1b", week: 1, daysFromEpoch: 4),
            game("w1a", week: 1, daysFromEpoch: 2),
        ])
        #expect(groups.map(\.id) == ["week-1", "week-2", "week-postseason"])
        #expect(groups[0].games.map(\.id) == ["w1a", "w1b"])
        #expect(groups[2].games.map(\.id) == ["title"])
    }

    @Test func nilWeekGamesBucketBeforePostseason() {
        let groups = ConferenceSlate.groups(from: [
            game("post", week: 1, seasonType: 3, daysFromEpoch: 100),
            game("known", week: 3, daysFromEpoch: 20),
            game("mystery", week: nil, daysFromEpoch: 50),
        ])
        #expect(groups.map(\.id) == ["week-3", "week-other", "week-postseason"])
    }

}
