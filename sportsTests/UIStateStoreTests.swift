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

    @Test func slateSectionsStartExpandedAndToggleInverts() {
        let store = UIStateStore(defaults: makeDefaults())
        let leagueId = GameSection.id(for: .nfl)

        // Inverse semantics: every section of the day's slate is expanded
        // until something closes it. Following keeps the opt-in set it has
        // had since launch — seeded open on a fresh install, but a store
        // reading someone else's saved state can find it closed.
        #expect(store.isExpanded(leagueId))
        #expect(store.isExpanded(GameSection.conferencePrefix + ConferenceID.cfb(8).token))
        #expect(store.isExpanded(FollowedTable.poll(.collegeFootball).token))
        #expect(store.isExpanded(GameSection.otherPrefix + "cfb"))
        #expect(!store.isExpanded("something-else"))

        store.toggle(leagueId)
        #expect(!store.isExpanded(leagueId))
        store.expand(leagueId)
        #expect(store.isExpanded(leagueId))
    }

    @Test func aCollapsedConferenceSectionPersistsLikeALeagueOne() {
        let defaults = makeDefaults()
        let sectionId = GameSection.conferencePrefix + ConferenceID.cfb(5).token
        UIStateStore(defaults: defaults).toggle(sectionId)

        let reloaded = UIStateStore(defaults: defaults)
        #expect(!reloaded.isExpanded(sectionId))
        #expect(!reloaded.expandedSections.contains(sectionId))
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
        UIStateStore(defaults: defaults).collapseAll(["something-else", leagueId,
                                                     GameSection.followingId])

        let reloaded = UIStateStore(defaults: defaults)
        #expect(!reloaded.isExpanded("something-else"))
        #expect(!reloaded.isExpanded(leagueId))
        #expect(!reloaded.isExpanded(GameSection.followingId))
    }

    @Test func bulkOpsAreIdempotentAndScoped() {
        let store = UIStateStore(defaults: makeDefaults())
        let leagueId = GameSection.id(for: .collegeFootball)

        // Only the passed ids move; the league stays open by default.
        store.collapseAll(["something-else"])
        store.collapseAll(["something-else"])
        #expect(!store.isExpanded("something-else"))
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
        store.scoreFilter = .top25
        let reloaded = UIStateStore(defaults: defaults)
        #expect(reloaded.liveOnly == true)
        #expect(reloaded.scoreFilter == .top25)

        reloaded.scoreFilter = nil
        #expect(UIStateStore(defaults: defaults).scoreFilter == nil)
    }

    /// A conference filter written before the view-options sheet retired
    /// comes back as the full slate: Top 25 is the only filter with a
    /// control now, so a restored conference slate would narrow the screen
    /// with nothing on it able to say so or clear it.
    @Test func aStoredConferenceFilterDoesNotComeBack() {
        let defaults = makeDefaults()
        let store = UIStateStore(defaults: defaults)
        store.scoreFilter = .conference(.cfb(8))

        #expect(UIStateStore(defaults: defaults).scoreFilter == nil)
    }
}
