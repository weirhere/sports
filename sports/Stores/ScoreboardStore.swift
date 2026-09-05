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
    /// League-qualified: group id 8 is the SEC in college football and the
    /// AFC in the NFL, so a bare id can't name a slate.
    case conference(ConferenceID)

    /// UserDefaults spelling — "top25" or "conference-8".
    var token: String {
        switch self {
        case .top25: "top25"
        case .conference(let id): "conference-\(id.token)"
        }
    }

    /// Pure parsing, and `UIStateStore.init` reaches it as an unapplied
    /// function reference (`flatMap(ScoreFilter.init(token:))`) — which
    /// is a nonisolated context, so the default MainActor isolation has
    /// to come off.
    nonisolated init?(token: String) {
        if token == "top25" {
            self = .top25
        } else if token.hasPrefix("conference-"),
                  // A bare id is a pre-league token and reads as college
                  // football; `ConferenceID.init(token:)` handles both.
                  let id = ConferenceID(token: String(token.dropFirst("conference-".count))) {
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
        guard case .conference(let id) = self, id.league == .collegeFootball else { return label }
        switch id.id {
        case 12: return "C-USA"
        case 17: return "MWC"
        case 18: return "Indep."
        default: return label
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
            game.home.team.conference == id || game.away.team.conference == id
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
    /// The league-qualified group, set only on conference sections with a
    /// known conference — it's what the header's standings link navigates
    /// with. Qualified because group id 8 is the SEC in college football
    /// and the AFC in the NFL.
    var conference: ConferenceID? = nil
}

@Observable
final class ScoreboardStore {
    private static let logger = Logger(subsystem: "com.andyryanweir.sports", category: "scoreboard")

    private let client: any ScoresProviding

    /// The league this store answers for. One store per league; the Scores
    /// header picks which one is on screen.
    let league: League

    private(set) var weeks: [WeekSlot] = []
    private(set) var selectedWeek: WeekSlot?
    /// The current season's rollover-default slot — where live games
    /// happen, and the Live toggle's jump-home target. Stays anchored to
    /// the current season while browsing past ones.
    private(set) var currentWeekSlot: WeekSlot?
    private(set) var games: [Game] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    /// Which divisions the slate covers. FBS alone unless someone opts
    /// into FCS (E8 scope (b), Andy 2026-09-01) — the second request is
    /// what the polite-guest rule is spending, so it only exists while
    /// FCS is actually surfaced. The filter sheet drives this; until that
    /// item lands it is always `[.fbs]`, which is what the app fetched
    /// before E8.
    private(set) var divisions: Set<Conference.Division> = [.fbs]

    /// The cache key: week slot plus the divisions that produced it. A
    /// week fetched as FBS-only and a week fetched as a union are
    /// different slates under the same `WeekSlot.id`, and the swipe
    /// preview reads straight out of here.
    private func cacheKey(_ slotId: String) -> String {
        "\(slotId)#\(divisions.map { String($0.groupId) }.sorted().joined(separator: "+"))"
    }

    /// This season's fetched weeks, keyed by `cacheKey(_:)`. The key spells
    /// "seasonType-value#groups" with no year, so the season switch clears
    /// the whole cache. Feeds the swipe's preview pane and seeds a selected
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
        let followedConferenceIds: Set<ConferenceID>
        let grouping: ScoresGrouping
        let liveOnly: Bool
        let filter: ScoreFilter?
        let divisions: Set<Conference.Division>
        let extraFollowingGames: [Game]
    }

    /// The season on screen.
    private(set) var seasonYear: Int?
    /// ESPN's "now" season, captured on first load. Tops the picker range
    /// and marks which year needs no `dates=` override.
    private(set) var currentSeasonYear: Int?


    @ObservationIgnored private var pollTask: Task<Void, Never>?
    /// Non-nil while browsing a past season; forwarded on every fetch.
    @ObservationIgnored private var seasonOverride: Int?

    init(league: League = .collegeFootball,
         client: (any ScoresProviding)? = nil) {
        self.league = league
        self.client = client ?? DataProvider.makeClient(league: league)
    }

    /// Whether the strip is on the current season's rollover-default week
    /// — the "now" slot. Cross-league Following only fills in here: past
    /// weeks are time navigation inside one league, and the two calendars
    /// have no honest mapping between them.
    var isOnCurrentWeek: Bool {
        guard let currentWeekSlot else { return selectedWeek == nil }
        return selectedWeek?.id == currentWeekSlot.id && seasonYear == currentSeasonYear
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
            let scoreboard = try await client.scoreboard(
                weekValue: nil, seasonType: nil, year: nil, divisions: divisions)
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
        games = weekGamesCache[cacheKey(week.id)] ?? []
        await fetchSelectedWeek()
        startPollingIfNeeded()
        prefetchAdjacentWeeks()
    }

    /// The divisions a given set of user choices needs on the slate. FBS
    /// is always there — the app's default promise — and FCS joins only
    /// when someone selected an FCS conference in the filter sheet or
    /// follows one. That "only when asked" is the whole of scope (b), and
    /// it's what keeps the 30s poll at one request for everyone else.
    nonisolated static func divisions(
        filter: ScoreFilter?, followedConferenceIds: Set<ConferenceID>
    ) -> Set<Conference.Division> {
        var needed: Set<Conference.Division> = [.fbs]
        if case .conference(let id) = filter,
           Conference.division(for: id.id, in: id.league) == .fcs {
            needed.insert(.fcs)
        }
        if followedConferenceIds.contains(where: {
            Conference.division(for: $0.id, in: $0.league) == .fcs
        }) {
            needed.insert(.fcs)
        }
        return needed
    }

    /// Widen or narrow the slate's divisions. Async and explicit rather
    /// than a settable property, because the selected week has to be
    /// refetched: clearing the cache alone would leave the FBS-only slate
    /// on screen with no request in flight to replace it.
    func select(divisions newValue: Set<Conference.Division>) async {
        guard newValue != divisions, !newValue.isEmpty else { return }
        divisions = newValue
        // The narrower slate must never stand in for the wider one, so
        // every entry goes — cache keys carry the divisions that made them,
        // but the in-flight prefetches don't.
        weekGamesCache = [:]
        prefetching = []
        await fetchSelectedWeek()
        startPollingIfNeeded()
        prefetchAdjacentWeeks()
    }

    /// The preview pane's data: what the cache holds for a strip slot,
    /// nil before its prefetch lands.
    func cachedGames(for week: WeekSlot) -> [Game]? {
        weekGamesCache[cacheKey(week.id)]
    }

    /// Warm the swipe's ±1 targets so a drag shows the real slate. One
    /// fetch per uncached neighbor, never polled — a preview can sit
    /// slightly stale until its commit refreshes it (the polite-guest
    /// trade). Safe to call repeatedly; warm and in-flight slots no-op.
    func prefetchAdjacentWeeks() {
        for offset in [-1, 1] {
            guard let target = adjacentWeek(offset: offset) else { continue }
            let key = cacheKey(target.id)
            guard weekGamesCache[key] == nil, !prefetching.contains(key) else { continue }
            prefetching.insert(key)
            let season = seasonYear
            let override = seasonOverride
            let groups = divisions
            Task { [weak self] in
                guard let self else { return }
                defer { prefetching.remove(key) }
                guard let scoreboard = try? await client.scoreboard(
                    weekValue: target.value, seasonType: target.seasonType,
                    year: override, divisions: groups)
                else { return }
                // A season or division switch mid-flight would file this
                // under a colliding key; drop it.
                guard seasonYear == season, divisions == groups else { return }
                weekGamesCache[key] = scoreboard.games
            }
        }
    }

    /// File the on-screen games under the selected slot's cache key. The
    /// cache is observed (the swipe preview reads it), so a no-change poll
    /// tick must not rewrite the entry.
    private func cacheSelectedGames() {
        guard let id = selectedWeek.map({ cacheKey($0.id) }),
              weekGamesCache[id] != games else { return }
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
            let scoreboard = try await client.scoreboard(
                weekValue: 1, seasonType: 2, year: year, divisions: divisions)
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
                year: seasonOverride,
                divisions: divisions
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

    /// The groups in flight, for the poll log. A union doubles every tick
    /// into two requests, so the Saturday log archive has to say which
    /// ones it was (E8's polling-budget item).
    private var groupsLabel: String {
        divisions.map { String($0.groupId) }.sorted().joined(separator: "+")
    }

    private func describe(_ error: Error) -> String {
        if error is DecodingError { return "Couldn't read the scoreboard." }
        return "Couldn't reach the scoreboard."
    }

    // MARK: - Polling
    // 30s auto-poll, only while the scene is active and ≥1 game is live.

    func startPollingIfNeeded() {
        guard pollTask == nil, hasLiveGames else { return }
        Self.logger.info("polling: started (groups \(self.groupsLabel))")
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: DataProvider.pollInterval)
                guard !Task.isCancelled, let self else { return }
                guard self.hasLiveGames else {
                    Self.logger.info("polling: stopped (no live games)")
                    self.pollTask = nil
                    return
                }
                Self.logger.info("polling: tick (groups \(self.groupsLabel))")
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
                  followedConferenceIds: Set<ConferenceID> = [],
                  grouping: ScoresGrouping = .conference,
                  liveOnly: Bool = false,
                  filter: ScoreFilter? = nil,
                  extraFollowingGames: [Game] = []) -> [GameSection] {
        sections(from: games, followingIds: followingIds,
                 followedConferenceIds: followedConferenceIds,
                 grouping: grouping, liveOnly: liveOnly, filter: filter,
                 extraFollowingGames: extraFollowingGames)
    }

    /// The same pipeline over any game list — the swipe's preview pane
    /// renders a cached neighbor week through it (2026-08-31).
    /// `extraFollowingGames` are followed games from the *other* leagues.
    /// They join the Following section and nothing else — "my games"
    /// shouldn't care which sport they belong to, but the Top 25, the
    /// conference stack and the day sections all belong to this league's
    /// slate. Filters apply to them the same way, except the conference
    /// filter, which is a college-football-shaped question that another
    /// league can't answer.
    func sections(from games: [Game],
                  followingIds: Set<String>,
                  followedConferenceIds: Set<ConferenceID> = [],
                  grouping: ScoresGrouping = .conference,
                  liveOnly: Bool = false,
                  filter: ScoreFilter? = nil,
                  extraFollowingGames: [Game] = []) -> [GameSection] {
        // `divisions` is in the key because the bucketing loop reads it:
        // the same games opted into FCS produce different sections.
        let key = SectionsKey(games: games, followingIds: followingIds,
                              followedConferenceIds: followedConferenceIds,
                              grouping: grouping, liveOnly: liveOnly, filter: filter,
                              divisions: divisions, extraFollowingGames: extraFollowingGames)
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
        func isFollowed(_ game: Game) -> Bool {
            followingIds.contains(game.home.team.followKey)
                || followingIds.contains(game.away.team.followKey)
                || game.home.team.conference.map(followedConferenceIds.contains) ?? false
                || game.away.team.conference.map(followedConferenceIds.contains) ?? false
        }
        var followed = visible.filter(isFollowed)
        // Other leagues' followed games join here and nowhere else. Live
        // composes; the conference filter deliberately doesn't, since
        // "SEC" has no meaning in another league's slate — narrowing to a
        // conference is a college-football question, and it would silently
        // empty the section otherwise.
        if !extraFollowingGames.isEmpty {
            var elsewhere = extraFollowingGames.filter(isFollowed)
            if liveOnly { elsewhere = elsewhere.filter(\.isLive) }
            if case .top25 = filter { elsewhere = elsewhere.filter(\.involvesRankedTeam) }
            followed = chronological(followed + elsewhere)
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
                                             followedConferenceIds: Set<ConferenceID>) -> [GameSection] {
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
        //
        // Sections follow the slate's divisions, not the registry's
        // knowledge: FCS is opt-in (scope (b)), so until someone asks for
        // it a Big Sky visitor at an FBS school stays in the host's
        // section rather than spawning a Big Sky one.
        var byConference: [ConferenceID?: [Game]] = [:]
        for game in visible {
            let known = Set([game.home.team.conference, game.away.team.conference]
                .compactMap { conference -> ConferenceID? in
                    guard let conference else { return nil }
                    // The NFL has no divisions to opt into, so every known
                    // group qualifies; college football gates on the slate.
                    if conference.league != .collegeFootball {
                        return Conference.isKnown(conference.id, in: conference.league)
                            ? conference : nil
                    }
                    return Conference.division(for: conference.id, in: conference.league)
                        .map(divisions.contains) == true ? conference : nil
                })
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
            .filter { followingIds.contains($0.team.followKey) }
            .compactMap(\.team.conference))
            .union(followedConferenceIds)
        let orderedIds = byConference.keys.sorted { lhs, rhs in
            let (lf, rf) = (lhs.map(floatedConferenceIds.contains) ?? false,
                            rhs.map(floatedConferenceIds.contains) ?? false)
            if lf != rf { return lf }
            let (lt, rt) = (Conference.tier(for: lhs?.id, in: lhs?.league ?? league),
                            Conference.tier(for: rhs?.id, in: rhs?.league ?? league))
            return lt == rt
                ? Conference.name(for: lhs) < Conference.name(for: rhs)
                : lt < rt
        }
        for id in orderedIds {
            let name = Conference.name(for: id)
            result.append(GameSection(id: "conf-\(name)", title: name,
                                      games: byConference[id] ?? [],
                                      logoURL: Conference.logoURL(for: id),
                                      isConference: true,
                                      conference: id))
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
