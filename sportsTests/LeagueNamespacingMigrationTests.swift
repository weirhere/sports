import Foundation
import Testing
@testable import StatSide

/// The migration that stops a UCLA fan silently following the Seahawks.
///
/// ESPN team ids collide across leagues — 20 of the NFL's 32 have a college
/// twin, including 26 (UCLA / Seattle), 24 (Stanford / Chargers) and 30
/// (USC / Jacksonville) — so every follow saved before the league axis has
/// to be stamped college football, which is all it could have been.
@Suite struct LeagueNamespacingMigrationTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.leaguemigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func bareTeamIdsBecomeCollegeFootballKeys() {
        let defaults = makeDefaults()
        defaults.set(["26", "130", "24"], forKey: AppGroup.followingKey)

        AppGroup.migrateLeagueNamespacingIfNeeded(in: defaults)

        #expect(defaults.stringArray(forKey: AppGroup.followingKeysKey)
                == ["cfb:130", "cfb:24", "cfb:26"])
    }

    @Test func bareConferenceIdsBecomeCollegeFootballTokens() {
        let defaults = makeDefaults()
        defaults.set([8, 5], forKey: AppGroup.followingConferencesKey)

        AppGroup.migrateLeagueNamespacingIfNeeded(in: defaults)

        #expect(defaults.stringArray(forKey: AppGroup.followingConferenceTokensKey)
                == ["cfb-5", "cfb-8"])
    }

    /// A rollback to 1.4.0 must not lose anyone's teams, so the pre-league
    /// keys are deliberately left in place — the same promise the App Group
    /// migration makes.
    @Test func thePreLeagueKeysSurviveForRollback() {
        let defaults = makeDefaults()
        defaults.set(["26"], forKey: AppGroup.followingKey)
        defaults.set([8], forKey: AppGroup.followingConferencesKey)

        AppGroup.migrateLeagueNamespacingIfNeeded(in: defaults)

        #expect(defaults.stringArray(forKey: AppGroup.followingKey) == ["26"])
        #expect(defaults.array(forKey: AppGroup.followingConferencesKey) as? [Int] == [8])
    }

    /// Running twice must not clobber follows made after the first run.
    @Test func migrationIsIdempotentAndNeverOverwritesNewerFollows() {
        let defaults = makeDefaults()
        defaults.set(["26"], forKey: AppGroup.followingKey)
        AppGroup.migrateLeagueNamespacingIfNeeded(in: defaults)

        let store = FollowingStore(defaults: defaults)
        store.toggle("26", in: .nfl)          // now follows UCLA *and* Seattle
        AppGroup.migrateLeagueNamespacingIfNeeded(in: defaults)

        #expect(defaults.stringArray(forKey: AppGroup.followingKeysKey)
                == ["cfb:26", "nfl:26"])
    }

    @Test func aFreshInstallMigratesToNothing() {
        let defaults = makeDefaults()
        AppGroup.migrateLeagueNamespacingIfNeeded(in: defaults)
        #expect(defaults.stringArray(forKey: AppGroup.followingKeysKey) == nil)
        #expect(FollowingStore(defaults: defaults).followsAnyone == false)
    }

    /// The end-to-end promise: after migrating, the store still knows UCLA
    /// and does not think you follow the Seahawks.
    @Test func aMigratedFollowStaysTheCollegeTeam() {
        let defaults = makeDefaults()
        defaults.set(["26"], forKey: AppGroup.followingKey)
        AppGroup.migrateLeagueNamespacingIfNeeded(in: defaults)

        let store = FollowingStore(defaults: defaults)
        #expect(store.isFollowing("26", in: .collegeFootball))
        #expect(!store.isFollowing("26", in: .nfl))
        #expect(store.teamIds(in: .collegeFootball) == ["26"])
        #expect(store.teamIds(in: .nfl).isEmpty)
    }
}

/// Follows are per-league even when the ids are identical.
@Suite struct CrossLeagueFollowTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.crossleague.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    private func team(_ id: String, league: League, conference: Int? = nil) -> Team {
        Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
             displayName: nil, shortDisplayName: nil, logoURL: nil,
             conferenceId: conference, league: league)
    }

    private func game(home: Team, away: Team) -> Game {
        Game(id: "g1", date: nil, name: nil, shortName: nil, weekNumber: 1,
             status: .pre(detail: nil),
             home: Competitor(team: home, score: nil, record: nil, rank: nil,
                              isHome: true, winner: nil),
             away: Competitor(team: away, score: nil, record: nil, rank: nil,
                              isHome: false, winner: nil),
             broadcast: nil)
    }

    @Test func followingUCLADoesNotFollowTheSeahawks() {
        let store = FollowingStore(defaults: makeDefaults())
        store.toggle(team("26", league: .collegeFootball))

        #expect(store.follows(game(home: team("26", league: .collegeFootball),
                                   away: team("2", league: .collegeFootball))))
        #expect(!store.follows(game(home: team("26", league: .nfl),
                                    away: team("25", league: .nfl))))
    }

    /// Conference id 8 is the SEC and the AFC — following one must not
    /// claim the other's games.
    @Test func followingTheSECDoesNotFollowTheAFC() {
        let store = FollowingStore(defaults: makeDefaults())
        store.toggleConference(.cfb(8))

        #expect(store.follows(game(home: team("1", league: .collegeFootball, conference: 8),
                                   away: team("2", league: .collegeFootball))))
        #expect(!store.follows(game(home: team("1", league: .nfl, conference: 8),
                                    away: team("2", league: .nfl))))
    }
}
