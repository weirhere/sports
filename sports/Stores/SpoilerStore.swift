import Foundation
import Observation

/// Spoiler mode's state (E30, 2026-10-19): the Settings switch, and the
/// games the user has revealed. The rule itself is `SpoilerGuard`; this
/// is what feeds it.
///
/// Backed by the App Group suite like `FollowingStore`, and for the same
/// reason: the widget draws scores too, and a mode the home screen
/// ignores is not a mode (E30 PR 2 reads these keys there). Every value
/// is read once in `init`, so a UI suite can pin both keys from the
/// argument domain the way it pins `-ui.scoreFilter`.
@Observable
final class SpoilerStore {
    /// The switch: hide results until they are revealed.
    var hidesScores: Bool {
        didSet { defaults.set(hidesScores, forKey: AppGroup.spoilerEnabledKey) }
    }

    /// Which games the switch reaches: My teams (the default) or All
    /// games. Kept while the switch is off, so turning it back on finds
    /// the choice where it was left.
    var scope: SpoilerGuard.Scope {
        didSet { defaults.set(scope.rawValue, forKey: AppGroup.spoilerScopeKey) }
    }

    /// `Game.routeKey` → when it was revealed. A reveal is the user's
    /// word that they've watched, so it is never undone by the app, only
    /// aged out: anything older than `retention` is dropped on the next
    /// launch. Longer than `SpoilerGuard.finalWindow`, so a reveal always
    /// outlives the concealment it answered.
    private(set) var revealed: [String: Date]

    /// How long a reveal is remembered.
    static let retention: TimeInterval = 14 * 86_400

    private let defaults: UserDefaults

    init(defaults: UserDefaults = AppGroup.defaults, now: Date = .now) {
        self.defaults = defaults
        hidesScores = defaults.bool(forKey: AppGroup.spoilerEnabledKey)
        // An unknown or missing value is My teams: the narrower reach is
        // the one a stale or mistyped key should fall to.
        scope = defaults.string(forKey: AppGroup.spoilerScopeKey)
            .flatMap(SpoilerGuard.Scope.init(rawValue:)) ?? .followedTeams
        // Stored as `[String: Double]` (seconds since 1970): a dictionary
        // of dates round-trips through the argument domain as `{}` where a
        // Date would not, and the UI suite pins an empty one.
        let stored = defaults.dictionary(forKey: AppGroup.spoilerRevealedKey) ?? [:]
        var kept: [String: Date] = [:]
        for (key, value) in stored {
            guard let seconds = value as? Double else { continue }
            let date = Date(timeIntervalSince1970: seconds)
            guard now.timeIntervalSince(date) <= Self.retention else { continue }
            kept[key] = date
        }
        revealed = kept
        // Write back only when something aged out, so a launch that
        // changes nothing writes nothing.
        if kept.count != stored.count { persistRevealed() }
    }

    var revealedKeys: Set<String> { Set(revealed.keys) }

    func isRevealed(_ game: Game) -> Bool { revealed[game.routeKey] != nil }

    /// Show this game's result from now on.
    func reveal(_ game: Game, at date: Date = .now) {
        guard revealed[game.routeKey] == nil else { return }
        revealed[game.routeKey] = date
        persistRevealed()
    }

    /// What `SpoilerGuard` needs from here, with the follow set it also
    /// needs from `FollowingStore`.
    func guardValue(followedKeys: Set<String>) -> SpoilerGuard {
        SpoilerGuard(isEnabled: hidesScores, followedKeys: followedKeys,
                     revealedKeys: revealedKeys, scope: scope)
    }

    private func persistRevealed() {
        defaults.set(revealed.mapValues(\.timeIntervalSince1970), forKey: AppGroup.spoilerRevealedKey)
    }
}
