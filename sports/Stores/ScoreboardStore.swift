import Foundation
import Observation
import os

/// One ordered section of the scores screen. A game appears in every section
/// whose promise it satisfies — sections are complete, never deduplicated.
struct GameSection: Identifiable, Hashable {
    static let followingId = "following"
    static let top25Id = "top25"

    let id: String
    let title: String
    let games: [Game]
}

@Observable
final class ScoreboardStore {
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "scoreboard")

    private let client: any ScoresProviding

    private(set) var weeks: [WeekSlot] = []
    private(set) var selectedWeek: WeekSlot?
    private(set) var games: [Game] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    var liveOnly = false

    @ObservationIgnored private var pollTask: Task<Void, Never>?

    init(client: any ScoresProviding) {
        self.client = client
    }

    var hasLiveGames: Bool {
        games.contains(where: \.isLive)
    }

    // MARK: - Loading

    /// First load: fetch ESPN's current scoreboard, build the week strip,
    /// and apply the Sunday rollover rule to pick the selected week.
    func loadInitial() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let scoreboard = try await client.scoreboard(weekValue: nil, seasonType: nil)
            weeks = scoreboard.weeks
            let defaultSlot = WeekLogic.defaultSelection(
                in: scoreboard.weeks,
                currentWeekNumber: scoreboard.currentWeekNumber,
                seasonType: scoreboard.seasonType
            )
            selectedWeek = defaultSlot
            // ESPN's current-week response only matches the default slot when
            // the rollover rule didn't shift it; re-fetch if it did.
            if let slot = defaultSlot,
               slot.value != scoreboard.currentWeekNumber || slot.seasonType != scoreboard.seasonType {
                await fetchSelectedWeek()
            } else {
                games = scoreboard.games
                lastError = nil
            }
        } catch {
            lastError = describe(error)
            Self.logger.error("initial load failed: \(error)")
        }
        startPollingIfNeeded()
    }

    func select(week: WeekSlot) async {
        guard week.id != selectedWeek?.id else { return }
        selectedWeek = week
        games = []
        await fetchSelectedWeek()
        startPollingIfNeeded()
    }

    /// Re-fetch the selected week. Games keep stable ids, so SwiftUI updates
    /// rows in place and accordion/scroll state survives.
    func refresh() async {
        await fetchSelectedWeek()
        startPollingIfNeeded()
    }

    private func fetchSelectedWeek() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let scoreboard = try await client.scoreboard(
                weekValue: selectedWeek?.value,
                seasonType: selectedWeek?.seasonType
            )
            if !scoreboard.weeks.isEmpty {
                weeks = scoreboard.weeks
            }
            games = scoreboard.games
            lastError = nil
        } catch {
            // Keep last-good games on failure.
            lastError = describe(error)
            Self.logger.error("fetch failed: \(error)")
        }
    }

    private func describe(_ error: Error) -> String {
        if error is DecodingError { return "Couldn't read the scoreboard." }
        return "Couldn't reach the scoreboard."
    }

    // MARK: - Polling
    // 30s auto-poll, only while the scene is active and ≥1 game is live.

    func startPollingIfNeeded() {
        guard pollTask == nil, hasLiveGames else { return }
        Self.logger.info("polling: started")
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                guard !Task.isCancelled, let self else { return }
                guard self.hasLiveGames else {
                    Self.logger.info("polling: stopped (no live games)")
                    self.pollTask = nil
                    return
                }
                Self.logger.info("polling: tick")
                await self.fetchSelectedWeek()
            }
        }
    }

    func stopPolling() {
        if pollTask != nil {
            Self.logger.info("polling: stopped (scene inactive)")
        }
        pollTask?.cancel()
        pollTask = nil
    }

    // MARK: - Sections

    /// Following → Top 25 → conferences, each section complete on its own
    /// terms. The Live filter collapses sections to in-progress games and
    /// hides the empties.
    func sections(followingIds: Set<String>) -> [GameSection] {
        let visible = liveOnly ? games.filter(\.isLive) : games
        var result: [GameSection] = []

        let followed = visible.filter {
            followingIds.contains($0.home.team.id) || followingIds.contains($0.away.team.id)
        }
        if !followed.isEmpty {
            result.append(GameSection(id: GameSection.followingId, title: "Following",
                                      games: chronological(followed)))
        }

        let ranked = visible.filter(\.involvesRankedTeam)
        if !ranked.isEmpty {
            result.append(GameSection(id: GameSection.top25Id, title: "Top 25",
                                      games: chronological(ranked)))
        }

        // A cross-conference game lands in both conferences' sections;
        // unknown conference ids bucket into "Other" (the nil key).
        var byConference: [Int?: [Game]] = [:]
        for game in visible {
            let ids = Set([game.home.team.conferenceId, game.away.team.conferenceId].map { id in
                Conference.tier(for: id) == .other ? nil : id
            })
            for id in ids {
                byConference[id, default: []].append(game)
            }
        }
        let orderedIds = byConference.keys.sorted { lhs, rhs in
            let (lt, rt) = (Conference.tier(for: lhs), Conference.tier(for: rhs))
            return lt == rt ? Conference.name(for: lhs) < Conference.name(for: rhs) : lt < rt
        }
        for id in orderedIds {
            let name = Conference.name(for: id)
            result.append(GameSection(id: "conf-\(name)", title: name,
                                      games: chronological(byConference[id] ?? [])))
        }
        return result
    }

    private func chronological(_ games: [Game]) -> [Game] {
        games.sorted {
            switch ($0.date, $1.date) {
            case let (a?, b?) where a != b: a < b
            case (nil, _?): false
            case (_?, nil): true
            default: $0.id < $1.id
            }
        }
    }
}
