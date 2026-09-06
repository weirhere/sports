import XCTest

/// The contextual-permission moment: the user's first-ever follow offers
/// kickoff reminders, Enable walks through the system prompt, and the
/// TeamPage bell reflects the result.
final class ReminderOfferUITests: XCTestCase {
    @MainActor
    func testFirstFollowOffersRemindersAndBellTurnsOn() throws {
        let app = XCUIApplication()
        // Argument-domain overrides reach every UserDefaults instance,
        // including the App Group suite, so the app launches as a fresh
        // user: no follows, onboarding seen, reminder offer not yet made.
        //
        // `notifications.enabled` must NOT be overridden here, though it
        // once was: argument-domain values beat the app's own writes, and
        // `refreshAuthorization()` re-reads that key on scene-active — the
        // grant would flip the bell on, then the prompt's dismissal would
        // re-activate the scene and the refresh would read the override's
        // NO and flip it straight back off. Fresh state for that key comes
        // from a fresh install instead: uninstall the app before this
        // suite (the release checklist already does), or the offer may
        // not appear and the first assert fails.
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.notificationsPrompted", "NO",
                                // Empty the league-qualified follow set —
                                // the pre-league key stopped being read
                                // when the namespacing migration landed.
                                "-following.teamKeys", "()"]
        app.launch()

        // Teams lists the teams you follow now, so the first follow comes
        // from the Add teams sheet. The offer rides the sheet's dismissal
        // rather than the tap itself — a SwiftUI alert can't present over
        // a sheet anchored to the same view, so it waits for the sheet to
        // go (which is what onboarding's first follow always did too).
        XCTAssertTrue(followTeam("Georgia Bulldogs", in: app),
                      "The Add teams sheet should follow Georgia")

        // The one-time offer rides the first follow.
        let offer = app.alerts["Get kickoff reminders?"]
        XCTAssertTrue(offer.waitForExistence(timeout: 5),
                      "First follow should offer kickoff reminders")
        // Both panels here — the app's SwiftUI alert and springboard's
        // permission prompt — hit the iOS 26.5 tap-lands-nowhere trap;
        // tapUntilDismissed carries the coordinate-tap fallback.
        tapUntilDismissed(offer.buttons["Enable"], dismissing: offer, via: app)

        // System permission prompt lives in springboard, not the app.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            tapUntilDismissed(allow, dismissing: allow, via: app)
        }

        // The bell lives on the team page, one tap from the followed card.
        let card = app.teamCard("Georgia Bulldogs")
        XCTAssertTrue(card.waitForExistence(timeout: 10),
                      "The follow should leave a card on the Teams tab")
        card.tap()

        let bellOn = app.buttons["Kickoff reminders on"]
        XCTAssertTrue(bellOn.waitForExistence(timeout: 10),
                      "Granting permission should flip the bell on")
    }
}
