import XCTest

/// Live-network smoke test: every tab renders real data, and following a
/// team from browse makes the Following section appear on Scores.
final class SmokeUITests: XCTestCase {
    @MainActor
    func testTabsAndFollowFlow() throws {
        let app = XCUIApplication()
        app.launch()

        // Scores loads a real slate.
        XCTAssertTrue(app.staticTexts["SEC"].waitForExistence(timeout: 15),
                      "Scores should show the SEC section header")

        // Rankings shows a poll with a #1 row.
        app.tabBars.buttons["Rankings"].tap()
        XCTAssertTrue(app.buttons["AP"].waitForExistence(timeout: 15),
                      "Rankings should show the AP chip")
        snapshot(app, "rankings")

        // Teams browse + search + follow.
        app.tabBars.buttons["Teams"].tap()
        XCTAssertTrue(app.staticTexts["ACC"].waitForExistence(timeout: 15),
                      "Teams should show the ACC conference header")
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 5))
        search.tap()
        search.typeText("Georgia Bulldogs")
        let row = app.staticTexts["Georgia"].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "Search should surface Georgia")
        row.tap()

        // Team page: follow (tolerate an already-followed state from a
        // previous run — follows persist on the simulator).
        let follow = app.buttons["Follow"].firstMatch
        if follow.waitForExistence(timeout: 10) {
            follow.tap()
        }
        XCTAssertTrue(app.buttons["Following"].firstMatch.waitForExistence(timeout: 5),
                      "Follow should flip to Following")
        snapshot(app, "team-page")

        // Scores now leads with the Following section.
        app.tabBars.buttons["Scores"].tap()
        XCTAssertTrue(app.staticTexts["FOLLOWING"].waitForExistence(timeout: 10),
                      "Following section should appear once a team is followed")
        snapshot(app, "scores-following")

        // Into a game detail from the (already expanded) Following section.
        let gameLink = app.buttons.containing(.staticText, identifier: "Georgia").firstMatch
        XCTAssertTrue(gameLink.waitForExistence(timeout: 5), "Following should list a Georgia game row")
        gameLink.tap()
        XCTAssertTrue(app.navigationBars.firstMatch.waitForExistence(timeout: 10),
                      "Tapping a game row should push the game detail")
        snapshot(app, "game-detail")
    }

    @MainActor
    private func snapshot(_ app: XCUIApplication, _ name: String) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
