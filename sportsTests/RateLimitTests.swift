import Foundation
import Testing
@testable import StatSide

/// Stubs an `HTTPURLResponse` for whatever `ESPNClient` asks, so the 429
/// path can be exercised without a route to ESPN (the agent environment's
/// egress is outside it). `ESPNClient.init(session:)` already takes a
/// `URLSession`, which is the seam this uses.
private final class RateLimitStubProtocol: URLProtocol {
    nonisolated(unsafe) static var statusCode = 429
    nonisolated(unsafe) static var headers: [String: String] = [:]

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.statusCode,
                                       httpVersion: "HTTP/1.1", headerFields: Self.headers)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private func stubbedClient(statusCode: Int, headers: [String: String] = [:]) -> ESPNClient {
    RateLimitStubProtocol.statusCode = statusCode
    RateLimitStubProtocol.headers = headers
    let config = URLSessionConfiguration.ephemeral
    config.protocolClasses = [RateLimitStubProtocol.self]
    return ESPNClient(league: .collegeFootball, session: URLSession(configuration: config))
}

/// A stubbed 429 produces `ESPNError.rateLimited`, not the generic
/// `badStatus` every other non-2xx keeps answering — the acceptance a
/// retry button needs something to throttle on, verified at the one seam
/// that can take a fake `URLSession` without a real route to ESPN.
@Suite struct RateLimitDecodingTests {
    @Test func a429WithARetryAfterHeaderCarriesThatInterval() async {
        let client = stubbedClient(statusCode: 429, headers: ["Retry-After": "42"])
        do {
            _ = try await client.scoreboard(day: Date())
            Issue.record("expected a throw")
        } catch ESPNError.rateLimited(let retryAfter) {
            #expect(retryAfter == 42)
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func a429WithNoRetryAfterHeaderDefaultsToThirtySeconds() async {
        let client = stubbedClient(statusCode: 429)
        do {
            _ = try await client.scoreboard(day: Date())
            Issue.record("expected a throw")
        } catch ESPNError.rateLimited(let retryAfter) {
            #expect(retryAfter == 30)
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func everyOtherBadStatusStillThrowsBadStatus() async {
        let client = stubbedClient(statusCode: 503)
        do {
            _ = try await client.scoreboard(day: Date())
            Issue.record("expected a throw")
        } catch ESPNError.badStatus(let code) {
            #expect(code == 503)
        } catch {
            Issue.record("wrong error: \(error)")
        }
    }

    @Test func retryAfterIntervalParsesSecondsAndFallsBackHonestly() {
        func response(_ headers: [String: String]) -> HTTPURLResponse {
            HTTPURLResponse(url: URL(string: "https://site.api.espn.com")!, statusCode: 429,
                            httpVersion: "HTTP/1.1", headerFields: headers)!
        }
        #expect(ESPNClient.retryAfterInterval(from: response(["Retry-After": "12"])) == 12)
        // No header, zero, negative, and the HTTP-date form this doesn't
        // parse all fall back to the same floor — ESPN has never sent any
        // of these, so the floor is the honest default rather than a
        // guess at which one is more likely.
        #expect(ESPNClient.retryAfterInterval(from: response([:])) == 30)
        #expect(ESPNClient.retryAfterInterval(from: response(["Retry-After": "0"])) == 30)
        #expect(ESPNClient.retryAfterInterval(from: response(["Retry-After": "-5"])) == 30)
        #expect(ESPNClient.retryAfterInterval(
            from: response(["Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"])) == 30)
    }
}
