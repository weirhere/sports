import Foundation
import Observation

/// Decides when to ask for an App Store rating.
///
/// There is exactly one moment worth asking at, and it is not a launch
/// count: a kickoff reminder fired, and the user tapped it through to the
/// game. That is the app delivering the thing it promised, in the second
/// it delivered it (open question #7, 2026-09-08). Anywhere else is an
/// interruption of something the user came here to do.
///
/// The arm is per *game* and in-memory. A reminder tap names the game it
/// is routing to; opening that game spends the arm, opening any other
/// leaves it alone, and it dies with the process. The only thing that
/// outlives a launch is the version we last asked on.
@Observable
final class ReviewPrompt {
    /// One ask per shipped version. Apple throttles the system prompt on
    /// its own (a few times a year, and whether it renders at all is out
    /// of our hands) — this is the politeness the app owes on top of that,
    /// and it is the half that can be tested.
    private static let lastVersionKey = "review.lastRequestedVersion"

    /// The game a kickoff-reminder tap is on its way to. Not observed:
    /// nothing renders from it, and arming shouldn't invalidate a view.
    @ObservationIgnored private var armedGameId: String?

    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let version: String

    init(defaults: UserDefaults = .standard, version: String = ReviewPrompt.bundleVersion) {
        self.defaults = defaults
        self.version = version
    }

    /// `CFBundleShortVersionString` — the marketing version, so 2.2.0 and
    /// 2.2.1 are two asks and two builds of 2.2.0 are one.
    static var bundleVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// A kickoff reminder was tapped, and it is routing to this game.
    func armFromKickoffReminder(gameId: String) {
        armedGameId = gameId
    }

    /// Whether this game appearing on screen has earned the ask.
    ///
    /// Spends the arm when the game matches, whatever the verdict: the
    /// reminder's moment happens once, and a version that has already
    /// asked shouldn't leave a live arm behind to fire on the next launch.
    func earnedByOpening(gameId: String) -> Bool {
        guard armedGameId == gameId else { return false }
        armedGameId = nil
        guard !isDisabled else { return false }
        return defaults.string(forKey: Self.lastVersionKey) != version
    }

    /// Records that the system prompt was asked for on this version.
    /// Called when the request is made rather than when a rating arrives —
    /// whether the sheet renders is Apple's call and is not observable.
    func recordRequest() {
        defaults.set(version, forKey: Self.lastVersionKey)
    }

    /// The UI-test kill switch (`-review.prompt off`). A system rating
    /// sheet landing mid-suite eats taps that were meant for the app, and
    /// XCUITest can't dismiss it reliably — see CLAUDE.md § Running the UI
    /// tests. DEBUG-only, so no release build can be argued out of asking.
    private var isDisabled: Bool {
        #if DEBUG
        return defaults.string(forKey: "review.prompt") == "off"
        #else
        return false
        #endif
    }
}
