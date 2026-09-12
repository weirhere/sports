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
    /// Persisted (Andy, 2026-08-29): "you should be able to customize it to
    /// the way you want it and keep it" — the permanent chip and the
    /// explanatory empty state make a saved filter legible on a quiet
    /// Tuesday.
    var liveOnly: Bool {
        didSet { defaults.set(liveOnly, forKey: Self.liveOnlyKey) }
    }

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

    /// The Scores slate filter. Persisted like `liveOnly` (same call,
    /// superseding the session-only first cut); the funnel chip's label
    /// keeps a saved filter visible.
    var scoreFilter: ScoreFilter? {
        didSet {
            if let scoreFilter {
                defaults.set(scoreFilter.token, forKey: Self.scoreFilterKey)
            } else {
                defaults.removeObject(forKey: Self.scoreFilterKey)
            }
        }
    }

    private static let followPromptDismissedKey = "ui.followPromptDismissed"
    private static let liveOnlyKey = "ui.liveOnly"
    private static let scoreFilterKey = "ui.scoreFilter"

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
        followPromptDismissed = defaults.bool(forKey: Self.followPromptDismissedKey)
        liveOnly = defaults.bool(forKey: Self.liveOnlyKey)
        scoreFilter = defaults.string(forKey: Self.scoreFilterKey)
            .flatMap(ScoreFilter.init(token:))
        pollChoice = defaults.string(forKey: Self.pollChoiceKey)
    }

    func isExpanded(_ sectionId: String) -> Bool {
        if Self.defaultsOpen(sectionId) {
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
    /// seeded open on first run.
    private static func defaultsOpen(_ sectionId: String) -> Bool {
        [GameSection.leaguePrefix, GameSection.conferencePrefix,
         GameSection.pollPrefix, GameSection.otherPrefix]
            .contains { sectionId.hasPrefix($0) }
    }

    func toggle(_ sectionId: String) {
        if Self.defaultsOpen(sectionId) {
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

    func expand(_ sectionId: String) {
        if Self.defaultsOpen(sectionId) {
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
    func collapseAll(_ sectionIds: [String]) {
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

    func expandAll(_ sectionIds: [String]) {
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
    private func partition(_ sectionIds: [String]) -> (dayIds: Set<String>, otherIds: Set<String>) {
        var dayIds = Set<String>()
        var otherIds = Set<String>()
        for id in sectionIds {
            if Self.defaultsOpen(id) {
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
