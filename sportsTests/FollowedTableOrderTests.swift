import Foundation
import Testing
@testable import StatSide

@Suite struct FollowedTableTests {
    @Test func tokensRoundTrip() {
        let tables: [FollowedTable] = [.poll(.collegeFootball), .poll(.nfl),
                                       .conference(.cfb(8)), .conference(.nfl(9))]
        for table in tables {
            #expect(FollowedTable(token: table.token) == table)
        }
        #expect(FollowedTable(token: "conf-cfb-8") == .conference(.cfb(8)))
        #expect(FollowedTable(token: "poll-cfb") == .poll(.collegeFootball))
    }

    @Test func nonsenseTokensDoNotParse() {
        // The stored order is a list of these tokens, written by whatever
        // version of the app last touched it, so a token that isn't one of
        // ours has to fail rather than resolve to something
        // plausible-looking.
        #expect(FollowedTable(token: "") == nil)
        #expect(FollowedTable(token: "SEC") == nil)
        #expect(FollowedTable(token: "poll-") == nil)
        #expect(FollowedTable(token: "conf-") == nil)
        #expect(FollowedTable(token: "conf-mlb-8") == nil)
    }

    @Test func namesComeFromTheRegistry() {
        #expect(FollowedTable.conference(.cfb(5)).name == "Big Ten")
        #expect(FollowedTable.conference(.nfl(8)).name == "AFC")
        #expect(FollowedTable.conference(.nfl(9)).name == "NFL")
        #expect(FollowedTable.poll(.collegeFootball).name == "Top 25")
    }

    @Test func aConferenceClaimsAGameThroughTheGroupChain() {
        // ESPN's NFL scoreboard hands a team its *division*, so a followed
        // AFC only means anything if the walk-up happens.
        let bills = Team(id: "2", location: "Buffalo", name: nil, abbreviation: nil,
                         displayName: nil, shortDisplayName: nil, logoURL: nil,
                         conferenceId: 4, league: .nfl)
        let chiefs = Team(id: "12", location: "Kansas City", name: nil, abbreviation: nil,
                          displayName: nil, shortDisplayName: nil, logoURL: nil,
                          conferenceId: 6, league: .nfl)
        let game = Game(id: "g", date: nil, name: nil, shortName: nil, weekNumber: 1,
                        status: .pre(detail: nil),
                        home: Competitor(team: bills, score: nil, record: nil, rank: nil,
                                         isHome: true, winner: nil),
                        away: Competitor(team: chiefs, score: nil, record: nil, rank: nil,
                                         isHome: false, winner: nil),
                        broadcast: nil)

        #expect(FollowedTable.conference(.nfl(4)).matches(game))   // AFC East
        #expect(FollowedTable.conference(.nfl(8)).matches(game))   // AFC
        #expect(FollowedTable.conference(.nfl(9)).matches(game))   // the league
        #expect(!FollowedTable.conference(.nfl(7)).matches(game))  // NFC
        #expect(!FollowedTable.conference(.cfb(8)).matches(game))  // the *SEC* is group 8 too
    }
}

@MainActor
@Suite struct FollowedTableOrderTests {
    private func makeStore() -> (FollowingStore, UserDefaults) {
        let name = "test.tableorder.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (FollowingStore(defaults: defaults), defaults)
    }

    @Test func newFollowsLandAtTheEnd() {
        let (store, _) = makeStore()
        store.toggleConference(.cfb(8))
        store.togglePoll(in: .collegeFootball)
        store.toggleConference(.cfb(5))

        #expect(store.orderedTables == [.conference(.cfb(8)), .poll(.collegeFootball),
                                        .conference(.cfb(5))])
    }

    @Test func draggingReordersAndPersists() {
        let (store, defaults) = makeStore()
        store.toggleConference(.cfb(8))
        store.toggleConference(.cfb(5))
        store.toggleConference(.nfl(8))

        store.move(.conference(.nfl(8)), onto: .conference(.cfb(8)))
        #expect(store.orderedTables == [.conference(.nfl(8)), .conference(.cfb(8)),
                                        .conference(.cfb(5))])

        let reloaded = FollowingStore(defaults: defaults)
        #expect(reloaded.orderedTables == [.conference(.nfl(8)), .conference(.cfb(8)),
                                           .conference(.cfb(5))])
    }

    @Test func movingDownPutsTheRowAfterItsTarget() {
        let (store, _) = makeStore()
        store.toggleConference(.cfb(8))
        store.toggleConference(.cfb(5))
        store.toggleConference(.cfb(1))

        store.move(.conference(.cfb(8)), onto: .conference(.cfb(5)))
        #expect(store.orderedTables == [.conference(.cfb(5)), .conference(.cfb(8)),
                                        .conference(.cfb(1))])
    }

    @Test func unfollowingDropsItFromTheOrder() {
        let (store, defaults) = makeStore()
        store.toggleConference(.cfb(8))
        store.toggleConference(.cfb(5))
        store.toggleConference(.cfb(8))

        #expect(store.orderedTables == [.conference(.cfb(5))])
        #expect(!store.tableOrder.contains("conf-cfb-8"))
        #expect(FollowingStore(defaults: defaults).orderedTables == [.conference(.cfb(5))])
    }

    @Test func followsSavedBeforeDraggingExistedFallBackToTheHubsOrder() {
        // No stored order: polls first, then P4 → G5, alphabetical inside
        // a tier — the order the tables hub already listed them in.
        let name = "test.tableorder.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaults.set(["cfb-15", "cfb-8", "cfb-5"],
                     forKey: AppGroup.followingConferenceTokensKey)
        defaults.set(["cfb"], forKey: AppGroup.followingPollLeaguesKey)

        #expect(FollowingStore(defaults: defaults).orderedTables
                == [.poll(.collegeFootball), .conference(.cfb(5)),
                    .conference(.cfb(8)), .conference(.cfb(15))])
    }

    @Test func aStoredOrderIgnoresTokensNoLongerFollowed() {
        let name = "test.tableorder.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaults.set(["cfb-8"], forKey: AppGroup.followingConferenceTokensKey)
        defaults.set(["conf-cfb-5", "conf-cfb-8", "nonsense"],
                     forKey: AppGroup.followingTableOrderKey)

        #expect(FollowingStore(defaults: defaults).orderedTables == [.conference(.cfb(8))])
    }

    @Test func movingSomethingUnfollowedChangesNothing() {
        let (store, _) = makeStore()
        store.toggleConference(.cfb(8))
        store.toggleConference(.cfb(5))

        store.move(.conference(.cfb(4)), onto: .conference(.cfb(8)))
        store.move(.conference(.cfb(4)), to: 0)
        #expect(store.orderedTables == [.conference(.cfb(8)), .conference(.cfb(5))])
    }

    // MARK: - Index moves
    //
    // What a drag resolves to: an insertion index into the list with the
    // lifted card taken out of it, which is the only reading that can name
    // the slot past the last card.

    @Test func anIndexMoveDropsTheCardIntoThatSlot() {
        let (store, defaults) = makeStore()
        store.toggleConference(.cfb(8))
        store.toggleConference(.cfb(5))
        store.toggleConference(.cfb(1))

        // Lift the first card, drop it into the last slot.
        store.move(.conference(.cfb(8)), to: 2)
        #expect(store.orderedTables == [.conference(.cfb(5)), .conference(.cfb(1)),
                                        .conference(.cfb(8))])

        // And back to the top.
        store.move(.conference(.cfb(8)), to: 0)
        #expect(store.orderedTables == [.conference(.cfb(8)), .conference(.cfb(5)),
                                        .conference(.cfb(1))])

        #expect(FollowingStore(defaults: defaults).orderedTables
                == [.conference(.cfb(8)), .conference(.cfb(5)), .conference(.cfb(1))])
    }

    @Test func droppingACardBackWhereItStartedPersistsNothing() {
        // A lift that travels nowhere shouldn't pin down an order the user
        // never arranged — everything here is still riding the default.
        let name = "test.tableorder.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        defaults.set(["cfb-8", "cfb-5"], forKey: AppGroup.followingConferenceTokensKey)
        let store = FollowingStore(defaults: defaults)

        #expect(store.orderedTables == [.conference(.cfb(5)), .conference(.cfb(8))])
        store.move(.conference(.cfb(5)), to: 0)
        #expect(store.tableOrder.isEmpty)
    }

    @Test func anOutOfRangeIndexClampsRatherThanCrashing() {
        let (store, _) = makeStore()
        store.toggleConference(.cfb(8))
        store.toggleConference(.cfb(5))

        store.move(.conference(.cfb(8)), to: 99)
        #expect(store.orderedTables == [.conference(.cfb(5)), .conference(.cfb(8))])

        store.move(.conference(.cfb(8)), to: -3)
        #expect(store.orderedTables == [.conference(.cfb(8)), .conference(.cfb(5))])
    }
}
