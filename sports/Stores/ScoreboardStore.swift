import Foundation
import Observation
import os

/// How the scores list groups its sections: the default Following → Top 25
/// → conference stack, or Following pinned above one section per day.
enum ScoresGrouping: String {
    case conference
    case date
}

/// The ESPN-style slate filter (Josh Vertucci's feedback, 2026-08-29):
/// narrow the whole screen to one conference — or to ranked matchups —
/// in either grouping. Persisted like the grouping (Andy, same day,
/// superseding the session-only first cut): the labeled chip and the
/// explanatory empty states mean a saved filter is never a mystery.
enum ScoreFilter: Hashable {
    case top25
    case conference(Int)

    /// UserDefaults spelling — "top25" or "conference-8".
    var token: String {
        switch self {
        case .top25: "top25"
        case .conference(let id): "conference-\(id)"
        }
    }

    init?(token: String) {
        if token == "top25" {
            self = .top25
        } else if token.hasPrefix("conference-"),
                  let id = Int(token.dropFirst("conference-".count)) {
            self = .conference(id)
        } else {
            return nil
        }
    }

    /// What the sheet and empty state call the selection.
    var label: String {
        switch self {
        case .top25: "Top 25"
        case .conference(let id): Conference.name(for: id)
        }
    }

    /// The header chip's label — the long conference names get their
    /// common short forms so a full chip row still fits the screen.
    var chipLabel: String {
        switch self {
        case .conference(12): "C-USA"
        case .conference(17): "MWC"
        case .conference(18): "Indep."
        default: label
        }
    }

    /// The same claim rules the sections use: any ranked participant for
    /// Top 25, either side's conference for a conference — so an FCS
    /// visitor's game stays visible under its FBS host's conference.
    func matches(_ game: Game) -> Bool {
        switch self {
        case .top25:
            game.involvesRankedTeam
        case .conference(let id):
            game.home.team.conferenceId == id || game.away.team.conferenceId == id
        }
    }
}

/// One ordered section of the scores screen. A game appears in every section
/// whose promise it satisfies — sections are complete, never deduplicated.
struct GameSection: Identifiable, Hashable {
    static let followingId = "following"
    static let top25Id = "top25"
    /// Day sections (date grouping) use ids like "day-2026-08-29"; the
    /// prefix routes their expansion state separately in UIStateStore.
    static let dayPrefix = "day-"
    static let tbdDayId = "day-tbd"

    let id: String
    let title: String
    let games: [Game]
    var logoURL: URL? = nil
    /// Conference sections always show a mark (logo or fallback) so their
    /// titles align; Following shows a star, Top 25 a trophy.
    var isConference = false
    /// ESPN's group id, set only on conference sections with a known
    /// conference — it's what the header's standings link navigates with.
    var conferenceId: Int? = nil
}

@Observable
final class ScoreboardStore {
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "scoreboard")

    private let client: any ScoresProviding

    private(set) var weeks: [WeekSlot] = []
    private(set) var selectedWeek: WeekSlot?
    /// The current season's rollover-default slot — where live games
    /// happen, and the Live toggle's jump-home target. Stays anchored to
    /// the current season while browsing past ones.
    private(set) var currentWeekSlot: WeekSlot?
    private(set) var games: [Game] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    /// This season's fetched weeks, keyed by `WeekSlot.id`. The key spells
    /// "seasonType-value" with no year, so the season switch clears the
    /// whole cache. Feeds the swipe's preview pane and seeds a selected
    /// week so commits and chip taps never blank (2026-08-31).
    private(set) var weekGamesCache: [String: [Game]] = [:]
    @ObservationIgnored private var prefetching: Set<String> = []

    /// Memoized section builds. ScoresScreen's body re-evaluates on every
    /// frame of the interactive week drag, and each evaluation asks for
    /// the full pipeline up to three times (banner check, content, preview
    /// pane). The key hashes the games themselves — not ids — so a poll
    /// tick that only moves a clock can never be served stale sections.
    /// @ObservationIgnored: a body-time fill must not re-invalidate views.
    @ObservationIgnored private var sectionsMemo: [SectionsKey: [GameSection]] = [:]

    private struct SectionsKey: Hashable {
        let games: [Game]
        let followingIds: Set<String>
        let followedConferenceIds: Set<Int>
        let grouping: ScoresGrouping
        let liveOnly: Bool
        let filter: ScoreFilter?
    }

    /// The season on screen.
    private(set) var seasonYear: Int?
    /// ESPN's "now" season, captured on first load. Tops the picker range
    /// and marks which year needs no `dates=` override.
    private(set) var currentSeasonYear: Int?


    @ObservationIgnored private var pollTask: Task<Void, Never>?
    /// Non-nil while browsing a past season; forwarded on every fetch.
    @ObservationIgnored private var seasonOverride: Int?

    init(client: any ScoresProviding) {
        self.client = client
    }

    var hasLiveGames: Bool {
        games.contains(where: \.isLive)
    }

    /// Selectable seasons, newest first. Floor is 2014 — the CFP era.
    var availableSeasons: [Int] {
        guard let current = currentSeasonYear else { return [] }
        return Array(stride(from: current, through: 2014, by: -1))
    }

    // MARK: - Loading

    /// First load: fetch ESPN's current scoreboard, build the week strip,
    /// and apply the Sunday rollover rule to pick the selected week.
    func loadInitial() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let scoreboard = try await client.scoreboard(weekValue: nil, seasonType: nil, year: nil)
            weeks = scoreboard.weeks
            // The July offseason response can omit season; fall back to the
            // calendar's first slot (an August date, so its year IS the
            // season year even for January bowl games).
            currentSeasonYear = scoreboard.seasonYear
                ?? scoreboard.weeks.first?.startDate.map { Calendar.current.component(.year, from: $0) }
            seasonYear = currentSeasonYear
            let defaultSlot = WeekLogic.defaultSelection(
                in: scoreboard.weeks,
                currentWeekNumber: scoreboard.currentWeekNumber,
                seasonType: scoreboard.seasonType
            )
            selectedWeek = defaultSlot
            currentWeekSlot = defaultSlot
            // ESPN's current-week response only matches the default slot when
            // the rollover rule didn't shift it; re-fetch if it did.
            if let slot = defaultSlot,
               slot.value != scoreboard.currentWeekNumber || slot.seasonType != scoreboard.seasonType {
                await fetchSelectedWeek()
            } else {
                games = scoreboard.games
                lastError = nil
                cacheSelectedGames()
            }
        } catch {
            lastError = describe(error)
            Self.logger.error("initial load failed: \(error)")
        }
        startPollingIfNeeded()
        prefetchAdjacentWeeks()
    }

    func select(week: WeekSlot) async {
        guard week.id != selectedWeek?.id else { return }
        selectedWeek = week
        // Seed from the cache — the fresh fetch below still runs, and
        // stable game ids let rows refresh in place instead of blanking.
        games = weekGamesCache[week.id] ?? []
        await fetchSelectedWeek()
        startPollingIfNeeded()
        prefetchAdjacentWeeks()
    }

    /// The preview pane's data: what the cache holds for a strip slot,
    /// nil before its prefetch lands.
    func cachedGames(for week: WeekSlot) -> [Game]? {
        weekGamesCache[week.id]
    }

    /// Warm the swipe's ±1 targets so a drag shows the real slate. One
    /// fetch per uncached neighbor, never polled — a preview can sit
    /// slightly stale until its commit refreshes it (the polite-guest
    /// trade). Safe to call repeatedly; warm and in-flight slots no-op.
    func prefetchAdjacentWeeks() {
        for offset in [-1, 1] {
            guard let target = adjacentWeek(offset: offset),
                  weekGamesCache[target.id] == nil,
                  !prefetching.contains(target.id) else { continue }
            prefetching.insert(target.id)
            let season = seasonYear
            let override = seasonOverride
            Task { [weak self] in
                guard let self else { return }
                defer { prefetching.remove(target.id) }
                guard let scoreboard = try? await client.scoreboard(
                    weekValue: target.value, seasonType: target.seasonType, year: override)
                else { return }
                // A season switch mid-flight would file this under a
                // colliding key; drop it.
                guard seasonYear == season else { return }
                weekGamesCache[target.id] = scoreboard.games
            }
        }
    }

    /// File the on-screen games under the selected slot's cache key. The
    /// cache is observed (the swipe preview reads it), so a no-change poll
    /// tick must not rewrite the entry.
    private func cacheSelectedGames() {
        guard let id = selectedWeek?.id, weekGamesCache[id] != games else { return }
        weekGamesCache[id] = games
    }

    /// Jump home to where live games happen: the current season's
    /// rollover-default week (the Live toggle's landing, Andy 2026-08-29).
    /// A past season goes back through the season switch so the rollover
    /// rule reapplies; the current season just selects the slot. No-op
    /// when already there or before the first load.
    func selectCurrentWeek() async {
        if let currentSeasonYear, seasonYear != currentSeasonYear {
            await select(season: currentSeasonYear)
        } else if let currentWeekSlot {
            await select(week: currentWeekSlot)
        }
    }

    /// The strip slot `offset` steps from the selected week — the swipe
    /// gesture's target. Nil past either end of the season and before the
    /// first load, so a swipe there is a quiet no-op.
    func adjacentWeek(offset: Int) -> WeekSlot? {
        guard let selectedWeek,
              let index = weeks.firstIndex(where: { $0.id == selectedWeek.id })
        else { return nil }
        let target = index + offset
        guard weeks.indices.contains(target) else { return nil }
        return weeks[target]
    }

    /// Switch seasons. The current year goes back through the initial-load
    /// path so the Sunday rollover rule reapplies; past years land on the
    /// season's final slot — a finished season's state is its conclusion.
    func select(season year: Int) async {
        guard year != seasonYear else { return }
        stopPolling()
        seasonYear = year
        seasonOverride = year == currentSeasonYear ? nil : year
        weeks = []
        games = []
        selectedWeek = nil
        // The cache key carries no year — a season switch must start clean.
        weekGamesCache = [:]
        prefetching = []
        if let year = seasonOverride {
            await loadSeason(year)
            startPollingIfNeeded()
        } else {
            await loadInitial()
        }
    }

    /// Load a past season: anchor on regular-season week 1 (always exists —
    /// a bare `dates=` request dumps the entire season) to get its calendar,
    /// then land on the last slot (the CFP).
    private func loadSeason(_ year: Int) async {
        isLoading = true
        defer { isLoading = false }
        do {
            let scoreboard = try await client.scoreboard(weekValue: 1, seasonType: 2, year: year)
            weeks = scoreboard.weeks
            seasonYear = scoreboard.seasonYear ?? year
            // No current week in a finished season: defaultSelection falls
            // through to the last slot for past dates.
            let slot = WeekLogic.defaultSelection(
                in: scoreboard.weeks, currentWeekNumber: nil, seasonType: nil
            )
            selectedWeek = slot
            if let slot, slot.seasonType == 2, slot.value == 1 {
                games = scoreboard.games
                lastError = nil
                cacheSelectedGames()
            } else {
                await fetchSelectedWeek()
            }
            prefetchAdjacentWeeks()
        } catch {
            lastError = describe(error)
            Self.logger.error("season load failed: \(error)")
        }
    }

    /// Re-fetch the selected week. Games keep stable ids, so SwiftUI updates
    /// rows in place and accordion/scroll state survives.
    func refresh() async {
        if selectedWeek == nil, let year = seasonOverride {
            // A failed season switch left no week anchor; redo the switch.
            await loadSeason(year)
        } else {
            await fetchSelectedWeek()
        }
        startPollingIfNeeded()
    }

    private func fetchSelectedWeek() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let scoreboard = try await client.scoreboard(
                weekValue: selectedWeek?.value,
                seasonType: selectedWeek?.seasonType,
                year: seasonOverride
            )
            // Equality guards throughout: @Observable notifies on every
            // set, so an unconditional write here would re-render the whole
            // scores tree on each 30s poll tick even when nothing moved.
            if !scoreboard.weeks.isEmpty, weeks != scoreboard.weeks {
                weeks = scoreboard.weeks
            }
            if let year = scoreboard.seasonYear, year != seasonYear {
                seasonYear = year
            }
            if games != scoreboard.games {
                games = scoreboard.games
            }
            if lastError != nil { lastError = nil }
            cacheSelectedGames()
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
                try? await Task.sleep(for: DataProvider.pollInterval)
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

    /// Following pinned first in either grouping, each section complete on
    /// its own terms. Conference mode adds Top 25 → conferences; date mode
    /// adds one section per calendar day. The Live and slate filters
    /// collapse sections to matching games and hide the empties —
    /// "complete" means complete within the active filters.
    func sections(followingIds: Set<String>,
                  followedConferenceIds: Set<Int> = [],
                  grouping: ScoresGrouping = .conference,
                  liveOnly: Bool = false,
                  filter: ScoreFilter? = nil) -> [GameSection] {
        sections(from: games, followingIds: followingIds,
                 followedConferenceIds: followedConferenceIds,
                 grouping: grouping, liveOnly: liveOnly, filter: filter)
    }

    /// The same pipeline over any game list — the swipe's preview pane
    /// renders a cached neighbor week through it (2026-08-31).
    func sections(from games: [Game],
                  followingIds: Set<String>,
                  followedConferenceIds: Set<Int> = [],
                  grouping: ScoresGrouping = .conference,
                  liveOnly: Bool = false,
                  filter: ScoreFilter? = nil) -> [GameSection] {
        let key = SectionsKey(games: games, followingIds: followingIds,
                              followedConferenceIds: followedConferenceIds,
                              grouping: grouping, liveOnly: liveOnly, filter: filter)
        if let memoized = sectionsMemo[key] { return memoized }

        var visible = liveOnly ? games.filter(\.isLive) : games
        if let filter {
            visible = visible.filter(filter.matches)
        }
        // One sort up front: filters and the bucketing loops below all
        // preserve order, so every section inherits chronology from here
        // instead of re-sorting its own slice of the same games.
        visible = chronological(visible)
        var result: [GameSection] = []

        // Team follows or conference follows both claim a game; an FCS
        // visitor's nil conferenceId is carried in by its FBS host's side.
        let followed = visible.filter { game in
            followingIds.contains(game.home.team.id) || followingIds.contains(game.away.team.id)
                || game.home.team.conferenceId.map(followedConferenceIds.contains) ?? false
                || game.away.team.conferenceId.map(followedConferenceIds.contains) ?? false
        }
        if !followed.isEmpty {
            result.append(GameSection(id: GameSection.followingId, title: "Following",
                                      games: followed))
        }

        switch grouping {
        case .conference:
            result += rankedAndConferenceSections(from: visible, followingIds: followingIds,
                                                  followedConferenceIds: followedConferenceIds)
        case .date:
            result += daySections(from: visible)
        }
        // Old weeks' entries age out wholesale; the bound only exists so
        // browsing a whole season can't accumulate every slate it touched.
        if sectionsMemo.count >= 8 { sectionsMemo.removeAll() }
        sectionsMemo[key] = result
        return result
    }

    /// Top 25 → conferences, the default stack below Following. Expects
    /// `visible` already chronological; every bucket preserves that order.
    private func rankedAndConferenceSections(from visible: [Game],
                                             followingIds: Set<String>,
                                             followedConferenceIds: Set<Int>) -> [GameSection] {
        var result: [GameSection] = []
        let ranked = visible.filter(\.involvesRankedTeam)
        if !ranked.isEmpty {
            result.append(GameSection(id: GameSection.top25Id, title: "Top 25",
                                      games: ranked))
        }

        // A cross-conference game lands in both conferences' sections.
        // "Other" (the nil key) is a last resort for games no section can
        // claim — an FCS visitor at an FBS school stays in the host's
        // conference only, or Week 1's ~48 FCS matchups would pile up in
        // Other as duplicates.
        var byConference: [Int?: [Game]] = [:]
        for game in visible {
            let known = Set([game.home.team.conferenceId, game.away.team.conferenceId]
                .compactMap { id in Conference.tier(for: id) == .other ? nil : id })
            if known.isEmpty {
                byConference[nil, default: []].append(game)
            } else {
                for id in known {
                    byConference[id, default: []].append(game)
                }
            }
        }
        // A followed team's conference floats to the top — as does an
        // explicitly followed conference; then P4 → G5 → Independents →
        // Other.
        let floatedConferenceIds = Set(visible.flatMap { [$0.home, $0.away] }
            .filter { followingIds.contains($0.team.id) }
            .compactMap(\.team.conferenceId))
            .union(followedConferenceIds)
        let orderedIds = byConference.keys.sorted { lhs, rhs in
            let (lf, rf) = (lhs.map(floatedConferenceIds.contains) ?? false,
                            rhs.map(floatedConferenceIds.contains) ?? false)
            if lf != rf { return lf }
            let (lt, rt) = (Conference.tier(for: lhs), Conference.tier(for: rhs))
            return lt == rt ? Conference.name(for: lhs) < Conference.name(for: rhs) : lt < rt
        }
        for id in orderedIds {
            let name = Conference.name(for: id)
            result.append(GameSection(id: "conf-\(name)", title: name,
                                      games: byConference[id] ?? [],
                                      logoURL: Conference.logoURL(for: id),
                                      isConference: true,
                                      conferenceId: id))
        }
        return result
    }

    /// One section per local calendar day; games with no kickoff date land
    /// in a trailing "TBD" section. Expects `visible` already chronological
    /// (the day buckets preserve it). Ids come from local date components
    /// (not ISO8601, whose UTC default would mis-bucket late kicks) so
    /// expansion state keys stay stable.
    private func daySections(from visible: [Game]) -> [GameSection] {
        let calendar = Calendar.current
        var byDay: [Date: [Game]] = [:]
        var undated: [Game] = []
        for game in visible {
            if let date = game.date {
                byDay[calendar.startOfDay(for: date), default: []].append(game)
            } else {
                undated.append(game)
            }
        }
        var result: [GameSection] = byDay.keys.sorted().map { day in
            let parts = calendar.dateComponents([.year, .month, .day], from: day)
            let id = String(format: "%@%04d-%02d-%02d", GameSection.dayPrefix,
                            parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
            return GameSection(id: id,
                               title: day.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()),
                               games: byDay[day] ?? [])
        }
        if !undated.isEmpty {
            result.append(GameSection(id: GameSection.tbdDayId, title: "TBD",
                                      games: undated))
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
