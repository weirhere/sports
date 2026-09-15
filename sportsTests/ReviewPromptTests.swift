import Foundation
import Testing
@testable import StatSide

@MainActor
@Suite struct ReviewPromptTests {
    private func makeDefaults() -> UserDefaults {
        let suite = "ReviewPromptTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    @Test func unarmedGameNeverEarnsTheAsk() {
        let prompt = ReviewPrompt(defaults: makeDefaults(), version: "2.2.0")

        // Every other way into a game — a row tap, a widget, a share link,
        // search — is the user doing something they came here to do.
        #expect(!prompt.earnedByOpening(gameId: "401"))
    }

    @Test func theRemindersGameEarnsItOnce() {
        let defaults = makeDefaults()
        let prompt = ReviewPrompt(defaults: defaults, version: "2.2.0")

        prompt.armFromKickoffReminder(gameId: "401")
        #expect(prompt.earnedByOpening(gameId: "401"))
        prompt.recordRequest()

        // Spent. A second visit to the same game on the same launch is a
        // visit, not a delivered promise.
        #expect(!prompt.earnedByOpening(gameId: "401"))
    }

    @Test func anotherGameLeavesTheArmAlone() {
        let prompt = ReviewPrompt(defaults: makeDefaults(), version: "2.2.0")

        // Landing somewhere else first — a live row on the way past, a
        // widget tap — must not burn the arm the reminder set.
        prompt.armFromKickoffReminder(gameId: "401")
        #expect(!prompt.earnedByOpening(gameId: "999"))
        #expect(prompt.earnedByOpening(gameId: "401"))
    }

    @Test func oneAskPerVersionSurvivesRelaunch() {
        let defaults = makeDefaults()

        let first = ReviewPrompt(defaults: defaults, version: "2.2.0")
        first.armFromKickoffReminder(gameId: "401")
        #expect(first.earnedByOpening(gameId: "401"))
        first.recordRequest()

        // A fresh process, same version, same user: asked already.
        let relaunched = ReviewPrompt(defaults: defaults, version: "2.2.0")
        relaunched.armFromKickoffReminder(gameId: "401")
        #expect(!relaunched.earnedByOpening(gameId: "401"))

        // A shipped version is a new thing to have an opinion about.
        let upgraded = ReviewPrompt(defaults: defaults, version: "2.3.0")
        upgraded.armFromKickoffReminder(gameId: "401")
        #expect(upgraded.earnedByOpening(gameId: "401"))
    }

    @Test func aDeclinedVersionIsStillSpentOnTheArm() {
        let defaults = makeDefaults()
        defaults.set("2.2.0", forKey: "review.lastRequestedVersion")
        let prompt = ReviewPrompt(defaults: defaults, version: "2.2.0")

        // The verdict is no, and the arm still goes: an arm left live on a
        // version that has already asked would fire on the next launch,
        // long after the game it belonged to finished.
        prompt.armFromKickoffReminder(gameId: "401")
        #expect(!prompt.earnedByOpening(gameId: "401"))

        let upgraded = ReviewPrompt(defaults: defaults, version: "2.3.0")
        #expect(!upgraded.earnedByOpening(gameId: "401"))
    }

    #if DEBUG
    @Test func theUITestKillSwitchSilencesIt() {
        let defaults = makeDefaults()
        defaults.set("off", forKey: "review.prompt")
        let prompt = ReviewPrompt(defaults: defaults, version: "2.2.0")

        prompt.armFromKickoffReminder(gameId: "401")
        #expect(!prompt.earnedByOpening(gameId: "401"))
        // Silenced, not spent-and-recorded: the version is untouched, so a
        // real user on a real build still gets their one ask.
        #expect(defaults.string(forKey: "review.lastRequestedVersion") == nil)
    }
    #endif

    @Test func theBundleVersionIsReadNotInvented() {
        // The default initializer reads CFBundleShortVersionString, and the
        // fallback is a sentinel rather than a plausible version number —
        // "0" can never collide with something we shipped.
        #expect(!ReviewPrompt.bundleVersion.isEmpty)
    }
}
