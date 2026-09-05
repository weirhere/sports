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

    @Test func leagueSectionsStartExpandedAndToggleInverts() {
        let store = UIStateStore(defaults: makeDefaults())
        let leagueId = GameSection.id(for: .nfl)

        // Inverse semantics: unknown league ids are expanded; every other
        // id is collapsed until something opens it.
        #expect(store.isExpanded(leagueId))
        #expect(!store.isExpanded("conf-SEC"))

        store.toggle(leagueId)
        #expect(!store.isExpanded(leagueId))
        store.expand(leagueId)
        #expect(store.isExpanded(leagueId))
    }

    @Test func collapsedLeaguesPersistAcrossInstances() {
        let defaults = makeDefaults()
        let leagueId = GameSection.id(for: .collegeFootball)
        UIStateStore(defaults: defaults).toggle(leagueId)

        let reloaded = UIStateStore(defaults: defaults)
        #expect(!reloaded.isExpanded(leagueId))
        // League state routes through collapsedDays, never expandedSections.
        #expect(!reloaded.expandedSections.contains(leagueId))
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
        let cfbId = GameSection.id(for: .collegeFootball)
        let nflId = GameSection.id(for: .nfl)
        let ids = [GameSection.followingId, cfbId, nflId]

        store.collapseAll(ids)
        for id in ids {
            #expect(!store.isExpanded(id))
        }
        // League ids route through collapsedDays, never expandedSections;
        // Following (open by default) actually left expandedSections.
        #expect(store.collapsedDays.contains(cfbId))
        #expect(!store.expandedSections.contains(cfbId))
        #expect(!store.expandedSections.contains(GameSection.followingId))

        store.expandAll(ids)
        for id in ids {
            #expect(store.isExpanded(id))
        }
        #expect(!store.collapsedDays.contains(cfbId))
    }

    @Test func bulkOpsPersistAcrossInstances() {
        let defaults = makeDefaults()
        let leagueId = GameSection.id(for: .nfl)
        UIStateStore(defaults: defaults).collapseAll(["conf-SEC", leagueId,
                                                     GameSection.followingId])

        let reloaded = UIStateStore(defaults: defaults)
        #expect(!reloaded.isExpanded("conf-SEC"))
        #expect(!reloaded.isExpanded(leagueId))
        #expect(!reloaded.isExpanded(GameSection.followingId))
    }

    @Test func bulkOpsAreIdempotentAndScoped() {
        let store = UIStateStore(defaults: makeDefaults())
        let leagueId = GameSection.id(for: .collegeFootball)

        // Only the passed ids move; the league stays open by default.
        store.collapseAll(["conf-SEC"])
        store.collapseAll(["conf-SEC"])
        #expect(!store.isExpanded("conf-SEC"))
        #expect(store.isExpanded(leagueId))

        store.expandAll([])
        store.collapseAll([])
        #expect(store.isExpanded(leagueId))
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
}
