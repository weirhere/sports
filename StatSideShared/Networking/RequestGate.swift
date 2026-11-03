import Foundation

/// At most `limit` requests in flight; the rest wait their turn.
///
/// A season fetch fans out to a request per day where a month comes back
/// short, and college basketball's season is ~150 such days of ~2 MB each.
/// Fired all at once they shared one HTTP/2 connection, and on 2026-11-03
/// 660 of 1,159 requests timed out at 60s with no byte received — the poll
/// behind them too. Taken in turns they each get the connection to
/// themselves long enough to finish.
actor RequestGate {
    private let limit: Int
    private var running = 0
    private var waiting: [CheckedContinuation<Void, Never>] = []

    init(limit: Int) {
        self.limit = max(1, limit)
    }

    /// Runs `operation` once a slot is free, retrying it once on failure: a
    /// request that timed out under load usually answers the second time,
    /// and one lost day would otherwise fail the whole season.
    func run<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        await acquire()
        defer { release() }
        do {
            return try await operation()
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            return try await operation()
        }
    }

    private func acquire() async {
        guard running >= limit else {
            running += 1
            return
        }
        await withCheckedContinuation { waiting.append($0) }
    }

    /// Hands the slot straight to the next waiter, so `running` never
    /// drops and refills between them.
    private func release() {
        if waiting.isEmpty {
            running -= 1
        } else {
            waiting.removeFirst().resume()
        }
    }
}
