import Foundation
import Testing
@testable import StatSide

@Suite struct AppGroupMigrationTests {
    private func makeDefaults(_ label: String) -> (UserDefaults, name: String) {
        let name = "test.migration.\(label).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: name)!
        defaults.removePersistentDomain(forName: name)
        return (defaults, name)
    }

    @Test func copiesFollowsOnceAndKeepsTheOriginal() {
        let (standard, _) = makeDefaults("standard")
        let (suite, _) = makeDefaults("suite")
        standard.set(["61", "333"], forKey: AppGroup.followingKey)

        AppGroup.migrateFollowingIfNeeded(from: standard, to: suite)
        #expect(suite.stringArray(forKey: AppGroup.followingKey) == ["61", "333"])
        // Rollback safety: build 5 reads standard defaults.
        #expect(standard.stringArray(forKey: AppGroup.followingKey) == ["61", "333"])

        // A second run must not clobber suite-side changes.
        suite.set(["61"], forKey: AppGroup.followingKey)
        AppGroup.migrateFollowingIfNeeded(from: standard, to: suite)
        #expect(suite.stringArray(forKey: AppGroup.followingKey) == ["61"])
    }

    @Test func existingSuiteDataWinsOverStandard() {
        let (standard, _) = makeDefaults("standard")
        let (suite, _) = makeDefaults("suite")
        standard.set(["999"], forKey: AppGroup.followingKey)
        suite.set(["61"], forKey: AppGroup.followingKey)

        AppGroup.migrateFollowingIfNeeded(from: standard, to: suite)
        #expect(suite.stringArray(forKey: AppGroup.followingKey) == ["61"])
    }

    @Test func freshInstallMigratesToNothing() {
        let (standard, _) = makeDefaults("standard")
        let (suite, _) = makeDefaults("suite")

        AppGroup.migrateFollowingIfNeeded(from: standard, to: suite)
        #expect(suite.stringArray(forKey: AppGroup.followingKey) == nil)
    }
}
