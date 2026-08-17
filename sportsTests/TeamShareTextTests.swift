import Foundation
import Testing
@testable import StatSide

// Fixtures mirror GameShareTextTests' private builders. The shared team
// carries a stable id so home/away detection has something real to match.
private let buckeyeId = "194"

private func team(_ location: String, id: String, displayName: String? = nil) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: nil,
         displayName: displayName, shortDisplayName: nil, logoURL: nil, conferenceId: nil)
}

private func competitor(_ location: String, id: String, rank: Int? = nil, isHome: Bool) -> Competitor {
    Competitor(team: team(location, id: id), score: nil, record: nil,
               rank: rank, isHome: isHome, winner: nil)
}

private func game(status: GameStatus, homeId: String = buckeyeId, home: String = "Ohio State",
                  awayId: String = "61", away: String = "Georgia", awayRank: Int? = nil,
                  date: Date? = nil, timeTBD: Bool = false, broadcast: String? = nil) -> Game {
    Game(id: "g", date: date, timeTBD: timeTBD, name: nil, shortName: nil, weekNumber: 1, status: status,
         home: competitor(home, id: homeId, isHome: true),
         away: competitor(away, id: awayId, rank: awayRank, isHome: false),
         broadcast: broadcast)
}

private func schedule(record: String? = nil, games: [Game] = []) -> TeamSchedule {
    TeamSchedule(team: nil, record: record, standing: nil, games: games)
}

@Suite struct TeamShareTextTests {
    private let buckeyes = team("Ohio State", id: buckeyeId, displayName: "Ohio State Buckeyes")
    private let kick = Date(timeIntervalSince1970: 1_787_200_200)

    @Test func fullShapeCarriesRecordOpponentKickAndFirstNetwork() {
        let text = buckeyes.shareText(schedule: schedule(record: "12-1", games: [
            game(status: .pre(detail: nil), awayRank: 3, date: kick, broadcast: "ESPN/ESPN2")
        ]))
        #expect(text.hasPrefix("Keep up with Ohio State Buckeyes this season — 12-1"))
        #expect(text.contains("Next up: vs #3 Georgia"))
        #expect(text.contains(kick.shareKickText))
        #expect(text.contains("on ESPN"))
        #expect(!text.contains("ESPN2"))
    }

    @Test func awayNextGameSaysAt() {
        let road = game(status: .pre(detail: nil), homeId: "61", home: "Georgia",
                        awayId: buckeyeId, away: "Ohio State")
        let text = buckeyes.shareText(schedule: schedule(record: "12-1", games: [road]))
        #expect(text.contains("Next up: at Georgia"))
    }

    @Test func preseasonHidesTheRecordLikeTheHeader() {
        let text = buckeyes.shareText(schedule: schedule(record: "0-0", games: [
            game(status: .pre(detail: nil), date: kick)
        ]))
        #expect(!text.contains("0-0"))
        #expect(text.contains("Next up: vs Georgia"))
    }

    @Test func unannouncedKickoffSharesTheDayWithTimeTBD() {
        let text = buckeyes.shareText(schedule: schedule(record: "12-1", games: [
            game(status: .pre(detail: nil), date: kick, timeTBD: true)
        ]))
        #expect(text.contains("\(kick.shareKickDayText), time TBD"))
        #expect(!text.contains(kick.shareKickText))
    }

    @Test func noUpcomingGameDropsNextUp() {
        let text = buckeyes.shareText(schedule: schedule(record: "12-1", games: [
            game(status: .final(detail: "Final"))
        ]))
        #expect(text.hasPrefix("Keep up with Ohio State Buckeyes this season — 12-1 — via StatSide"))
        #expect(!text.contains("Next up"))
    }

    @Test func nilScheduleSharesTheInviteAlone() {
        let text = buckeyes.shareText(schedule: nil)
        #expect(text.hasPrefix("Keep up with Ohio State Buckeyes this season — via StatSide"))
    }

    @Test func missingDateAndBroadcastDropTheirClauses() {
        let text = buckeyes.shareText(schedule: schedule(games: [
            game(status: .pre(detail: nil))
        ]))
        #expect(text.contains("Next up: vs Georgia — via StatSide"))
        #expect(!text.contains(" on "))
    }

    @Test func nextGameSkipsFinalsAndLiveGames() {
        let text = buckeyes.shareText(schedule: schedule(record: "8-1", games: [
            game(status: .final(detail: "Final"), away: "Purdue"),
            game(status: .live(displayClock: "5:24", period: 3, detail: nil, possessionTeamId: nil), away: "Penn State"),
            game(status: .pre(detail: nil), away: "Michigan")
        ]))
        #expect(text.contains("Next up: vs Michigan"))
        #expect(!text.contains("Purdue"))
        #expect(!text.contains("Penn State"))
    }

    @Test func signsOffOnceWithTheStoreLink() {
        // The sign-off is the only place the app names itself — the body
        // saying "StatSide" too would read like a double signature.
        let shapes = [
            buckeyes.shareText(schedule: nil),
            buckeyes.shareText(schedule: schedule(record: "12-1", games: [
                game(status: .pre(detail: nil), date: kick, broadcast: "FOX")
            ]))
        ]
        for text in shapes {
            #expect(text.hasSuffix("— via StatSide\n\(ShareSignOff.appStoreURL)"))
            #expect(text.ranges(of: "StatSide").count == 1)
        }
    }
}
