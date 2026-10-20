import Foundation
import Testing
@testable import StatSide

private func team(_ id: String, league: League = .collegeFootball) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil, league: league)
}

private func side(_ id: String, score: Int?, winner: Bool?, isHome: Bool,
                  league: League = .collegeFootball) -> Competitor {
    Competitor(team: team(id, league: league), score: score, record: nil, rank: nil,
               isHome: isHome, winner: winner)
}

private let regulation = GameStatus.final(detail: "Final")
private let finalOT = GameStatus.final(detail: "Final/OT")
private let finalSO = GameStatus.final(detail: "Final/SO")
private let live = GameStatus.live(displayClock: "5:24", period: 3, detail: nil,
                                   phase: .playing, possessionTeamId: nil)

/// A hidden final's record with the game taken back off it (E30). The
/// winner gives back a win, the loser a loss — except hockey's overtime
/// and shootout losses, which come off the third field, and the NFL's
/// ties, which do too. Anything the rewind can't do honestly hides the
/// record rather than printing a wrong one.
@Suite struct RecordRewindTests {
    private let winner = side("w", score: 24, winner: true, isHome: false)
    private let loser = side("l", score: 17, winner: false, isHome: true)

    @Test func theWinnerGivesBackAWin() {
        #expect(RecordRewind.rewound("7-0", for: winner, against: loser,
                                     status: regulation, league: .collegeFootball) == "6-0")
    }

    @Test func theLoserGivesBackALoss() {
        #expect(RecordRewind.rewound("6-2", for: loser, against: winner,
                                     status: regulation, league: .collegeFootball) == "6-1")
    }

    @Test func aHockeyOvertimeLossComesOffTheThirdField() {
        #expect(RecordRewind.rewound("38-20-6", for: loser, against: winner,
                                     status: finalOT, league: .nhl) == "38-20-5")
    }

    @Test func aHockeyShootoutLossComesOffTheThirdField() {
        #expect(RecordRewind.rewound("38-20-6", for: loser, against: winner,
                                     status: finalSO, league: .nhl) == "38-20-5")
    }

    @Test func aHockeyRegulationLossIsALoss() {
        #expect(RecordRewind.rewound("38-20-6", for: loser, against: winner,
                                     status: regulation, league: .nhl) == "38-19-6")
    }

    @Test func aHockeyWinnerInOvertimeStillGivesBackAWin() {
        #expect(RecordRewind.rewound("40-19-5", for: winner, against: loser,
                                     status: finalOT, league: .nhl) == "39-19-5")
    }

    @Test func aTwoFieldHockeyRecordFallsBackToTheLoss() {
        // No third field to take it from; the loss column is the honest
        // nearest thing.
        #expect(RecordRewind.rewound("38-20", for: loser, against: winner,
                                     status: finalOT, league: .nhl) == "38-19")
    }

    @Test func anNFLOvertimeLossIsALoss() {
        // The NFL's third field is ties, so "OT" means nothing for it.
        #expect(RecordRewind.rewound("5-2-1", for: loser, against: winner,
                                     status: finalOT, league: .nfl) == "5-1-1")
    }

    @Test func aTieComesOffTheThirdField() {
        let home = side("h", score: 20, winner: nil, isHome: true, league: .nfl)
        let away = side("a", score: 20, winner: nil, isHome: false, league: .nfl)
        #expect(RecordRewind.rewound("5-2-1", for: home, against: away,
                                     status: regulation, league: .nfl) == "5-2-0")
    }

    @Test func aTieWithNoTiesColumnHides() {
        let home = side("h", score: 20, winner: nil, isHome: true, league: .nfl)
        let away = side("a", score: 20, winner: nil, isHome: false, league: .nfl)
        #expect(RecordRewind.rewound("5-2", for: home, against: away,
                                     status: regulation, league: .nfl) == nil)
    }

    @Test func theScoresDecideWhenESPNOmitsTheWinnerFlags() {
        let ahead = side("h", score: 31, winner: nil, isHome: true)
        let behind = side("a", score: 17, winner: nil, isHome: false)
        #expect(RecordRewind.rewound("3-0", for: ahead, against: behind,
                                     status: regulation, league: .collegeFootball) == "2-0")
        #expect(RecordRewind.rewound("0-3", for: behind, against: ahead,
                                     status: regulation, league: .collegeFootball) == "0-2")
    }

    @Test func anUnknownOutcomeHidesTheRecord() {
        let home = side("h", score: nil, winner: nil, isHome: true)
        let away = side("a", score: nil, winner: nil, isHome: false)
        #expect(RecordRewind.rewound("5-2", for: home, against: away,
                                     status: regulation, league: .collegeFootball) == nil)
    }

    @Test func aFieldThatWouldGoNegativeHidesTheRecord() {
        // A record that already lags the result: a lie either way, so a blank.
        #expect(RecordRewind.rewound("0-2", for: winner, against: loser,
                                     status: regulation, league: .collegeFootball) == nil)
    }

    @Test func anUnparseableRecordHides() {
        #expect(RecordRewind.rewound("—", for: winner, against: loser,
                                     status: regulation, league: .collegeFootball) == nil)
        #expect(RecordRewind.rewound("W5", for: winner, against: loser,
                                     status: regulation, league: .collegeFootball) == nil)
        #expect(RecordRewind.rewound("1-2-3-4", for: winner, against: loser,
                                     status: regulation, league: .collegeFootball) == nil)
    }

    @Test func aLiveGamesRecordIsAlreadyPreGame() {
        #expect(RecordRewind.rewound("7-0", for: winner, against: loser,
                                     status: live, league: .collegeFootball) == "7-0")
    }

    @Test func noRecordStaysNoRecord() {
        #expect(RecordRewind.rewound(nil, for: winner, against: loser,
                                     status: regulation, league: .collegeFootball) == nil)
    }
}
