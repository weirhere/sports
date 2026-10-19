import Foundation
import Testing
@testable import StatSide

private func team(_ id: String, league: League = .collegeFootball) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil, league: league)
}

private let georgia = team("61")
private let alabama = team("333")
private let now = Date(timeIntervalSince1970: 1_792_000_000)

private let liveQ3 = GameStatus.live(displayClock: "5:24", period: 3, detail: nil,
                                     phase: .playing, possessionTeamId: georgia.id)

private func game(status: GameStatus, date: Date? = now,
                  homeScore: Int? = 17, awayScore: Int? = 24,
                  homeRecord: String? = "6-1", awayRecord: String? = "7-0",
                  homeWinner: Bool? = nil, awayWinner: Bool? = nil) -> Game {
    var game = Game(id: "401", date: date, name: nil, shortName: "UGA @ ALA", weekNumber: 8,
                    headline: "Rose Bowl", status: status,
                    home: Competitor(team: alabama, score: homeScore, record: homeRecord, rank: 4,
                                     isHome: true, winner: homeWinner),
                    away: Competitor(team: georgia, score: awayScore, record: awayRecord, rank: 1,
                                     isHome: false, winner: awayWinner),
                    broadcast: "CBS")
    game.line = GameLine(details: "UGA -7.5", overUnder: 51.5, favoriteIsHome: false)
    game.venue = "Bryant-Denny Stadium"
    game.broadcasts = [GameBroadcast(kind: "TV", network: "CBS", isNational: true,
                                     logoURL: nil, darkLogoURL: nil)]
    return game
}

private func guardFollowing(_ teams: Team..., revealed: Set<String> = []) -> SpoilerGuard {
    SpoilerGuard(isEnabled: true, followedKeys: Set(teams.map(\.followKey)), revealedKeys: revealed)
}

/// Which games spoiler mode hides (E30): followed teams only, live
/// always, finals for a week, never a revealed game — and what a hidden
/// game is stripped down to.
@Suite struct SpoilerGuardTests {
    @Test func offConcealsNothing() {
        #expect(!SpoilerGuard.off.conceals(game(status: liveQ3), now: now))
    }

    @Test func anUnfollowedGameShowsItsScore() {
        let guardValue = guardFollowing(team("2633"))
        #expect(!guardValue.conceals(game(status: liveQ3), now: now))
    }

    @Test func aFollowedLiveGameIsConcealedFromEitherSide() {
        #expect(guardFollowing(georgia).conceals(game(status: liveQ3), now: now))
        #expect(guardFollowing(alabama).conceals(game(status: liveQ3), now: now))
    }

    @Test func aFollowedFinalIsConcealedForAWeek() {
        let guardValue = guardFollowing(georgia)
        let yesterday = now.addingTimeInterval(-86_400)
        #expect(guardValue.conceals(game(status: .final(detail: "Final"), date: yesterday), now: now))
        let justInside = now.addingTimeInterval(-SpoilerGuard.finalWindow + 1)
        #expect(guardValue.conceals(game(status: .final(detail: "Final"), date: justInside), now: now))
        let justOutside = now.addingTimeInterval(-SpoilerGuard.finalWindow - 1)
        #expect(!guardValue.conceals(game(status: .final(detail: "Final"), date: justOutside), now: now))
    }

    @Test func aFinalWithNoDateStaysConcealed() {
        #expect(guardFollowing(georgia).conceals(game(status: .final(detail: "Final"), date: nil), now: now))
    }

    @Test func aRevealedGameShowsItsScore() {
        let played = game(status: .final(detail: "Final"))
        let guardValue = guardFollowing(georgia, revealed: [played.routeKey])
        #expect(!guardValue.conceals(played, now: now))
        // The key is league-qualified: a bare id would reveal two games.
        #expect(guardFollowing(georgia, revealed: [played.id]).conceals(played, now: now))
    }

    @Test func preGameAndPostponedNeverConceal() {
        let guardValue = guardFollowing(georgia)
        #expect(!guardValue.conceals(game(status: .pre(detail: nil)), now: now))
        #expect(!guardValue.conceals(game(status: .other(detail: "Postponed")), now: now))
    }

    // MARK: - Game.concealed()

    @Test func aConcealedFinalKeepsNoResult() {
        let hidden = game(status: .final(detail: "Final/OT"),
                          homeWinner: false, awayWinner: true).concealed()
        guard case .final(let detail) = hidden.status else {
            Issue.record("a final stays a final")
            return
        }
        #expect(detail == nil, "\"OT\" is part of the result")
        #expect(hidden.home.score == nil && hidden.away.score == nil)
        #expect(hidden.home.winner == nil && hidden.away.winner == nil)
        #expect(hidden.line == nil, "who was favored is half the result")
    }

    @Test func aConcealedLiveGameSaysOnlyThatItIsLive() {
        let hidden = game(status: liveQ3).concealed()
        guard case .live(let clock, let period, let detail, let phase, let possession) = hidden.status else {
            Issue.record("a live game stays live")
            return
        }
        #expect(clock == nil && period == nil && detail == nil && possession == nil)
        #expect(phase == .playing)
        #expect(hidden.status.liveStatusText(in: .collegeFootball) == nil,
                "callers fall back to the word Live")
        #expect(hidden.isLive)
        #expect(hidden.home.score == nil && hidden.away.score == nil)
    }

    @Test func aConcealedFinalRewindsBothRecords() {
        let hidden = game(status: .final(detail: "Final"),
                          homeRecord: "6-2", awayRecord: "8-0",
                          homeWinner: false, awayWinner: true).concealed()
        #expect(hidden.away.record == "7-0")
        #expect(hidden.home.record == "6-1")
    }

    @Test func aConcealedLiveGameKeepsItsPreGameRecords() {
        let hidden = game(status: liveQ3).concealed()
        #expect(hidden.away.record == "7-0")
        #expect(hidden.home.record == "6-1")
    }

    @Test func concealingKeepsEverythingThatIsNotTheResult() {
        let original = game(status: .final(detail: "Final"), homeWinner: false, awayWinner: true)
        let hidden = original.concealed()
        #expect(hidden.id == original.id)
        #expect(hidden.routeKey == original.routeKey)
        #expect(hidden.date == original.date)
        #expect(hidden.headline == "Rose Bowl", "the bowl's name is not its result")
        #expect(hidden.broadcast == "CBS")
        #expect(hidden.broadcasts == original.broadcasts)
        #expect(hidden.venue == "Bryant-Denny Stadium")
        #expect(hidden.home.rank == 4 && hidden.away.rank == 1)
        #expect(hidden.home.team == original.home.team)
    }

    @Test func aPreGameCopyIsUnchanged() {
        let upcoming = game(status: .pre(detail: nil), homeScore: nil, awayScore: nil)
        #expect(upcoming.concealed() == upcoming)
    }
}
