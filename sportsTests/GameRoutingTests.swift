import Foundation
import Testing
@testable import StatSide

/// A widget row's tap, end to end: the link the widget writes, what the
/// app parses back out of it, and what the router hands the Scores screen.
///
/// The day is the whole subject. The widget lists games from yesterday to
/// a fortnight out while the Scores screen holds five days at a time, so a
/// link carrying an id alone can only open the handful of games that
/// happen to be in memory (Andy, 2026-09-07).
@Suite struct GameRoutingTests {

    private let day = DayFormat.date(fromId: "2026-09-13")!

    // MARK: - The grammar, both halves

    @Test func aGameLinkCarriesItsDayThroughTheRoundTrip() throws {
        let url = try #require(DeepLinkURL.game(id: "401", day: day))
        #expect(url.absoluteString == "statside://game/401?day=2026-09-13")
        #expect(DeepLink(url: url) == .game("401", day: day))
    }

    /// A kickoff nobody has scheduled yet still links — it just can't say
    /// where to look.
    @Test func aDaylessLinkRoundTripsToABareIntent() throws {
        let url = try #require(DeepLinkURL.game(id: "401"))
        #expect(url.absoluteString == "statside://game/401")
        #expect(DeepLink(url: url) == .game("401", day: nil))
    }

    /// The form every build before 2026-09-07 wrote, and the one a kickoff
    /// reminder still opens.
    @Test func aLegacyLinkStillParses() {
        #expect(DeepLink(url: URL(string: "statside://game/401")!) == .game("401", day: nil))
    }

    /// A day that isn't one degrades to no hint — the id still resolves
    /// against whatever the screen already holds.
    @Test func anUnreadableDayDegradesToNoHint() {
        #expect(DeepLink(url: URL(string: "statside://game/401?day=next-saturday")!)
                == .game("401", day: nil))
        #expect(DeepLink(url: URL(string: "statside://game/401?day=2026-09")!)
                == .game("401", day: nil))
    }

    @Test func theDayIdRoundTripsThroughItsOwnParser() {
        let noon = Calendar.current.date(byAdding: .hour, value: 12, to: day)!
        #expect(DayFormat.date(fromId: DayFormat.id(for: noon)) == day)
        #expect(DayFormat.date(fromId: "2026-13-45") == nil)
        #expect(DayFormat.date(fromId: "") == nil)
    }

    // MARK: - The router

    @MainActor
    @Test func theRouterCarriesTheDayThrough() {
        let router = Router()
        router.open(.game("401", day: day))
        #expect(router.pendingGame == GameRef(id: "401", day: day))
    }

    /// Search's intent comes from a game already in hand, so it knows the
    /// day for free — the same shape a widget tap arrives in.
    @MainActor
    @Test func anIntentBuiltFromAGameKnowsItsOwnDay() {
        let kickoff = Calendar.current.date(byAdding: .hour, value: 13, to: day)!
        let team = Team(id: "1", location: "Team 1", name: nil, abbreviation: nil,
                        displayName: nil, shortDisplayName: nil, logoURL: nil,
                        conferenceId: nil, league: .nfl)
        let game = Game(id: "401", date: kickoff, name: nil, shortName: nil,
                        weekNumber: 2, status: .pre(detail: nil),
                        home: Competitor(team: team, score: nil, record: nil, rank: nil,
                                         isHome: true, winner: nil),
                        away: Competitor(team: team, score: nil, record: nil, rank: nil,
                                         isHome: false, winner: nil),
                        broadcast: nil)
        #expect(GameRef(game).day == kickoff)
    }

    // MARK: - The destination's identity

    /// What every `navigationDestination(for: Game.self)` keys its `.id`
    /// on. A widget tap arriving while a detail page is already open
    /// *replaces* the value at that path position rather than pushing a
    /// second page, and a destination whose identity doesn't change is
    /// reused with all of its `@State` intact — which is how one game's
    /// logos, leaders and venue came to sit under another game's info card.
    @Test func twoGamesAreTwoDestinations() {
        #expect(game(id: "401", league: .collegeFootball).routeKey
                != game(id: "402", league: .collegeFootball).routeKey)
    }

    /// League-qualified for `FollowKey`'s reason: ESPN's ids collide across
    /// leagues, and an event id is no safer than a team id.
    @Test func theSameIdInTwoLeaguesIsTwoDestinations() {
        #expect(game(id: "401", league: .collegeFootball).routeKey
                != game(id: "401", league: .nfl).routeKey)
    }

    /// And the same game is the same destination however it was reached —
    /// a poll tick re-pushing its own game must not rebuild the page.
    @Test func theSameGameKeepsOneIdentity() {
        #expect(game(id: "401", league: .nhl).routeKey
                == game(id: "401", league: .nhl).routeKey)
    }

    private func game(id: String, league: League) -> Game {
        let team = Team(id: "1", location: "Team 1", name: nil, abbreviation: nil,
                        displayName: nil, shortDisplayName: nil, logoURL: nil,
                        conferenceId: nil, league: league)
        return Game(id: id, date: day, name: nil, shortName: nil,
                    weekNumber: nil, status: .pre(detail: nil),
                    home: Competitor(team: team, score: nil, record: nil, rank: nil,
                                     isHome: true, winner: nil),
                    away: Competitor(team: team, score: nil, record: nil, rank: nil,
                                     isHome: false, winner: nil),
                    broadcast: nil)
    }
}
