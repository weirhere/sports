import Foundation

/// The shared-suite contract between the app and the widget extension.
/// Both processes read the follow set through here; the widget also parks
/// its last-good snapshot in the suite.
nonisolated enum AppGroup {
    static let id = "group.com.andyryanweir.sports"
    static let widgetKind = "StatSideNextGame"

    /// Pre-league keys. Bare ESPN ids, college football by assumption.
    /// Still written by nothing, still read by the migration, and
    /// deliberately never deleted — see `migrateFollowingIfNeeded`.
    static let followingKey = "following.teamIds"
    static let followingConferencesKey = "following.conferenceIds"

    /// League-qualified keys. `following.teamKeys` holds `"cfb:130"` /
    /// `"nfl:26"`; `following.conferenceTokens` holds `"cfb-8"` / `"nfl-8"`.
    static let followingKeysKey = "following.teamKeys"
    static let followingConferenceTokensKey = "following.conferenceTokens"

    /// Leagues whose poll is followed, as league tokens (`"cfb"`). A poll
    /// belongs to a league rather than being one thing, so this is a set
    /// and not a flag — the NFL has no poll today, and a league that grows
    /// one needs no migration.
    static let followingPollLeaguesKey = "following.pollLeagues"

    /// The order followed tables appear in — `FollowedTable` tokens
    /// (`"poll-cfb"`, `"conf-cfb-5"`), the arrangement the user dragged
    /// them into on the tables hub. It drives the hoisted sections on
    /// Scores too, which is the whole point: one list, one order, both
    /// screens.
    ///
    /// Absence is not an error — a follow set saved before dragging
    /// existed simply has no stored order, and falls back to
    /// `FollowedTable.defaultOrder`. Tokens for tables no longer followed
    /// are dropped on read rather than migrated away, so unfollowing and
    /// re-following restores nothing and costs nothing.
    static let followingTableOrderKey = "following.tableOrder"

    static let snapshotKey = "widget.snapshot"
    private static let migrationKey = "migration.followingToGroup.done"
    private static let leagueMigrationKey = "migration.leagueNamespacing.done"

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

    /// Stamps the league onto follows saved before the league axis existed.
    ///
    /// This is the migration that matters. ESPN team ids collide across
    /// leagues — 26 is UCLA in college football and the Seattle Seahawks in
    /// the NFL, and 20 of the NFL's 32 ids have a college twin — so a bare
    /// id set is genuinely ambiguous the moment a second league ships.
    /// Everything stored before this build was college football, so every
    /// bare id becomes `"cfb:<id>"` and every bare conference id `"cfb-<id>"`.
    ///
    /// Like the App Group migration above, the pre-league keys are left
    /// untouched: a rollback to 1.4.0 must not lose anyone's teams.
    static func migrateLeagueNamespacingIfNeeded(in suite: UserDefaults = defaults) {
        guard !suite.bool(forKey: leagueMigrationKey) else { return }
        let prefix = League.collegeFootball.rawValue

        if suite.stringArray(forKey: followingKeysKey) == nil,
           let bare = suite.stringArray(forKey: followingKey) {
            suite.set(bare.map { "\(prefix):\($0)" }.sorted(), forKey: followingKeysKey)
        }
        if suite.stringArray(forKey: followingConferenceTokensKey) == nil,
           let bare = suite.array(forKey: followingConferencesKey) as? [Int] {
            suite.set(bare.map { ConferenceID(.collegeFootball, $0).token }.sorted(),
                      forKey: followingConferenceTokensKey)
        }
        suite.set(true, forKey: leagueMigrationKey)
    }
}
