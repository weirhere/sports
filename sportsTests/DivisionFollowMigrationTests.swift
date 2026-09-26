import Foundation
import Testing
@testable import StatSide

/// Divisions stopped being tables on 2026-09-26, so a division follow moves
/// up to the conference whose page it now lives on.
@Suite struct DivisionFollowMigrationTests {
    private func makeDefaults() -> UserDefaults {
        let name = "test.divisionmigration.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return defaults
    }

    @Test func aDivisionFollowBecomesItsConference() {
        let defaults = makeDefaults()
        // AFC East, the NBA's Atlantic, the SEC and the whole NFL.
        defaults.set(["nfl-4", "nba-1", "cfb-8", "nfl-9"],
                     forKey: AppGroup.followingConferenceTokensKey)

        AppGroup.migrateDivisionFollowsIfNeeded(in: defaults)

        #expect(defaults.stringArray(forKey: AppGroup.followingConferenceTokensKey)
                == ["cfb-8", "nba-5", "nfl-8", "nfl-9"])
    }

    @Test func twoDivisionsOfOneConferenceLeaveOneFollowWhereTheFirstWas() {
        let defaults = makeDefaults()
        defaults.set(["nfl-4", "nfl-12"], forKey: AppGroup.followingConferenceTokensKey)
        defaults.set(["poll-cfb", "conf-nfl-4", "conf-cfb-8", "conf-nfl-12"],
                     forKey: AppGroup.followingTableOrderKey)

        AppGroup.migrateDivisionFollowsIfNeeded(in: defaults)

        #expect(defaults.stringArray(forKey: AppGroup.followingConferenceTokensKey) == ["nfl-8"])
        #expect(defaults.stringArray(forKey: AppGroup.followingTableOrderKey)
                == ["poll-cfb", "conf-nfl-8", "conf-cfb-8"])
    }

    @Test func itRunsOnce() {
        let defaults = makeDefaults()
        AppGroup.migrateDivisionFollowsIfNeeded(in: defaults)
        defaults.set(["nfl-4"], forKey: AppGroup.followingConferenceTokensKey)

        AppGroup.migrateDivisionFollowsIfNeeded(in: defaults)

        #expect(defaults.stringArray(forKey: AppGroup.followingConferenceTokensKey) == ["nfl-4"])
    }
}
