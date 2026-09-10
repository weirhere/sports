import Foundation
import Testing
@testable import StatSide

#if canImport(ActivityKit)

private func competitor(_ id: String, abbrev: String?, score: Int?,
                        record: String? = nil, isHome: Bool) -> Competitor {
    Competitor(
        team: Team(id: id, location: id, name: nil, abbreviation: abbrev,
                   displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil),
        score: score, record: record, rank: nil, isHome: isHome, winner: nil
    )
}

private func game(status: GameStatus,
                  date: Date? = nil,
                  timeTBD: Bool = false,
                  broadcast: String? = nil,
                  awayScore: Int? = 7,
                  homeScore: Int? = 24) -> Game {
    Game(id: "g", date: date, timeTBD: timeTBD, name: nil, shortName: nil,
         weekNumber: 1, status: status,
         home: competitor("uga", abbrev: "UGA", score: homeScore, record: "3-0", isHome: true),
         away: competitor("tnst", abbrev: "TNST", score: awayScore, record: "1-1", isHome: false),
         broadcast: broadcast)
}

private let playing = GameStatus.live(displayClock: "5:24", period: 3, detail: nil,
                                      phase: .playing, possessionTeamId: "uga")
private let halftime = GameStatus.live(displayClock: "0:00", period: 2, detail: nil,
                                       phase: .halftime, possessionTeamId: nil)

/// The Live Activity's content derivation. The load-bearing property is
/// that this never formats a clock of its own — every headline during play
/// must come back through `GameStatus.liveStatusText(in:)`, which is what
/// stops this becoming the sixth surface to render "Q2 0:00" at halftime.
@Suite struct LiveActivityContentTests {

    // MARK: - Phase

    @Test func phaseMapsEachStatus() {
        #expect(LiveActivityContent.phase(for: .pre(detail: nil)) == .pre)
        #expect(LiveActivityContent.phase(for: playing) == .live)
        #expect(LiveActivityContent.phase(for: halftime) == .intermission)
        #expect(LiveActivityContent.phase(for: .final(detail: nil)) == .final)
    }

    /// Postponed and canceled fold into `.final` rather than growing a
    /// fifth case: the card's job in all of them is to stop claiming a
    /// clock is running.
    @Test func otherFoldsIntoFinal() {
        #expect(LiveActivityContent.phase(for: .other(detail: "Postponed")) == .final)
        let state = LiveActivityContent.state(for: game(status: .other(detail: "Postponed")))
        #expect(state.headline == "Postponed")
    }

    // MARK: - Scores

    @Test func preGameShowsNoScoresAtAll() {
        let state = LiveActivityContent.state(
            for: game(status: .pre(detail: nil), date: .now, awayScore: 0, homeScore: 0))
        #expect(state.showsScores == false)
        #expect(state.awayScore == nil)
        #expect(state.homeScore == nil)
    }

    @Test func liveCarriesBothScores() {
        let state = LiveActivityContent.state(for: game(status: playing))
        #expect(state.showsScores)
        #expect(state.awayScore == 7)
        #expect(state.homeScore == 24)
    }

    // MARK: - Headline

    @Test func halftimeNeverRendersAParkedClock() {
        let state = LiveActivityContent.state(for: game(status: halftime))
        #expect(state.headline == "Half")
        #expect(state.headline != "Q2 0:00")
    }

    @Test func livePeriodComesFromTheSharedFormatter() {
        let state = LiveActivityContent.state(for: game(status: playing))
        #expect(state.headline == "Q3 5:24")
    }

    @Test func unannouncedKickoffSaysTBDRatherThanMidnight() {
        let midnight = Calendar.current.startOfDay(for: .now)
        let state = LiveActivityContent.state(
            for: game(status: .pre(detail: nil), date: midnight, timeTBD: true))
        #expect(state.headline == "TBD")
    }

    // MARK: - Detail line

    @Test func preGameDetailIsTheNetwork() {
        let state = LiveActivityContent.state(
            for: game(status: .pre(detail: nil), date: .now, broadcast: "SECN"))
        #expect(state.detail == "SECN")
    }

    /// A break has no live situation, and a final has nothing left to tune
    /// into — the widget's own rule, one surface further out.
    @Test func intermissionAndFinalCarryNoDetail() {
        #expect(LiveActivityContent.state(for: game(status: halftime, broadcast: "SECN")).detail == nil)
        #expect(LiveActivityContent.state(for: game(status: .final(detail: nil), broadcast: "SECN")).detail == nil)
    }

    /// Basketball and hockey get no second line — not by a league check but
    /// because `GameSummary.situation` is derived from `drives.current`,
    /// which ESPN ships for football alone. The don't holds by construction.
    @Test func noSituationWithoutDrives() {
        #expect(LiveActivityContent.situationLine(game(status: playing), nil) == nil)
    }

    // MARK: - Attributes

    @Test func attributesCarryIdentityAndRecords() {
        let attributes = LiveActivityContent.attributes(for: game(status: playing))
        #expect(attributes.gameId == "g")
        #expect(attributes.away.abbreviation == "TNST")
        #expect(attributes.home.abbreviation == "UGA")
        #expect(attributes.away.record == "1-1")
        #expect(attributes.leagueToken == League.collegeFootball.rawValue)
    }

    /// An FCS visitor ESPN gives no abbreviation to still names itself,
    /// rather than rendering an empty column.
    @Test func abbreviationFallsBackToLocation() {
        let g = Game(id: "g", date: nil, name: nil, shortName: nil, weekNumber: 1,
                     status: playing,
                     home: competitor("uga", abbrev: "UGA", score: 24, isHome: true),
                     away: competitor("Tennessee State", abbrev: nil, score: 7, isHome: false),
                     broadcast: nil)
        #expect(LiveActivityContent.attributes(for: g).away.abbreviation == "Tennessee State")
    }

    @Test func phaseKnowsWhichStatesAreLive() {
        #expect(GameActivityAttributes.Phase.live.isLive)
        #expect(GameActivityAttributes.Phase.intermission.isLive)
        #expect(GameActivityAttributes.Phase.pre.isLive == false)
        #expect(GameActivityAttributes.Phase.final.isLive == false)
    }

    // MARK: - What the pin button is offered for

    @Test func offersPreGameAndLive() {
        #expect(LiveActivityController.isStartable(game(status: .pre(detail: nil), date: .now)))
        #expect(LiveActivityController.isStartable(game(status: playing, date: .now)))
        #expect(LiveActivityController.isStartable(game(status: halftime, date: .now)))
    }

    /// A finished game gets no card. Its whole job is the part of the day
    /// the game is still happening; starting one on a final would put a
    /// dead result on the lock screen with nothing left to say.
    @Test func refusesAFinishedGame() {
        #expect(LiveActivityController.isStartable(
            game(status: .final(detail: "Final"), date: .now)) == false)
        #expect(LiveActivityController.isStartable(
            game(status: .other(detail: "Postponed"), date: .now)) == false)
    }

    /// Yesterday's kickoff that ESPN never flipped off `pre` is spent —
    /// the widget's rule, reused rather than reinvented, so the two
    /// surfaces can't disagree about when a fixture stops being today's.
    @Test func refusesASpentGame() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        #expect(LiveActivityController.isStartable(
            game(status: .pre(detail: nil), date: yesterday), now: .now) == false)
    }

    /// But a live game is never suppressed by a clock heuristic, however
    /// old its kickoff looks — `isSpent` exempts live games on purpose,
    /// and the pin control inherits that rather than second-guessing it.
    @Test func aLongRunningLiveGameStaysStartable() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: .now)!
        #expect(LiveActivityController.isStartable(game(status: playing, date: yesterday)))
    }

    /// A flaky pre-game summary against a live snapshot must not make a
    /// live game look startable-as-pre — the merge rule, one surface out.
    @Test func offerFollowsTheMergedStatus() {
        let liveGame = game(status: playing, date: .now)
        let stalePre = GameSummary(home: nil, away: nil, status: .pre(detail: nil),
                                   scoringPlays: [], drives: [], teamStats: [],
                                   leaders: [], venue: nil, attendance: nil)
        #expect(LiveActivityContent.state(for: liveGame, summary: stalePre).phase == .live)
    }
}
#endif
