import Foundation
import Testing
@testable import StatSide

/// The season fetch's request limiter and the college Top 25's slimmer
/// slate (2026-11-03): ~150 college basketball day requests fired at once
/// timed out 660 of 1,159 requests, the page's poll among them.
@Suite struct RequestGateTests {
    private actor Counter {
        var now = 0
        var peak = 0
        var calls = 0
        func enter() { now += 1; calls += 1; peak = max(peak, now) }
        func leave() { now -= 1 }
    }

    private struct Flaky: Error {}

    @Test func neverMoreThanTheLimitAtOnce() async throws {
        let gate = RequestGate(limit: 3)
        let counter = Counter()
        try await withThrowingTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    try await gate.run {
                        await counter.enter()
                        try await Task.sleep(for: .milliseconds(5))
                        await counter.leave()
                    }
                }
            }
            try await group.waitForAll()
        }
        #expect(await counter.peak == 3)
        #expect(await counter.calls == 20)
    }

    /// A request that fails once is asked again, and the second answer is
    /// the one that counts.
    @Test func aFailureIsRetriedOnce() async throws {
        let gate = RequestGate(limit: 1)
        let counter = Counter()
        let value = try await gate.run { () async throws -> Int in
            await counter.enter()
            await counter.leave()
            if await counter.calls == 1 { throw Flaky() }
            return 7
        }
        #expect(value == 7)
        #expect(await counter.calls == 2)
    }

    /// Twice is the limit: a request that fails both times fails.
    @Test func aSecondFailureIsThrown() async {
        let gate = RequestGate(limit: 1)
        let counter = Counter()
        await #expect(throws: Flaky.self) {
            try await gate.run { () async throws -> Int in
                await counter.enter()
                await counter.leave()
                throw Flaky()
            }
        }
        #expect(await counter.calls == 2)
    }

    /// Selection Sunday's weekend through the championship, with slack:
    /// March 14 to April 10 of the year the season ends.
    @Test func theTournamentWindowRunsMidMarchToEarlyApril() {
        let days = ESPNClient.tournamentDayTokens(endYear: 2026)
        #expect(days.first == "20260314")
        #expect(days.last == "20260410")
        #expect(days.count == 28)
        #expect(days.contains("20260406"))
    }

    /// Only college basketball is too big to load whole.
    @Test func onlyCollegeBasketballSkipsTheWholeSeason() {
        #expect(!League.mensCollegeBasketball.loadsWholeSeasonSlate)
        #expect(!League.womensCollegeBasketball.loadsWholeSeasonSlate)
        for league in [League.collegeFootball, .nfl, .nba, .nhl, .mlb, .wnba] {
            #expect(league.loadsWholeSeasonSlate, "\(league)")
        }
    }
}
