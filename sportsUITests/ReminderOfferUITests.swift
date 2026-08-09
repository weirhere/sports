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
        // `notifications.enabled` matters on a simulator that has already run
        // this test — the offer is suppressed when reminders are already on,
        // so without the reset the second run never sees the alert.
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.notificationsPrompted", "NO",
                                "-notifications.enabled", "NO",
                                "-following.teamIds", "()"]
        app.launch()

        app.tabBars.buttons["Teams"].tap()
        XCTAssertTrue(app.staticTexts["ACC"].waitForExistence(timeout: 15),
                      "Teams browse should load")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Georgia Bulldogs")
        let row = app.staticTexts["Georgia"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10))
        row.tap()

        let follow = app.buttons["Follow"].firstMatch
        XCTAssertTrue(follow.waitForExistence(timeout: 10),
                      "Fresh launch state should show an unfollowed team")
        follow.tap()

        // The one-time offer rides the first follow.
        let offer = app.alerts["Get kickoff reminders?"]
        XCTAssertTrue(offer.waitForExistence(timeout: 5),
                      "First follow should offer kickoff reminders")
        offer.buttons["Enable"].tap()

        // System permission prompt lives in springboard, not the app.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        let allow = springboard.buttons["Allow"]
        if allow.waitForExistence(timeout: 5) {
            allow.tap()
        }

        let bellOn = app.buttons["Kickoff reminders on"]
        XCTAssertTrue(bellOn.waitForExistence(timeout: 10),
                      "Granting permission should flip the bell on")
    }
}
