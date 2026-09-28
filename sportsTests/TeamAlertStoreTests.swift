import Foundation
import Testing
@testable import StatSide

// Per-team notifications from the bell sheet (Andy, 2026-09-28).

@MainActor
@Suite struct TeamAlertStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.teamAlerts.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func anUntouchedTeamGetsTheKickoffReminderAndNothingElse() {
        let store = TeamAlertStore(defaults: makeDefaults())
        #expect(store.alerts(for: "cfb:61") == [.kickoffReminder])
        #expect(store.isOn(.kickoffReminder, for: "cfb:61"))
        #expect(!store.isOn(.scoring, for: "cfb:61"))
        #expect(!store.pinsGames("cfb:61"))
    }

    @Test func existingFollowersKeepTheirReminders() {
        // Nothing stored is today's install: every followed team still
        // gets its reminder, exactly as before the sheet.
        let store = TeamAlertStore(defaults: makeDefaults())
        let followed: Set<String> = ["cfb:61", "nfl:26"]
        #expect(store.keys(receiving: .kickoffReminder, among: followed) == followed)
    }

    @Test func turningTheReminderOffDropsOnlyThatTeam() {
        let store = TeamAlertStore(defaults: makeDefaults())
        store.toggle(.kickoffReminder, for: "cfb:61")
        #expect(store.keys(receiving: .kickoffReminder, among: ["cfb:61", "nfl:26"]) == ["nfl:26"])
    }

    @Test func muteSilencesATeamAndUnmuteGivesBackItsChoices() {
        let store = TeamAlertStore(defaults: makeDefaults())
        store.toggle(.final, for: "nhl:21")
        store.setMuted(true, for: "nhl:21")
        #expect(!store.isOn(.kickoffReminder, for: "nhl:21"))
        #expect(!store.isOn(.final, for: "nhl:21"))
        store.setMuted(false, for: "nhl:21")
        #expect(store.isOn(.kickoffReminder, for: "nhl:21"))
        #expect(store.isOn(.final, for: "nhl:21"))
    }

    @Test func choicesSurviveARelaunch() {
        let defaults = makeDefaults()
        let first = TeamAlertStore(defaults: defaults)
        first.toggle(.news, for: "nba:13")
        first.setMuted(true, for: "cfb:61")
        first.setPinsGames(true, for: "nfl:26")

        let second = TeamAlertStore(defaults: defaults)
        #expect(second.alerts(for: "nba:13") == [.kickoffReminder, .news])
        #expect(second.isMuted("cfb:61"))
        #expect(second.pinnedKeys(among: ["nfl:26", "cfb:61"]) == ["nfl:26"])
    }

    @Test func everyWriteBumpsTheRevisionAndANoOpDoesNot() {
        let store = TeamAlertStore(defaults: makeDefaults())
        store.setMuted(false, for: "cfb:61")
        store.setPinsGames(false, for: "cfb:61")
        #expect(store.revision == 0)
        store.toggle(.news, for: "cfb:61")
        store.setMuted(true, for: "cfb:61")
        store.setPinsGames(true, for: "cfb:61")
        #expect(store.revision == 3)
    }

    @Test func pinnedOnlyCountsFollowedTeams() {
        let store = TeamAlertStore(defaults: makeDefaults())
        store.setPinsGames(true, for: "nfl:26")
        #expect(store.pinnedKeys(among: ["cfb:61"]).isEmpty)
    }

    // MARK: - What the sheet offers

    @Test func withoutAServiceOnlyTheReminderIsOffered() {
        for league in League.allCases {
            #expect(TeamAlert.offered(in: league, serviceAvailable: false) == [.kickoffReminder])
        }
    }

    @Test func basketballHasNoScoringRow() {
        #expect(!TeamAlert.offered(in: .nba, serviceAvailable: true).contains(.scoring))
        #expect(TeamAlert.offered(in: .nhl, serviceAvailable: true).contains(.scoring))
        #expect(TeamAlert.offered(in: .nfl, serviceAvailable: true).contains(.scoring))
    }

    @Test func rowsSpeakEachSport() {
        #expect(TeamAlert.kickoffReminder.title(in: .nfl) == "30 min before kickoff")
        #expect(TeamAlert.kickoffReminder.title(in: .nba) == "30 min before tip-off")
        #expect(TeamAlert.scoring.title(in: .nhl) == "Goals")
        #expect(TeamAlert.breakInPlay.title(in: .nhl) == "Intermissions")
        #expect(TeamAlert.breakInPlay.title(in: .collegeFootball) == "Halftime")
    }

    @Test func aTeamWithOnlyUnofferedAlertsSendsNothing() {
        // News picked in a DEBUG build, then the service switched off:
        // the bell must not claim a team sends something no row shows.
        let store = TeamAlertStore(defaults: makeDefaults())
        store.toggle(.kickoffReminder, for: "cfb:61")
        store.toggle(.news, for: "cfb:61")
        #expect(!store.sendsAnything("cfb:61", in: .collegeFootball, serviceAvailable: false))
        #expect(store.sendsAnything("cfb:61", in: .collegeFootball, serviceAvailable: true))
    }
}

#if canImport(ActivityKit)
// A team that pins every game (2026-09-28): which games get a card now.

private func game(_ id: String, status: GameStatus, kickoff: Date?,
                  timeTBD: Bool = false) -> Game {
    func side(_ teamId: String, home: Bool) -> Competitor {
        Competitor(team: Team(id: teamId, location: teamId, name: nil, abbreviation: nil,
                              displayName: nil, shortDisplayName: nil, logoURL: nil,
                              conferenceId: nil),
                   score: nil, record: nil, rank: nil, isHome: home, winner: nil)
    }
    return Game(id: id, date: kickoff, timeTBD: timeTBD, name: nil, shortName: nil,
                weekNumber: nil, status: status,
                home: side("h", home: true), away: side("a", home: false), broadcast: nil)
}

@MainActor
@Suite struct PinnedTeamGamesTests {
    private let now = Date(timeIntervalSince1970: 1_790_000_000)

    @Test func pinsTodaysGameInsideTheWindow() {
        let soon = game("g1", status: .pre(detail: nil), kickoff: now.addingTimeInterval(3600))
        #expect(LiveActivityController.gamesToPin([soon], active: [], now: now).map(\.id) == ["g1"])
    }

    @Test func waitsOnAGameBeyondTheWindow() {
        let later = game("g1", status: .pre(detail: nil),
                         kickoff: now.addingTimeInterval(LiveActivityController.pinWindow + 60))
        #expect(LiveActivityController.gamesToPin([later], active: [], now: now).isEmpty)
    }

    @Test func skipsATBDKickoff() {
        let tbd = game("g1", status: .pre(detail: nil), kickoff: now.addingTimeInterval(3600),
                       timeTBD: true)
        #expect(LiveActivityController.gamesToPin([tbd], active: [], now: now).isEmpty)
    }

    @Test func skipsAFinalAndAGameAlreadyCarded() {
        let final = game("g1", status: .final(detail: nil), kickoff: now.addingTimeInterval(-3600))
        let carded = game("g2", status: .pre(detail: nil), kickoff: now.addingTimeInterval(3600))
        #expect(LiveActivityController.gamesToPin([final, carded], active: ["g2"], now: now).isEmpty)
    }

    @Test func aGameBothPinningTeamsPlayIsOneCard() {
        let g = game("g1", status: .pre(detail: nil), kickoff: now.addingTimeInterval(3600))
        #expect(LiveActivityController.gamesToPin([g, g], active: [], now: now).count == 1)
    }
}
#endif
