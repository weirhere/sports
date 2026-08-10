import Foundation
import Testing
@testable import StatSide

@MainActor
@Suite struct UIStateStoreTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "UIStateStoreTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func daySectionsStartExpandedAndToggleInverts() {
        let store = UIStateStore(defaults: makeDefaults())
        let dayId = "\(GameSection.dayPrefix)2026-08-29"

        // Inverse semantics: unknown day ids are expanded; unknown
        // conference-style ids are collapsed.
        #expect(store.isExpanded(dayId))
        #expect(!store.isExpanded("conf-SEC"))

        store.toggle(dayId)
        #expect(!store.isExpanded(dayId))
        store.expand(dayId)
        #expect(store.isExpanded(dayId))
    }

    @Test func collapsedDaysPersistAcrossInstances() {
        let defaults = makeDefaults()
        let dayId = "\(GameSection.dayPrefix)2026-08-29"
        UIStateStore(defaults: defaults).toggle(dayId)

        let reloaded = UIStateStore(defaults: defaults)
        #expect(!reloaded.isExpanded(dayId))
        // Day state routes through collapsedDays, never expandedSections.
        #expect(!reloaded.expandedSections.contains(dayId))
    }

    @Test func expandConferenceForcesOpenAndPersists() {
        let defaults = makeDefaults()
        let store = UIStateStore(defaults: defaults)
        let sectionId = "teams.conf.8"

        // Idempotent when already open (Teams cards start expanded).
        store.expandConference(sectionId)
        #expect(!store.isConferenceCollapsed(sectionId))

        store.toggleConference(sectionId)
        #expect(store.isConferenceCollapsed(sectionId))
        store.expandConference(sectionId)
        #expect(!store.isConferenceCollapsed(sectionId))
        #expect(!UIStateStore(defaults: defaults).isConferenceCollapsed(sectionId))
    }

    @Test func scoresGroupingRoundTripsAndDefaultsToConference() {
        let defaults = makeDefaults()
        let store = UIStateStore(defaults: defaults)
        #expect(store.scoresGrouping == .conference)

        store.scoresGrouping = .date
        #expect(UIStateStore(defaults: defaults).scoresGrouping == .date)
    }
}
