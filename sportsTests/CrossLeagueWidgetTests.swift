import Foundation
import Testing
@testable import StatSide

private func team(_ id: String, in league: League) -> Team {
    Team(id: id, location: "\(league.shortName) \(id)", name: nil,
         abbreviation: "T\(id)", displayName: nil, shortDisplayName: nil,
         logoURL: nil, conferenceId: nil, league: league)
}

private func game(_ id: String, in league: League, home: String, away: String,
                  status: GameStatus, date: Date?) -> Game {
    Game(id: id, date: date, name: nil, shortName: nil, weekNumber: 1, status: status,
         home: Competitor(team: team(home, in: league), score: nil, record: nil,
                          rank: nil, isHome: true, winner: nil),
         away: Competitor(team: team(away, in: league), score: nil, record: nil,
                          rank: nil, isHome: false, winner: nil),
         broadcast: nil)
}

/// What the widget and the Siri intent both ask for: "my games", regardless
/// of which sport they belong to.
@Suite struct CrossLeagueWidgetTests {
    /// 6pm on a fixed day, so every offset below lands where the assertion
    /// expects it in any time zone the tests run in — the selection rules
    /// read the local calendar.
    private let now = Calendar.current.date(
        bySettingHour: 18, minute: 0, second: 0,
        of: Date(timeIntervalSince1970: 1_760_000_000)
    ) ?? Date(timeIntervalSince1970: 1_760_000_000)

    /// The pick is chronological across leagues, so a Sunday NFL kickoff can
    /// outrank a college Saturday that has already finished.
    @Test func theWidgetPicksAcrossLeaguesByTime() {
        let games = [
            game("cfb-final", in: .collegeFootball, home: "130", away: "9",
                 status: .final(detail: "Final"), date: now.addingTimeInterval(-3 * 3600)),
            game("nfl-next", in: .nfl, home: "26", away: "25",
                 status: .pre(detail: nil), date: now.addingTimeInterval(3600)),
            game("cfb-next", in: .collegeFootball, home: "130", away: "8",
                 status: .pre(detail: nil), date: now.addingTimeInterval(2 * 3600)),
        ]
        let picked = GameSelection.relevantGames(
            in: games, followedKeys: ["cfb:130", "nfl:26"], limit: 4, now: now)

        #expect(picked.map(\.id) == ["nfl-next", "cfb-next", "cfb-final"])
    }

    /// The collision, at the surface that reaches the home screen: following
    /// UCLA (college id 26) must not put the Seahawks (NFL id 26) on it.
    @Test func aCollidingIdDoesNotReachTheWidget() {
        let games = [
            game("nfl", in: .nfl, home: "26", away: "25",
                 status: .pre(detail: nil), date: now.addingTimeInterval(3600)),
            game("cfb", in: .collegeFootball, home: "26", away: "9",
                 status: .pre(detail: nil), date: now.addingTimeInterval(2 * 3600)),
        ]
        #expect(GameSelection.relevantGames(in: games, followedKeys: ["cfb:26"],
                                            limit: 4, now: now).map(\.id) == ["cfb"])
        #expect(GameSelection.relevantGames(in: games, followedKeys: ["nfl:26"],
                                            limit: 4, now: now).map(\.id) == ["nfl"])
    }

    /// A game where a followed team is the *away* side counts too — the
    /// widget shouldn't only find home fixtures.
    @Test func eitherSideClaimsTheGame() {
        let away = game("away", in: .nfl, home: "25", away: "26",
                        status: .pre(detail: nil), date: now.addingTimeInterval(3600))
        #expect(GameSelection.relevantGames(in: [away], followedKeys: ["nfl:26"],
                                            limit: 4, now: now).map(\.id) == ["away"])
    }

    /// The politeness property the widget leans on: a follow set touching
    /// one league fans out to one request, not two. Doubling the leagues
    /// must not double everyone's request volume.
    @Test func fanOutCoversOnlyTheLeaguesFollowed() {
        let collegeOnly: Set<String> = ["cfb:130", "cfb:61"]
        #expect(collegeOnly.followedLeagues == [.collegeFootball])

        let nflOnly: Set<String> = ["nfl:26"]
        #expect(nflOnly.followedLeagues == [.nfl])

        let both: Set<String> = ["cfb:130", "nfl:26"]
        #expect(both.followedLeagues.count == 2)
    }
}
