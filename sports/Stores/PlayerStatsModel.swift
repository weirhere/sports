import Foundation
import Observation

/// One player page's numbers: the season-by-season stats, fetched once when
/// the page opens, and each season's game log, fetched the first time the
/// Games tab asks for that season.
///
/// Held for the session in `cache`, so walking back to a player you just
/// looked at costs no request — E20's Career rule ("lazy, cached for the
/// session, cancelled when the page goes away") applied to every tab. The
/// page owns the tasks, so a pop cancels whatever is in flight.
@Observable
@MainActor
final class PlayerStatsModel {
    let athleteId: String
    let league: League

    private(set) var stats: PlayerStats?
    /// Keyed by ESPN season year; `nil` is "whatever ESPN calls current".
    private(set) var logs: [Int?: PlayerGameLog] = [:]
    private(set) var loadingLog: Int??

    @ObservationIgnored private let client: PlayerStatsClient

    init(athleteId: String, league: League, client: PlayerStatsClient = PlayerStatsClient()) {
        self.athleteId = athleteId
        self.league = league
        self.client = client
        let cached = Self.cache[Self.key(athleteId, league)]
        self.stats = cached?.stats
        self.logs = cached?.logs ?? [:]
    }

    /// The season "now" belongs to, in ESPN's numbering for this league —
    /// the only season the Current season card will speak for.
    var currentESPNSeason: Int {
        league.espnSeason(for: SeasonSpan.year(containing: .now))
    }

    func loadStats() async {
        guard stats == nil else { return }
        let fetched = await client.stats(athleteId: athleteId, league: league)
        guard !Task.isCancelled else { return }
        stats = fetched
        remember()
    }

    func loadLog(season: Int?) async {
        guard logs[season] == nil else { return }
        loadingLog = .some(season)
        defer { if loadingLog == .some(season) { loadingLog = nil } }
        let fetched = await client.gameLog(athleteId: athleteId, league: league, season: season)
        guard !Task.isCancelled else { return }
        logs[season] = fetched
        // ESPN's "current" answer also names its season; file it under that
        // year too, so picking it from the menu is a cache hit.
        if season == nil, let year = fetched.season { logs[year] = fetched }
        remember()
    }

    // MARK: - Session cache

    private struct Entry {
        var stats: PlayerStats?
        var logs: [Int?: PlayerGameLog]
    }

    private static var cache: [String: Entry] = [:]

    private static func key(_ athleteId: String, _ league: League) -> String {
        "\(league.rawValue)-\(athleteId)"
    }

    private func remember() {
        Self.cache[Self.key(athleteId, league)] = Entry(stats: stats, logs: logs)
    }
}
