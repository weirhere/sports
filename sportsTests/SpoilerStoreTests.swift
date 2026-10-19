import Foundation
import Testing
@testable import StatSide

private func team(_ id: String) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil)
}

private func game(_ id: String) -> Game {
    Game(id: id, date: nil, name: nil, shortName: nil, weekNumber: 1,
         status: .final(detail: "Final"),
         home: Competitor(team: team("h"), score: 24, record: nil, rank: nil, isHome: true, winner: true),
         away: Competitor(team: team("a"), score: 17, record: nil, rank: nil, isHome: false, winner: false),
         broadcast: nil)
}

@MainActor
@Suite struct SpoilerStoreTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.spoiler.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func offByDefaultAndScopedToMyTeams() {
        let store = SpoilerStore(defaults: makeDefaults())
        #expect(!store.hidesScores)
        #expect(store.scope == .followedTeams)
        #expect(store.revealed.isEmpty)
        #expect(!store.guardValue(followedKeys: ["cfb:61"]).isEnabled)
    }

    @Test func theSwitchPersistsAcrossReinit() {
        let defaults = makeDefaults()
        let store = SpoilerStore(defaults: defaults)
        store.hidesScores = true
        #expect(SpoilerStore(defaults: defaults).hidesScores)
        store.hidesScores = false
        #expect(!SpoilerStore(defaults: defaults).hidesScores)
    }

    @Test func theScopePersistsAndReachesTheGuard() {
        let defaults = makeDefaults()
        let store = SpoilerStore(defaults: defaults)
        store.hidesScores = true
        store.scope = .allGames
        #expect(store.guardValue(followedKeys: []).scope == .allGames)
        #expect(store.guardValue(followedKeys: []).conceals(game("401")))

        let reloaded = SpoilerStore(defaults: defaults)
        #expect(reloaded.scope == .allGames)
        // Off keeps the choice for next time.
        reloaded.hidesScores = false
        #expect(SpoilerStore(defaults: defaults).scope == .allGames)
    }

    @Test func anUnknownScopeFallsBackToMyTeams() {
        let defaults = makeDefaults()
        defaults.set("everything", forKey: AppGroup.spoilerScopeKey)
        #expect(SpoilerStore(defaults: defaults).scope == .followedTeams)
    }

    @Test func aRevealPersistsAcrossReinit() {
        let defaults = makeDefaults()
        let store = SpoilerStore(defaults: defaults)
        let played = game("401")
        #expect(!store.isRevealed(played))
        store.reveal(played)
        #expect(store.isRevealed(played))

        let reloaded = SpoilerStore(defaults: defaults)
        #expect(reloaded.isRevealed(played))
        #expect(reloaded.revealedKeys == [played.routeKey])
        #expect(!reloaded.guardValue(followedKeys: []).conceals(played))
    }

    @Test func aRevealIsKeyedByLeagueAndId() {
        let store = SpoilerStore(defaults: makeDefaults())
        store.reveal(game("401"))
        #expect(store.revealedKeys == ["cfb:401"])
    }

    @Test func oldRevealsAgeOutOnLaunch() {
        let defaults = makeDefaults()
        let now = Date(timeIntervalSince1970: 1_792_000_000)
        let store = SpoilerStore(defaults: defaults, now: now)
        store.reveal(game("old"), at: now.addingTimeInterval(-15 * 86_400))
        store.reveal(game("recent"), at: now.addingTimeInterval(-13 * 86_400))
        #expect(store.revealedKeys == ["cfb:old", "cfb:recent"])

        let reloaded = SpoilerStore(defaults: defaults, now: now)
        #expect(reloaded.revealedKeys == ["cfb:recent"])
        // And the prune was written back, not just applied in memory.
        #expect(SpoilerStore(defaults: defaults, now: now).revealedKeys == ["cfb:recent"])
    }

    @Test func anUnreadableEntryIsDropped() {
        let defaults = makeDefaults()
        let mixed: [String: Any] = ["cfb:1": "not a date", "cfb:2": 1_792_000_000.0]
        defaults.set(mixed, forKey: AppGroup.spoilerRevealedKey)
        let store = SpoilerStore(defaults: defaults, now: Date(timeIntervalSince1970: 1_792_000_000))
        #expect(store.revealedKeys == ["cfb:2"])
    }
}
