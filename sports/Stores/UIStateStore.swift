import Foundation
import Observation

@Observable
final class UIStateStore {
    private static let expandedKey = "ui.expandedSections"
    private static let collapsedConferencesKey = "ui.collapsedConferences"
    private static let collapsedDaysKey = "ui.collapsedDays"
    private static let groupingKey = "ui.scoresGrouping"
    private static let pollChoiceKey = "ui.pollChoice"

    /// Section ids currently expanded. Following + Top 25 start open on
    /// first launch; conference state persists across launches.
    private(set) var expandedSections: Set<String>

    /// Conference cards collapsed on the Teams browse screen. Inverse
    /// semantics from `expandedSections`: everything starts open there,
    /// so absence means expanded.
    private(set) var collapsedConferences: Set<String>

    /// Day sections collapsed in the Scores date grouping. Inverse
    /// semantics like `collapsedConferences` — days start expanded.
    private(set) var collapsedDays: Set<String>

    /// Which grouping the Scores screen uses. A stored property (not a
    /// UserDefaults passthrough) so @Observable tracks the toggle.
    var scoresGrouping: ScoresGrouping {
        didSet { defaults.set(scoresGrouping.rawValue, forKey: Self.groupingKey) }
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let saved = defaults.stringArray(forKey: Self.expandedKey) {
            expandedSections = Set(saved)
        } else {
            expandedSections = [GameSection.followingId, GameSection.top25Id]
        }
        collapsedConferences = Set(defaults.stringArray(forKey: Self.collapsedConferencesKey) ?? [])
        collapsedDays = Set(defaults.stringArray(forKey: Self.collapsedDaysKey) ?? [])
        scoresGrouping = defaults.string(forKey: Self.groupingKey)
            .flatMap(ScoresGrouping.init(rawValue:)) ?? .conference
    }

    func isExpanded(_ sectionId: String) -> Bool {
        if sectionId.hasPrefix(GameSection.dayPrefix) {
            return !collapsedDays.contains(sectionId)
        }
        return expandedSections.contains(sectionId)
    }

    func toggle(_ sectionId: String) {
        if sectionId.hasPrefix(GameSection.dayPrefix) {
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
        if sectionId.hasPrefix(GameSection.dayPrefix) {
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

    /// Day sections track collapsed state; everything else tracks expanded.
    private func partition(_ sectionIds: [String]) -> (dayIds: Set<String>, otherIds: Set<String>) {
        var dayIds = Set<String>()
        var otherIds = Set<String>()
        for id in sectionIds {
            if id.hasPrefix(GameSection.dayPrefix) {
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

    private func persist() {
        defaults.set(Array(expandedSections).sorted(), forKey: Self.expandedKey)
    }

    private func persistCollapsedDays() {
        defaults.set(Array(collapsedDays).sorted(), forKey: Self.collapsedDaysKey)
    }

    var pollChoice: String? {
        get { defaults.string(forKey: Self.pollChoiceKey) }
        set { defaults.set(newValue, forKey: Self.pollChoiceKey) }
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
