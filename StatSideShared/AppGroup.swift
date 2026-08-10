import Foundation

/// The shared-suite contract between the app and the widget extension.
/// Both processes read the follow set through here; the widget also parks
/// its last-good snapshot in the suite.
nonisolated enum AppGroup {
    static let id = "group.com.andyryanweir.sports"
    static let widgetKind = "StatSideNextGame"
    static let followingKey = "following.teamIds"
    static let followingConferencesKey = "following.conferenceIds"
    static let snapshotKey = "widget.snapshot"
    private static let migrationKey = "migration.followingToGroup.done"

    /// The suite, falling back to standard defaults if the entitlement is
    /// missing (previews, tests) so nothing force-unwraps.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: id) ?? .standard
    }

    /// Copies pre-App-Group follows into the suite exactly once. The
    /// standard-defaults copy is deliberately left behind: rolling back to
    /// build 5 must not lose anyone's teams. Parameters exist for tests;
    /// production always calls it bare.
    static func migrateFollowingIfNeeded(
        from standard: UserDefaults = .standard, to suite: UserDefaults = defaults
    ) {
        guard suite !== standard, !suite.bool(forKey: migrationKey) else { return }
        if suite.stringArray(forKey: followingKey) == nil,
           let existing = standard.stringArray(forKey: followingKey) {
            suite.set(existing, forKey: followingKey)
        }
        suite.set(true, forKey: migrationKey)
    }
}
