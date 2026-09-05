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

    @Test func collapseAllAndExpandAllHandleMixedSemantics() {
        let store = UIStateStore(defaults: makeDefaults())
        let dayId = "\(GameSection.dayPrefix)2026-08-29"
        let ids = [GameSection.followingId, "conf-SEC", dayId, GameSection.tbdDayId]

        store.collapseAll(ids)
        for id in ids {
            #expect(!store.isExpanded(id))
        }
        // Day ids route through collapsedDays, never expandedSections;
        // Following (open by default) actually left expandedSections.
        #expect(store.collapsedDays.contains(dayId))
        #expect(!store.expandedSections.contains(dayId))
        #expect(!store.expandedSections.contains(GameSection.followingId))

        store.expandAll(ids)
        for id in ids {
            #expect(store.isExpanded(id))
        }
        #expect(!store.collapsedDays.contains(dayId))
    }

    @Test func bulkOpsPersistAcrossInstances() {
        let defaults = makeDefaults()
        let dayId = "\(GameSection.dayPrefix)2026-08-29"
        UIStateStore(defaults: defaults).collapseAll(["conf-SEC", dayId, GameSection.top25Id])

        let reloaded = UIStateStore(defaults: defaults)
        #expect(!reloaded.isExpanded("conf-SEC"))
        #expect(!reloaded.isExpanded(dayId))
        #expect(!reloaded.isExpanded(GameSection.top25Id))
    }

    @Test func bulkOpsAreIdempotentAndScoped() {
        let store = UIStateStore(defaults: makeDefaults())

        // Only the passed ids move; Top 25 stays open by default.
        store.collapseAll(["conf-SEC"])
        store.collapseAll(["conf-SEC"])
        #expect(!store.isExpanded("conf-SEC"))
        #expect(store.isExpanded(GameSection.top25Id))

        store.expandAll([])
        store.collapseAll([])
        #expect(store.isExpanded(GameSection.top25Id))
    }

    @Test func filtersPersistAndDefaultToOff() {
        let defaults = makeDefaults()
        let store = UIStateStore(defaults: defaults)
        #expect(store.liveOnly == false)
        #expect(store.scoreFilter == nil)

        store.liveOnly = true
        store.scoreFilter = .conference(.cfb(8))
        let reloaded = UIStateStore(defaults: defaults)
        #expect(reloaded.liveOnly == true)
        #expect(reloaded.scoreFilter == .conference(.cfb(8)))

        reloaded.scoreFilter = .top25
        #expect(UIStateStore(defaults: defaults).scoreFilter == .top25)
        reloaded.scoreFilter = nil
        #expect(UIStateStore(defaults: defaults).scoreFilter == nil)
    }

    @Test func scoresGroupingRoundTripsAndDefaultsToDate() {
        let defaults = makeDefaults()
        let store = UIStateStore(defaults: defaults)
        #expect(store.scoresGrouping == .date)

        store.scoresGrouping = .conference
        #expect(UIStateStore(defaults: defaults).scoresGrouping == .conference)
    }
}
