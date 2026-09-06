import XCTest

/// Installs the StatSide widget from the Home Screen gallery, waits for it
/// to render the followed team's game, and taps through the deep link.
/// Springboard automation is version-sensitive; label fallbacks cover the
/// iOS 17–26 gallery variants.
final class WidgetUITests: XCTestCase {
    @MainActor
    func testWidgetInstallsRendersAndDeepLinks() throws {
        // The widget reads follows from the App Group; make sure one exists
        // by driving the app first (argument-domain overrides don't reach
        // the widget process, so the follow must be really persisted).
        let app = XCUIApplication()
        app.launchArguments += ["-ui.onboardingSeen", "YES"]
        app.launch()
        // The Add teams sheet is where a follow starts now (the Teams tab
        // lists follows rather than the directory). A no-op if a previous
        // run already followed Georgia.
        XCTAssertTrue(followTeam("Georgia Bulldogs", in: app),
                      "The Add teams sheet should follow Georgia")
        // The reminder offer may ride the sheet's dismissal on a fresh
        // install; it isn't this suite's subject.
        let offer = app.alerts["Get kickoff reminders?"]
        if offer.waitForExistence(timeout: 3) {
            tapUntilDismissed(offer.buttons["Not Now"], dismissing: offer, via: app)
        }
        XCTAssertTrue(app.teamCard("Georgia Bulldogs").waitForExistence(timeout: 10),
                      "The follow should leave a card on the Teams tab")

        // To the Home Screen; enter jiggle mode.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        XCUIDevice.shared.press(.home)
        sleep(1)
        springboard.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55))
            .press(forDuration: 2.0)

        let edit = springboard.buttons["Edit"]
        if edit.waitForExistence(timeout: 5) {
            edit.tap()
            let addFromMenu = springboard.buttons["Add Widget"]
            XCTAssertTrue(addFromMenu.waitForExistence(timeout: 5),
                          "Edit menu should offer Add Widget")
            addFromMenu.tap()
        } else {
            // Older gallery entry: a "+" button while jiggling.
            let plus = springboard.buttons["Add widget"]
            XCTAssertTrue(plus.waitForExistence(timeout: 5),
                          "Jiggle mode should offer the widget gallery")
            plus.tap()
        }

        let gallerySearch = springboard.searchFields.firstMatch
        XCTAssertTrue(gallerySearch.waitForExistence(timeout: 5),
                      "Widget gallery should have a search field")
        gallerySearch.tap()
        gallerySearch.typeText("StatSide")
        let entry = springboard.cells.staticTexts["StatSide"].firstMatch
        XCTAssertTrue(entry.waitForExistence(timeout: 5),
                      "Gallery search should surface StatSide")
        // The gallery row reports not-hittable; a coordinate tap lands anyway.
        entry.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()

        // The add button's label has a leading space on some versions.
        let addButton = [" Add Widget", "Add Widget"]
            .map { springboard.buttons[$0] }
            .first { $0.waitForExistence(timeout: 3) }
        XCTAssertNotNil(addButton, "Widget detail should offer Add Widget")
        addButton?.tap()
        XCUIDevice.shared.press(.home)

        // The provider fetches the scoreboard, then renders team lines.
        // The gallery's first page is the medium family now; both system
        // sizes carry the ★ Following header, and "UGA" is Georgia's
        // abbreviation in a game row.
        XCTAssertTrue(springboard.staticTexts["Following"].firstMatch.waitForExistence(timeout: 30),
                      "Widget should render the Following header")
        let rendered = springboard.staticTexts["UGA"].firstMatch
        XCTAssertTrue(rendered.waitForExistence(timeout: 30),
                      "Widget should render the followed team's game")

        // Tap-through: widgetURL → statside://game/{id} → game lands in-app.
        rendered.tap()
        XCTAssertTrue(app.wait(for: .runningForeground, timeout: 10),
                      "Widget tap should foreground the app")
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 15),
                      "Deep link should push the game detail")
    }
}
