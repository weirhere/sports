import Foundation
import Testing
import UserNotifications
@testable import StatSide

// MARK: - Fakes

private actor FakeCenter: NotificationCentering {
    struct Added: Sendable {
        let id: String
        let body: String
        let fireDate: Date
        let gameId: String
    }

    private let granted: Bool
    private(set) var added: [Added] = []
    private(set) var removed: [String] = []
    private(set) var pending: [String] = []

    init(granted: Bool = true) {
        self.granted = granted
    }

    func requestAuthorization() async throws -> Bool { granted }

    func authorizationStatus() async -> UNAuthorizationStatus { granted ? .authorized : .denied }

    func pendingIdentifiers() async -> [String] { pending }

    func add(id: String, title: String, body: String, fireDate: Date, gameId: String) async throws {
        added.append(Added(id: id, body: body, fireDate: fireDate, gameId: gameId))
        pending.append(id)
    }

    func removePending(identifiers: [String]) async {
        removed.append(contentsOf: identifiers)
        pending.removeAll { identifiers.contains($0) }
    }
}

private struct ScheduleStub: ScoresProviding {
    let schedules: [String: [Game]]

    func teamSchedule(teamId: String) async throws -> TeamSchedule {
        TeamSchedule(team: nil, record: nil, standing: nil, games: schedules[teamId] ?? [])
    }

    func scoreboard(weekValue: Int?, seasonType: Int?, year: Int?) async throws -> Scoreboard {
        Scoreboard(seasonYear: nil, seasonType: nil, currentWeekNumber: nil, weeks: [], games: [])
    }
    func rankings() async throws -> [Poll] { [] }
    func fbsConferences() async throws -> [ConferenceTeams] { [] }
    func gameSummary(eventId: String) async throws -> GameSummary { throw ESPNError.invalidURL }
}

private func team(_ id: String) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil)
}

private func preGame(_ id: String, home: String, away: String, kickoff: Date?,
                     broadcast: String? = nil) -> Game {
    Game(id: id, date: kickoff, name: nil, shortName: nil, weekNumber: nil,
         status: .pre(detail: nil),
         home: Competitor(team: team(home), score: nil, record: nil, rank: nil, isHome: true, winner: nil),
         away: Competitor(team: team(away), score: nil, record: nil, rank: nil, isHome: false, winner: nil),
         broadcast: broadcast)
}

// MARK: - Tests

@MainActor
@Suite struct NotificationSchedulerTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.notifications.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func makeScheduler(center: FakeCenter, schedules: [String: [Game]])
        -> NotificationScheduler {
        NotificationScheduler(center: center,
                              client: ScheduleStub(schedules: schedules),
                              defaults: makeDefaults())
    }

    @Test func schedulesNearest24OfManyGames() async {
        let games = (1...30).map {
            preGame("g\($0)", home: "1", away: "opp\($0)",
                    kickoff: .now.addingTimeInterval(Double($0) * 86_400))
        }
        let center = FakeCenter()
        let scheduler = makeScheduler(center: center, schedules: ["1": games])

        await scheduler.requestAndEnable(followedIds: ["1"])

        let added = await center.added
        #expect(added.count == NotificationScheduler.maxScheduled)
        #expect(added.contains { $0.gameId == "g1" })
        #expect(!added.contains { $0.gameId == "g30" })
    }

    @Test func movedKickoffSwapsTheRequest() async {
        let original = Date.now.addingTimeInterval(7 * 86_400)
        let moved = original.addingTimeInterval(3 * 3600)
        let center = FakeCenter()
        let defaults = makeDefaults()

        let first = NotificationScheduler(
            center: center,
            client: ScheduleStub(schedules: ["1": [preGame("g1", home: "1", away: "2", kickoff: original)]]),
            defaults: defaults
        )
        await first.requestAndEnable(followedIds: ["1"])
        let originalId = NotificationScheduler.requestId(gameId: "g1", kickoff: original)
        #expect(await center.pending == [originalId])

        // ESPN moves the kickoff; the next resync (fresh launch here) must
        // drop the stale request and schedule the new instant.
        let second = NotificationScheduler(
            center: center,
            client: ScheduleStub(schedules: ["1": [preGame("g1", home: "1", away: "2", kickoff: moved)]]),
            defaults: defaults
        )
        await second.refreshAuthorization()
        await second.resync(followedIds: ["1"])

        #expect(await center.removed.contains(originalId))
        #expect(await center.pending == [NotificationScheduler.requestId(gameId: "g1", kickoff: moved)])
    }

    @Test func unfollowingEveryoneClearsPending() async {
        let center = FakeCenter()
        let scheduler = makeScheduler(
            center: center,
            schedules: ["1": [preGame("g1", home: "1", away: "2",
                                      kickoff: .now.addingTimeInterval(86_400))]]
        )
        await scheduler.requestAndEnable(followedIds: ["1"])
        #expect(await center.pending.count == 1)

        await scheduler.resync(followedIds: [])
        #expect(await center.pending.isEmpty)
    }

    @Test func tbdAndPastAndImminentGamesAreSkipped() async {
        let center = FakeCenter()
        let scheduler = makeScheduler(center: center, schedules: ["1": [
            preGame("tbd", home: "1", away: "2", kickoff: nil),
            preGame("played", home: "1", away: "3", kickoff: .now.addingTimeInterval(-86_400)),
            // Inside the 30-minute lead window: the reminder moment is gone.
            preGame("imminent", home: "1", away: "4", kickoff: .now.addingTimeInterval(10 * 60)),
        ]])
        await scheduler.requestAndEnable(followedIds: ["1"])
        #expect(await center.added.isEmpty)
    }

    @Test func sharedGameBetweenTwoFollowedTeamsSchedulesOnce() async {
        let rivalry = preGame("g1", home: "1", away: "2",
                              kickoff: .now.addingTimeInterval(86_400))
        let center = FakeCenter()
        let scheduler = makeScheduler(center: center, schedules: ["1": [rivalry], "2": [rivalry]])
        await scheduler.requestAndEnable(followedIds: ["1", "2"])
        #expect(await center.added.count == 1)
    }

    @Test func disabledSchedulerSchedulesNothing() async {
        let center = FakeCenter()
        let scheduler = makeScheduler(
            center: center,
            schedules: ["1": [preGame("g1", home: "1", away: "2",
                                      kickoff: .now.addingTimeInterval(86_400))]]
        )
        // Never enabled — resync must be a no-op.
        await scheduler.resync(followedIds: ["1"])
        #expect(await center.added.isEmpty)
    }

    @Test func deniedPermissionNeverEnables() async {
        let center = FakeCenter(granted: false)
        let scheduler = makeScheduler(
            center: center,
            schedules: ["1": [preGame("g1", home: "1", away: "2",
                                      kickoff: .now.addingTimeInterval(86_400))]]
        )
        let granted = await scheduler.requestAndEnable(followedIds: ["1"])
        #expect(!granted)
        #expect(scheduler.isDenied)
        #expect(!scheduler.remindersOn)
        #expect(await center.added.isEmpty)
    }

    @Test func reminderBodyReadsLikeASentence() {
        let kickoff = Date(timeIntervalSince1970: 1_787_200_200)
        let game = preGame("g1", home: "1", away: "2", kickoff: kickoff,
                           broadcast: "CBS/Paramount+")
        let body = NotificationScheduler.reminderBody(for: game)
        #expect(body.hasPrefix("Team 2 at Team 1 kicks off at "))
        #expect(body.hasSuffix(" on CBS"))
    }
}
