import Foundation
import Observation

@Observable
final class UIStateStore {
    private static let expandedKey = "ui.expandedSections"
    private static let collapsedConferencesKey = "ui.collapsedConferences"
    private static let collapsedDaysKey = "ui.collapsedDays"
    private static let pollChoiceKey = "ui.pollChoice"

    /// Section ids currently expanded. Following + Top 25 start open on
    /// first launch; conference state persists across launches.
    private(set) var expandedSections: Set<String>

    /// Conference cards collapsed on the Teams browse screen. Inverse
    /// semantics from `expandedSections`: everything starts open there,
    /// so absence means expanded.
    private(set) var collapsedConferences: Set<String>

    /// Scores sections that start open and are remembered when closed —
    /// the league and conference accordions, the day sections before them
    /// (same key, same inverse semantics as `collapsedConferences`). A
    /// section whose games you never want to see is a choice worth
    /// keeping; one you have never touched should be showing.
    private(set) var collapsedDays: Set<String>

    /// Whether the Scores follow-prompt card was dismissed. Stored (not a
    /// passthrough) so the card leaves the screen the moment it's tapped.
    var followPromptDismissed: Bool {
        didSet { defaults.set(followPromptDismissed, forKey: Self.followPromptDismissedKey) }
    }

    /// The Scores Live toggle — the remembered *intent*, which is not
    /// always what the slate on screen is narrowed by. Anywhere a day is in
    /// hand, read it through `liveOnly(on:)` instead.
    ///
    /// Session-only (Josh Vertucci via Andy, 2026-10-22, superseding the
    /// 2026-08-29 persistence call): "Live" is a question about right now,
    /// and a fresh launch answers it fresh, the way FotMob does. A Live
    /// left on after Saturday's last whistle used to greet Tuesday with
    /// "No live games right now". The funnel filter is a preference and
    /// still persists — `scoreFilter` below.
    var liveOnly: Bool {
        didSet {
            if liveOnly, tightOnly { tightOnly = false }
        }
    }

    /// The Scores Tight toggle (Coard Miller, 2026-09-24): live games that
    /// are late and close, or where the underdog leads. `GameCloseness`
    /// holds the rule. Session-only and suspended off today exactly like
    /// `liveOnly`, and the two are exclusive, since Tight is already a
    /// narrower Live. Turning one on turns the other off.
    var tightOnly: Bool {
        didSet {
            if tightOnly, liveOnly { liveOnly = false }
        }
    }

    /// Whether the Tight filter is narrowing `day` — `liveOnly(on:)`'s rule.
    func tightOnly(on day: Date, calendar: Calendar = .current) -> Bool {
        self.tightOnly && calendar.isDateInToday(day)
    }

    /// Either filter that narrows the slate to what's happening now, which
    /// is what renames today "Ongoing" on the strip and the Today button.
    var narrowsToNow: Bool { liveOnly || tightOnly }

    /// Whether the Live filter is actually narrowing `day`: the toggle is
    /// on *and* the day is today (Andy, 2026-09-12).
    ///
    /// "Live" is a question about right now, and today is the only day that
    /// can answer it — on tomorrow the filter guarantees an empty screen,
    /// and on yesterday it hides every result the day exists to show. So a
    /// swipe off today suspends the filter and a swipe back restores it,
    /// with the chip following. Suspended, never forgotten: the intent
    /// stays in `liveOnly`, which is what makes coming home turn it back on
    /// rather than leaving the user to.
    func liveOnly(on day: Date, calendar: Calendar = .current) -> Bool {
        // `self.` for the reader, not the compiler: the stored intent and
        // this rule share a base name on purpose, so every call site says
        // which one it means.
        self.liveOnly && calendar.isDateInToday(day)
    }

    /// The Scores slate filter. Persisted (Andy, 2026-08-29, superseding
    /// the session-only first cut): "you should be able to customize it to
    /// the way you want it and keep it" — "SEC" is how you want the slate
    /// every day, and the funnel chip's label keeps a saved filter visible.
    /// Live and Tight stopped persisting on 2026-10-22; this did not.
    var scoreFilter: ScoreFilter? {
        didSet {
            if let scoreFilter {
                defaults.set(scoreFilter.token, forKey: Self.scoreFilterKey)
            } else {
                defaults.removeObject(forKey: Self.scoreFilterKey)
            }
        }
    }

    /// The Hide all/Show all control's state: true collapses every Scores
    /// section that isn't Following or a followed table to the one-line
    /// control, false shows the full stack. Persisted like `scoreFilter`
    /// (Andy, 2026-09-22) — a crowded slate you've hidden once
    /// should stay hidden until you ask to see it again, not reopen itself
    /// on the next launch.
    var hideOtherSections: Bool {
        didSet { defaults.set(hideOtherSections, forKey: Self.hideOtherSectionsKey) }
    }

    /// Whether betting lines show at all — the spread and total on
    /// pre-game Scores rows and in the game page's Game info. Off by
    /// default (Coard Miller, 2026-09-24: "just a toggle… might be frowned
    /// upon"); switched on in Settings. The Tight filter reads the line
    /// whatever this says, because it never prints it.
    var showsLines: Bool {
        didSet { defaults.set(showsLines, forKey: Self.showsLinesKey) }
    }

    /// Light, dark, or whatever the iPhone says (the default). Read once in
    /// `init`, so a UI test can pin it with `-ui.appearance system`.
    var appearance: Appearance {
        didSet { defaults.set(appearance.rawValue, forKey: Self.appearanceKey) }
    }

    /// Whether the game page's Starters section draws the field or the
    /// list cards (Andy, 2026-10-18). One choice for every league — the
    /// preference is about the picture, not the sport. Read once in
    /// `init`, so a UI test can pin it with `-ui.startersLayout field`.
    var startersLayout: StartersLayout {
        didSet { defaults.set(startersLayout.rawValue, forKey: Self.startersLayoutKey) }
    }

    /// How each league's Scores slate is broken down (Andy, 2026-10-03).
    /// Only choices that differ from the default are stored, so a league
    /// without an entry follows `SlateGrouping.defaultValue(for:)`. Read
    /// once in `init`.
    private(set) var slateGroupings: [League: SlateGrouping] {
        didSet {
            defaults.set(Dictionary(uniqueKeysWithValues: slateGroupings.map { ($0.key.rawValue, $0.value.rawValue) }),
                         forKey: Self.slateGroupingKey)
        }
    }

    func grouping(for league: League) -> SlateGrouping {
        slateGroupings[league] ?? .defaultValue(for: league)
    }

    func setGrouping(_ grouping: SlateGrouping, for league: League) {
        guard SlateGrouping.options(for: league).contains(grouping) else { return }
        slateGroupings[league] = grouping == .defaultValue(for: league) ? nil : grouping
    }

    /// Every league's grouping, defaults filled in — what the sections
    /// pipeline is a function of.
    var resolvedGroupings: [League: SlateGrouping] {
        Dictionary(uniqueKeysWithValues: League.allCases.map { ($0, grouping(for: $0)) })
    }

    /// Followed teams kept off the News tab's For you (Andy, 2026-10-19):
    /// the sheet's unchecked rows, by follow key. The follow itself is
    /// untouched; a team unfollowed later just stops being consulted.
    private(set) var newsHiddenTeams: Set<String> {
        didSet { defaults.set(newsHiddenTeams.sorted(), forKey: Self.newsHiddenTeamsKey) }
    }

    func isShownInNews(_ key: String) -> Bool { !newsHiddenTeams.contains(key) }

    func setShownInNews(_ shown: Bool, for key: String) {
        if shown { newsHiddenTeams.remove(key) } else { newsHiddenTeams.insert(key) }
    }

    private static let newsHiddenTeamsKey = "news.hiddenTeams"
    private static let slateGroupingKey = "ui.slateGrouping"
    private static let showsLinesKey = "lines.enabled"
    private static let appearanceKey = "ui.appearance"
    private static let startersLayoutKey = "ui.startersLayout"
    private static let followPromptDismissedKey = "ui.followPromptDismissed"
    /// Live and Tight's old persistence keys. No longer written; `init`
    /// clears what an earlier build saved, and in DEBUG reads them once
    /// from the argument domain so a fixture suite can launch on a live
    /// slate (`-ui.liveOnly YES`).
    private static let liveOnlyKey = "ui.liveOnly"
    private static let tightOnlyKey = "ui.tightOnly"
    private static let scoreFilterKey = "ui.scoreFilter"
    private static let hideOtherSectionsKey = "ui.hideOtherSections"

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.stringArray(forKey: Self.expandedKey) {
            expandedSections = Set(saved)
        } else {
            expandedSections = [GameSection.followingId]
        }
        collapsedConferences = Set(defaults.stringArray(forKey: Self.collapsedConferencesKey) ?? [])
        collapsedDays = Set(defaults.stringArray(forKey: Self.collapsedDaysKey) ?? [])
        newsHiddenTeams = Set(defaults.stringArray(forKey: Self.newsHiddenTeamsKey) ?? [])
        followPromptDismissed = defaults.bool(forKey: Self.followPromptDismissedKey)
        // Live and Tight start off on every launch (2026-10-22). A value
        // written by a build that persisted them is cleared here, before
        // the read below, so it can't come back on a DEBUG build either.
        defaults.removeObject(forKey: Self.liveOnlyKey)
        defaults.removeObject(forKey: Self.tightOnlyKey)
        #if DEBUG
        // Only the argument domain can answer now: the UI-test hook for
        // launching on a live slate. Exclusive by construction; Live wins.
        let launchLive = defaults.bool(forKey: Self.liveOnlyKey)
        liveOnly = launchLive
        tightOnly = defaults.bool(forKey: Self.tightOnlyKey) && !launchLive
        #else
        liveOnly = false
        tightOnly = false
        #endif
        scoreFilter = defaults.string(forKey: Self.scoreFilterKey)
            .flatMap(ScoreFilter.init(token:))
        hideOtherSections = defaults.bool(forKey: Self.hideOtherSectionsKey)
        showsLines = defaults.bool(forKey: Self.showsLinesKey)
        appearance = defaults.string(forKey: Self.appearanceKey)
            .flatMap(Appearance.init(rawValue:)) ?? .system
        pollChoice = defaults.string(forKey: Self.pollChoiceKey)
        startersLayout = defaults.string(forKey: Self.startersLayoutKey)
            .flatMap(StartersLayout.init(rawValue:)) ?? .field
        var groupings: [League: SlateGrouping] = [:]
        for (raw, value) in defaults.dictionary(forKey: Self.slateGroupingKey) ?? [:] {
            guard let league = League(rawValue: raw),
                  let grouping = (value as? String).flatMap(SlateGrouping.init(rawValue:)),
                  SlateGrouping.options(for: league).contains(grouping)
            else { continue }
            groupings[league] = grouping
        }
        slateGroupings = groupings
    }

    func isExpanded(_ section: GameSection) -> Bool {
        isExpanded(section.id, followed: section.isFollowed)
    }

    func isExpanded(_ sectionId: String, followed: Bool = false) -> Bool {
        if Self.defaultsOpen(sectionId, followed: followed) {
            return !collapsedDays.contains(sectionId)
        }
        return expandedSections.contains(sectionId)
    }

    /// Every Scores section except Following starts open — the screen is a
    /// day's slate, and a collapsed-by-default section would hide the whole
    /// point of the page. That covers the league accordions, the
    /// conference stack that came back under them (2026-09-06), the poll,
    /// and the "Other" bucket. Following keeps the opt-in
    /// `expandedSections` semantics it has had since launch, where it is
    /// seeded open on first run, and so do the all-FBS and all-FCS
    /// sections above the conferences (`allDivisionPrefix`), which never
    /// are: a whole division open by default would put the ACC eleven
    /// screens down.
    ///
    /// College basketball's conferences are the exception (2026-11-02):
    /// they start closed. A weeknight is ~180 Division I men's games and
    /// ~165 women's, each in two conference sections, and open by default
    /// that is seven hundred rows between NCAAF and the NFL. Its Top 25
    /// stays open, so the night's headline games are still one scroll down.
    /// A followed one is hoisted under Following and opens like any other
    /// section there (WEIR-93, 2026-11-04): that is the one conference the
    /// fan asked for, and a closed card at the top of the page reads as
    /// nothing on tonight. Its state then lives in `collapsedDays` while
    /// it is followed and falls back to `expandedSections` after.
    private static func defaultsOpen(_ sectionId: String, followed: Bool) -> Bool {
        if isCollegeBasketballConference(sectionId) { return followed }
        return [GameSection.leaguePrefix, GameSection.conferencePrefix,
                GameSection.pollPrefix, GameSection.otherPrefix]
            .contains { sectionId.hasPrefix($0) }
    }

    /// A college basketball conference section, or its "Other" bucket.
    static func isCollegeBasketballConference(_ sectionId: String) -> Bool {
        // "conf-mcbb-8": the prefix, then the conference's own token.
        if sectionId.hasPrefix(GameSection.conferencePrefix),
           let id = ConferenceID(token: String(sectionId.dropFirst(GameSection.conferencePrefix.count))) {
            return id.league.isCollege && id.league.isBasketball
        }
        if sectionId.hasPrefix(GameSection.otherPrefix),
           let league = League(rawValue: String(sectionId.dropFirst(GameSection.otherPrefix.count))) {
            return league.isCollege && league.isBasketball
        }
        return false
    }

    func toggle(_ section: GameSection) {
        toggle(section.id, followed: section.isFollowed)
    }

    func toggle(_ sectionId: String, followed: Bool = false) {
        if Self.defaultsOpen(sectionId, followed: followed) {
            if collapsedDays.contains(sectionId) {
                collapsedDays.remove(sectionId)
            } else {
                collapsedDays.insert(sectionId)
            }
            persistCollapsedDays()
            return
        }
        if expandedSections.contains(sectionId) {
            expandedSections.remove(sectionId)
        } else {
            expandedSections.insert(sectionId)
        }
        persist()
    }

    func expand(_ sectionId: String, followed: Bool = false) {
        if Self.defaultsOpen(sectionId, followed: followed) {
            guard collapsedDays.contains(sectionId) else { return }
            collapsedDays.remove(sectionId)
            persistCollapsedDays()
            return
        }
        guard !expandedSections.contains(sectionId) else { return }
        expandedSections.insert(sectionId)
        persist()
    }

    /// Bulk ops for the Scores pinch gesture. Scoped to the ids the caller
    /// passes (the sections currently on screen) so day state for other
    /// weeks is never touched. Guards keep a no-op pinch from invalidating
    /// views or rewriting defaults.
    func collapseAll(_ sections: [GameSection]) {
        collapseAll(sections.map { ($0.id, $0.isFollowed) })
    }

    func expandAll(_ sections: [GameSection]) {
        expandAll(sections.map { ($0.id, $0.isFollowed) })
    }

    func collapseAll(_ sectionIds: [String]) {
        collapseAll(sectionIds.map { ($0, false) })
    }

    func expandAll(_ sectionIds: [String]) {
        expandAll(sectionIds.map { ($0, false) })
    }

    private func collapseAll(_ sectionIds: [(id: String, followed: Bool)]) {
        let (dayIds, otherIds) = partition(sectionIds)
        if !collapsedDays.isSuperset(of: dayIds) {
            collapsedDays.formUnion(dayIds)
            persistCollapsedDays()
        }
        if !expandedSections.isDisjoint(with: otherIds) {
            expandedSections.subtract(otherIds)
            persist()
        }
    }

    private func expandAll(_ sectionIds: [(id: String, followed: Bool)]) {
        let (dayIds, otherIds) = partition(sectionIds)
        if !collapsedDays.isDisjoint(with: dayIds) {
            collapsedDays.subtract(dayIds)
            persistCollapsedDays()
        }
        if !expandedSections.isSuperset(of: otherIds) {
            expandedSections.formUnion(otherIds)
            persist()
        }
    }

    /// Defaults-open sections track collapsed state; everything else
    /// tracks expanded.
    private func partition(_ sectionIds: [(id: String, followed: Bool)]) -> (dayIds: Set<String>, otherIds: Set<String>) {
        var dayIds = Set<String>()
        var otherIds = Set<String>()
        for (id, followed) in sectionIds {
            if Self.defaultsOpen(id, followed: followed) {
                dayIds.insert(id)
            } else {
                otherIds.insert(id)
            }
        }
        return (dayIds, otherIds)
    }

    func isConferenceCollapsed(_ conferenceId: String) -> Bool {
        collapsedConferences.contains(conferenceId)
    }

    func toggleConference(_ conferenceId: String) {
        if collapsedConferences.contains(conferenceId) {
            collapsedConferences.remove(conferenceId)
        } else {
            collapsedConferences.insert(conferenceId)
        }
        defaults.set(Array(collapsedConferences).sorted(), forKey: Self.collapsedConferencesKey)
    }

    /// Force-open a Teams browse card — a search result landing on its
    /// conference needs the section visible, whatever the saved state.
    func expandConference(_ conferenceId: String) {
        guard collapsedConferences.contains(conferenceId) else { return }
        collapsedConferences.remove(conferenceId)
        defaults.set(Array(collapsedConferences).sorted(), forKey: Self.collapsedConferencesKey)
    }

    private func persist() {
        defaults.set(Array(expandedSections).sorted(), forKey: Self.expandedKey)
    }

    private func persistCollapsedDays() {
        defaults.set(Array(collapsedDays).sorted(), forKey: Self.collapsedDaysKey)
    }

    /// Stored (not a UserDefaults passthrough) so @Observable tracks the
    /// picker: the passthrough version froze the AP/Coaches chips until
    /// the screen was rebuilt.
    var pollChoice: String? {
        didSet { defaults.set(pollChoice, forKey: Self.pollChoiceKey) }
    }

    private static let onboardingSeenKey = "ui.onboardingSeen"

    /// Whether the first-launch "pick your teams" moment has been offered.
    /// Set on dismiss however it happens — skipped, swiped away, or done.
    var onboardingSeen: Bool {
        get { defaults.bool(forKey: Self.onboardingSeenKey) }
        set { defaults.set(newValue, forKey: Self.onboardingSeenKey) }
    }

    private static let notificationsPromptedKey = "ui.notificationsPrompted"

    /// Whether the one-time "get kickoff reminders?" offer after the first
    /// follow has been shown. The bell on TeamPage remains the durable path.
    var notificationsPrompted: Bool {
        get { defaults.bool(forKey: Self.notificationsPromptedKey) }
        set { defaults.set(newValue, forKey: Self.notificationsPromptedKey) }
    }
}
