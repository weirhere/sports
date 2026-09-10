import Foundation
import os

#if canImport(ActivityKit)

/// Where a game's broadcast channel id comes from.
///
/// Path 3 subscribes each activity to a channel **per game**, so one push
/// reaches every device watching that game and the service stores channel
/// ids rather than device tokens. The client's whole part in that is
/// learning which channel a game is on.
///
/// A protocol because the answer is a network call the tests must not make,
/// and because "there is no service yet" has to be a first-class answer
/// rather than a crash.
nonisolated protocol LiveActivityChannelDirectory: Sendable {
    func channelId(for game: Game) async -> String?
}

/// The default: ask the service, fall back to nil.
///
/// nil means "start a local-only activity" — correct for a DEBUG look and
/// wrong for a shipped feature, which is what `isAvailable` is for.
nonisolated struct RemoteChannelDirectory: LiveActivityChannelDirectory {
    private static let log = Logger(subsystem: "com.andyryanweir.sports",
                                    category: "liveactivity.channels")

    /// Configured rather than hardcoded so a DEBUG build can point at a
    /// preview deployment without a code change. No value means no service,
    /// which is today's state.
    let baseURL: URL?
    let session: URLSession

    init(baseURL: URL? = RemoteChannelDirectory.configuredBaseURL,
         session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
    }

    static var configuredBaseURL: URL? {
        guard let raw = UserDefaults.standard.string(forKey: "liveactivity.serviceURL"),
              !raw.isEmpty else { return nil }
        return URL(string: raw)
    }

    private struct Response: Decodable { let channelId: String }

    func channelId(for game: Game) async -> String? {
        guard let baseURL else { return nil }
        var components = URLComponents(url: baseURL.appendingPathComponent("channel"),
                                       resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "gameId", value: game.id),
            URLQueryItem(name: "league", value: game.home.team.league.rawValue),
        ]
        guard let url = components?.url else { return nil }
        do {
            let (data, response) = try await session.data(from: url)
            guard let http = response as? HTTPURLResponse,
                  (200...299).contains(http.statusCode) else { return nil }
            return try JSONDecoder().decode(Response.self, from: data).channelId
        } catch {
            // A channel we can't look up is a card that updates locally
            // instead of not existing — the lesser failure by a distance.
            Self.log.error("channel lookup failed: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }
}

/// For tests and the DEBUG harness.
nonisolated struct StubChannelDirectory: LiveActivityChannelDirectory {
    let id: String?
    init(_ id: String? = nil) { self.id = id }
    func channelId(for game: Game) async -> String? { id }
}
#endif
