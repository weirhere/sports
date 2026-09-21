import Foundation
import SwiftUI

/// The games a search finds beyond the days already loaded.
///
/// Search's game corpus is `LeagueScoreboards.allLoadedGames` — the day you
/// are on plus the five-day window fetched around it. So a team that played
/// yesterday showed that final, today and tomorrow, and not the game they
/// play next week, because nothing had asked for that day (Andy, 2026-09-21,
/// three times, which is how often a limit has to bite before it is a bug).
///
/// **ESPN's search endpoint cannot fill this.** The one that gave us
/// athletes returns no scoreboard events: its `upcoming` type is broadcast
/// listings — "ESPN+ · NCAA Women's Soccer", keyed to a watch URL — across
/// sports this app does not cover. Probed live 2026-09-21.
///
/// `/teams/{id}/schedule` can: **one request, one whole season.** So the
/// games come from the teams the query already matched, which keeps the
/// request set a consequence of a search that succeeded rather than of
/// every keystroke.
@Observable
@MainActor
final class TeamScheduleSearchStore {
    private(set) var games: [Game] = []

    /// The same clock the athlete search runs on, so a query costs at most
    /// one round of requests however fast it is typed.
    private static let debounce = Duration.milliseconds(300)
    /// Three teams, one request each. A query like "New York" matches six
    /// across four leagues, and the answer to "when do they play next" does
    /// not improve by asking for all of them.
    private static let maxTeams = 3

    private let makeClient: @Sendable (League) -> any ScoresProviding
    private var task: Task<Void, Never>?
    /// Keyed by team, for the session. A schedule is a season and does not
    /// churn; `TeamPage` caches its own the same way.
    private var cache: [String: [Game]] = [:]
    private var lastKeys: [String] = []

    init(makeClient: @escaping @Sendable (League) -> any ScoresProviding = { ESPNClient(league: $0) }) {
        self.makeClient = makeClient
    }

    /// Call with whatever teams the query matched. Cheap when they haven't
    /// changed, and free when there are none.
    func load(for teams: [Team]) {
        let wanted = Array(teams.prefix(Self.maxTeams))
        let keys = wanted.map(\.followKey)
        guard keys != lastKeys else { return }
        lastKeys = keys
        task?.cancel()

        guard !wanted.isEmpty else {
            games = []
            return
        }

        task = Task { [weak self, makeClient] in
            try? await Task.sleep(for: Self.debounce)
            guard !Task.isCancelled else { return }

            var found: [Game] = []
            for team in wanted {
                if let cached = await self?.cache[team.followKey] {
                    found += cached
                    continue
                }
                let client = makeClient(team.league)
                guard let schedule = try? await client.teamSchedule(teamId: team.id) else { continue }
                guard !Task.isCancelled else { return }
                await self?.store(schedule.games, for: team.followKey)
                found += schedule.games
            }
            guard !Task.isCancelled else { return }
            guard let self, self.lastKeys == keys else { return }
            self.games = found
        }
    }

    func clear() {
        task?.cancel()
        lastKeys = []
        games = []
    }

    private func store(_ games: [Game], for key: String) {
        cache[key] = games
    }
}

nonisolated extension Game {
    /// The slate's copy of a game wins over a schedule's.
    ///
    /// A schedule is fetched once and never polled, so its score is frozen
    /// at whatever it held when the season was asked for — which is exactly
    /// how `ConferencePage` came to show a live game stuck at halftime
    /// (2026-09-01). `merging(_:withLive:)` already encodes the rule; this
    /// is the union that needs it, deduped so a game in both appears once.
    /// Deduped on **both** sides, which the first cut was not: a query for
    /// "new york" matches the Islanders and the Rangers, and the game they
    /// play each other arrives in both schedules. Two rows with one id in a
    /// `LazyVStack` do not render twice — they corrupt its layout and leave
    /// a blank card-sized gap, the failure `FollowedTablesList`'s own
    /// comment names (Andy, 2026-09-21: "weird awkward gaps").
    static func union(_ schedule: [Game], loaded: [Game]) -> [Game] {
        var seen = Set(loaded.map(\.id))
        var extra: [Game] = []
        for game in schedule where seen.insert(game.id).inserted {
            extra.append(game)
        }
        return merging(loaded + extra, withLive: loaded)
    }

    /// Next kickoff first, then forward; the most recent completed game
    /// above it.
    ///
    /// Not plain chronological. The question behind "when do they play
    /// next" is answered by one game, and a season sorted by date buries it
    /// under three months of finals.
    static func orderedAroundNow(_ games: [Game], now: Date = .now) -> [Game] {
        let dated = games.filter { $0.date != nil }
        let upcoming = dated.filter { ($0.date ?? .distantPast) >= now }
            .sorted { ($0.date ?? .distantPast) < ($1.date ?? .distantPast) }
        let past = dated.filter { ($0.date ?? .distantPast) < now }
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }
        // One completed game for context, then everything still to come.
        return Array(past.prefix(1)) + upcoming + Array(past.dropFirst())
    }
}
