import Foundation
import Testing
@testable import StatSide

private func team(_ id: String, conference: Int?) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: conference)
}

private func game(home: Team, away: Team) -> Game {
    Game(id: "g1", date: nil, name: nil, shortName: nil, weekNumber: 1,
         status: .pre(detail: nil),
         home: Competitor(team: home, score: nil, record: nil, rank: nil, isHome: true, winner: nil),
         away: Competitor(team: away, score: nil, record: nil, rank: nil, isHome: false, winner: nil),
         broadcast: nil)
}

@MainActor
@Suite struct FollowingStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.following.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func conferenceFollowPersistsAcrossReinit() {
        let defaults = makeDefaults()
        let store = FollowingStore(defaults: defaults)
        store.toggleConference(8)
        #expect(store.isFollowingConference(8))

        let reloaded = FollowingStore(defaults: defaults)
        #expect(reloaded.isFollowingConference(8))

        reloaded.toggleConference(8)
        #expect(!reloaded.isFollowingConference(8))
        #expect(!FollowingStore(defaults: defaults).isFollowingConference(8))
    }

    @Test func conferenceFollowAloneCountsAsFollowingSomeone() {
        let store = FollowingStore(defaults: makeDefaults())
        #expect(!store.followsAnyone)
        store.toggleConference(8)
        #expect(store.followsAnyone)
    }

    @Test func followsMatchesEitherSidesConference() {
        let store = FollowingStore(defaults: makeDefaults())
        store.toggleConference(8)

        // SEC on the home side, on the away side, and absent.
        #expect(store.follows(game(home: team("1", conference: 8),
                                   away: team("2", conference: 5))))
        #expect(store.follows(game(home: team("1", conference: 5),
                                   away: team("2", conference: 8))))
        #expect(!store.follows(game(home: team("1", conference: 5),
                                    away: team("2", conference: 1))))
    }

    @Test func nilConferenceIdNeverMatches() {
        // An FCS visitor has no conference id on our table; only the FBS
        // host's side can carry the game in.
        let store = FollowingStore(defaults: makeDefaults())
        store.toggleConference(8)
        #expect(store.follows(game(home: team("1", conference: 8),
                                   away: team("2", conference: nil))))
        #expect(!store.follows(game(home: team("1", conference: nil),
                                    away: team("2", conference: nil))))
    }

    @Test func conferenceAndTeamFollowsAreIndependentSets() {
        let store = FollowingStore(defaults: makeDefaults())
        store.toggle("61")
        store.toggleConference(8)
        #expect(store.isFollowing("61"))
        #expect(store.isFollowingConference(8))
        store.toggle("61")
        #expect(!store.isFollowing("61"))
        #expect(store.isFollowingConference(8))
    }
}
