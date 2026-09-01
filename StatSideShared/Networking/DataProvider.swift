import Foundation

/// Picks the scores backend. ESPN remains the default until the CFBD swap
/// is field-verified; CFBD activates only when both the switch is flipped
/// and a key is present:
///
///     defaults: `data.provider` = "cfbd", `cfbd.apiKey` = "<key>"
///     (or launch arguments `-data.provider cfbd`, plus the key in the
///      CFBD_API_KEY environment variable for simulator runs)
///
/// A flipped switch with no key falls back to ESPN rather than serving a
/// broken screen.
nonisolated enum DataProvider {
    static func makeClient(defaults: UserDefaults = .standard) -> any ScoresProviding {
        #if DEBUG
        // The live-detail regression tests' scripted backend — never
        // compiled into release builds, never touches the network.
        if defaults.string(forKey: "data.provider") == "fixture" {
            return FixtureScoresClient()
        }
        #endif
        if defaults.string(forKey: "data.provider") == "cfbd",
           let key = cfbdKey(defaults: defaults) {
            return CFBDClient(apiKey: key)
        }
        return ESPNClient()
    }

    /// The scoreboard and game-detail poll cadence: 30 seconds, the
    /// polite-guest floor. DEBUG builds may compress it via the
    /// `poll.interval` default (seconds) so the fixture-backed regression
    /// tests can pack many refresh cycles into one run; release builds
    /// ignore the override entirely.
    static var pollInterval: Duration {
        #if DEBUG
        let seconds = UserDefaults.standard.double(forKey: "poll.interval")
        if seconds > 0 { return .milliseconds(Int(seconds * 1000)) }
        #endif
        return .seconds(30)
    }

    static func cfbdKey(defaults: UserDefaults = .standard) -> String? {
        let key = defaults.string(forKey: "cfbd.apiKey")
            ?? ProcessInfo.processInfo.environment["CFBD_API_KEY"]
        guard let key, !key.isEmpty else { return nil }
        return key
    }
}
