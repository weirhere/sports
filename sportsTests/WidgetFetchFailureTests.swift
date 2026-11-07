import Foundation
import Testing
@testable import StatSide

/// The widget's failure categories (COR-13, 2026-11-07). The label is the
/// word a field Saturday's log archive gets grepped for, so it's tested as
/// the string, not just the case.
@Suite struct WidgetFetchFailureTests {

    @Test func noRouteIsOffline() {
        for code in [URLError.Code.notConnectedToInternet, .networkConnectionLost,
                     .cannotFindHost, .dnsLookupFailed] {
            #expect(WidgetFetchFailure(URLError(code)).label == "offline")
        }
    }

    @Test func aTimeoutIsItsOwnWord() {
        #expect(WidgetFetchFailure(URLError(.timedOut)).label == "timeout")
    }

    @Test func statusesCarryTheirCode() {
        #expect(WidgetFetchFailure(ESPNError.badStatus(503)).label == "http-503")
        #expect(WidgetFetchFailure(CFBDError.badStatus(401)).label == "http-401")
    }

    /// Both ways a 429 can arrive read the same, since it's the one a
    /// Saturday's log is most worth searching for.
    @Test func a429IsRateLimitedHoweverItArrives() {
        #expect(WidgetFetchFailure(ESPNError.rateLimited(retryAfter: 30)).label == "rate-limited")
        #expect(WidgetFetchFailure(ESPNError.badStatus(429)).label == "rate-limited")
    }

    @Test func aShapeChangeIsDecode() {
        let error = DecodingError.dataCorrupted(.init(codingPath: [], debugDescription: "x"))
        #expect(WidgetFetchFailure(error).label == "decode")
    }

    @Test func aTornDownTaskIsCancelled() {
        #expect(WidgetFetchFailure(CancellationError()).label == "cancelled")
        #expect(WidgetFetchFailure(URLError(.cancelled)).label == "cancelled")
    }

    @Test func anythingElseIsOther() {
        #expect(WidgetFetchFailure(ESPNError.invalidURL).label == "other")
        #expect(WidgetFetchFailure(URLError(.badServerResponse)).label == "other")
    }
}
