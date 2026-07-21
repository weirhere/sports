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
        if defaults.string(forKey: "data.provider") == "cfbd",
           let key = cfbdKey(defaults: defaults) {
            return CFBDClient(apiKey: key)
        }
        return ESPNClient()
    }

    static func cfbdKey(defaults: UserDefaults = .standard) -> String? {
        let key = defaults.string(forKey: "cfbd.apiKey")
            ?? ProcessInfo.processInfo.environment["CFBD_API_KEY"]
        guard let key, !key.isEmpty else { return nil }
        return key
    }
}
