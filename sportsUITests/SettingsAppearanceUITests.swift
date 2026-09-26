import XCTest

/// Settings' Appearance picker (2026-09-25): a choice sticks across a
/// relaunch, and System hands the scheme back to iOS. Colours can't be read
/// through the accessibility tree, so each state is attached as a screenshot
/// for eyes-on review; what's asserted is the selection.
final class SettingsAppearanceUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testAppearanceChoicePersistsAndSystemRestores() throws {
        let app = XCUIApplication()
        // Start from System whatever the last run left behind; later
        // launches drop the pin so the persisted choice is what's read.
        app.launchArguments += ["-ui.appearance", "system",
                                "-ui.onboardingSeen", "YES",
                                "-ui.scoreFilter", "none",
                                "-review.prompt", "off"]
        app.launch()

        let picker = openSettings(in: app)
        XCTAssertTrue(picker.buttons["System"].isSelected)
        attach(app, "1-system")

        picker.buttons["Dark"].tap()
        XCTAssertTrue(picker.buttons["Dark"].isSelected)
        attach(app, "2-dark")

        picker.buttons["Light"].tap()
        XCTAssertTrue(picker.buttons["Light"].isSelected)
        attach(app, "3-light")

        picker.buttons["Dark"].tap()
        app.terminate()
        app.launchArguments.removeAll { $0 == "-ui.appearance" || $0 == "system" }
        app.launch()

        let reopened = openSettings(in: app)
        XCTAssertTrue(reopened.buttons["Dark"].isSelected, "Dark should survive a relaunch")
        attach(app, "4-dark-after-relaunch")

        reopened.buttons["System"].tap()
        XCTAssertTrue(reopened.buttons["System"].isSelected)
        attach(app, "5-back-to-system")
    }

    @MainActor
    private func openSettings(in app: XCUIApplication) -> XCUIElement {
        let gear = app.buttons["scores-settings-button"]
        XCTAssertTrue(gear.waitForExistence(timeout: 15))
        let picker = app.segmentedControls["settings.appearance"]
        // A tap during the first load can be swallowed; retry until the
        // sheet is up.
        for _ in 0..<3 where !picker.exists {
            gear.tap()
            _ = picker.waitForExistence(timeout: 3)
        }
        XCTAssertTrue(picker.exists, "Settings sheet never showed the Appearance picker")
        return picker
    }

    @MainActor
    private func attach(_ app: XCUIApplication, _ name: String) {
        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = name
        shot.lifetime = .keepAlways
        add(shot)
    }
}
