import XCTest

/// The live drive card (2026-09-27) against the scripted fixture: the
/// always-live game carries a six-play drive that gains a play every
/// three ticks, so a short wait walks the field through a run, a pass, a
/// sack and on into the touchdown. Screenshots are attached for eyes-on
/// review; the assertion is only that the card is there and says what it
/// is.
final class GamecastCardUITests: XCTestCase {

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    func testLiveGameShowsTheCurrentDriveCard() throws {
        let app = XCUIApplication()
        app.launchArguments += [
            "-ui.onboardingSeen", "YES",
            // Live games only: fewer rows, so the list shifts less under
            // the tap while the fixture churns.
            "-ui.liveOnly", "YES",
            "-ui.followPromptDismissed", "YES",
            "-ui.scoreFilter", "none",
            "-ui.appearance", "system",
            "-review.prompt", "off",
            "-data.provider", "fixture",
            "-poll.interval", "0.5",
        ]
        app.launch()

        let row = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Alpha State"))
            .firstMatch
        let card = app.descendants(matching: .any)
            .matching(NSPredicate(format: "label CONTAINS %@", "Alpha State ball"))
            .firstMatch
        // The slate reorders under a tap as the fixture ticks, so a tap can
        // land on the neighboring game. Back out and try again.
        var opened = false
        for _ in 1...3 where !opened {
            XCTAssertTrue(scrollUntilExists(row, in: app), "the live fixture game never appeared")
            app.coordinate(withNormalizedOffset: .zero)
                .withOffset(CGVector(dx: row.frame.midX, dy: row.frame.midY))
                .tap()
            opened = card.waitForExistence(timeout: 8)
            if !opened, app.navigationBars.buttons.firstMatch.exists {
                app.navigationBars.buttons.firstMatch.tap()
            }
        }
        XCTAssertTrue(opened, "the current drive card never appeared")

        // Query-free waits between shots: a hold that polls the
        // accessibility tree can ghost-activate controls on iOS 26.5.
        // GAMECAST_HOLD=<seconds> keeps the card on screen, query-free,
        // for a look from outside the test (the simulator panel, simctl
        // screenshots, a recording).
        if let hold = ProcessInfo.processInfo.environment["GAMECAST_HOLD"].flatMap(Double.init) {
            Thread.sleep(forTimeInterval: hold)
        }
        for shot in 1...4 {
            let attachment = XCTAttachment(screenshot: app.screenshot())
            attachment.name = "gamecast-\(shot)"
            attachment.lifetime = .keepAlways
            add(attachment)
            Thread.sleep(forTimeInterval: 2.5)
        }
    }
}
