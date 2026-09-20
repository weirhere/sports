import XCTest

/// Does the team page's five-tab hero row actually fit a phone?
///
/// Filed off the web bug fixed 2026-09-20, where the same five tabs —
/// Overview, Games, Standings, Roster, Trophies — overflowed a 390pt
/// viewport and widened the whole document. SwiftUI has no document to
/// widen, so iOS cannot fail that way; `HeroTabBar` is a plain `HStack`
/// with fixed 40pt spacing, which means an over-wide row is paid for in
/// the labels instead. The question this answers is which, and whether a
/// user ever sees it.
///
/// It is a measurement, not a regression guard. A pass says the row fits
/// at this text size on this device; it does not say a `ScrollView` is
/// unnecessary at every size on every device, which is what the backlog
/// item actually asks. Run it at `large` and again at an accessibility
/// size, and read the attached screenshot alongside the numbers — a
/// truncated label still reports its full string through `label`, so the
/// ellipsis is visible to the eye and to nothing else.
///
///     xcrun simctl ui <udid> content_size large
///     xcodebuild test -scheme sports \
///       -destination "id=<udid>" \
///       -only-testing:sportsUITests/HeroTabFitUITests \
///       -parallel-testing-enabled NO
///
/// Pass the UDID, never the device name: `iPhone 17 Pro` exists on several
/// runtimes and xcodebuild's pick between them isn't stable. And reset the
/// content size afterwards — it persists on the simulator and takes
/// unrelated suites down with it.
final class HeroTabFitUITests: XCTestCase {
    /// `HeroTabBar`'s spacing, from Theme/HeroTabBar.swift. The `HStack`
    /// holds it rigid, so it is the gap that survives a squeeze while the
    /// labels are what give.
    private let tabSpacing: CGFloat = 40

    @MainActor
    func testTeamPageTabRowFitsTheScreen() throws {
        let app = XCUIApplication()
        // The slate filter persists across launches by design (2026-08-29),
        // so a run inherits whatever the last one left selected. This suite
        // only passes through Scores on its way to Search, but an inherited
        // filter changes what that screen is doing while we walk past it.
        app.launchArguments += ["-ui.onboardingSeen", "YES",
                                "-ui.scoreFilter", "none"]
        app.launch()

        // Georgia: an FBS team with a conference, so Standings is present,
        // and ESPN serves it a roster — the full five-tab row, which is the
        // only one of the three hero pages at risk. Conference and poll
        // pages carry three tabs (Standings, Games, Postseason) and have
        // room to spare.
        XCTAssertTrue(openTeamPage("Georgia Bulldogs", in: app),
                      "Search should land on the Georgia team page")

        let titles = ["Overview", "Games", "Standings", "Roster", "Trophies"]
        let tabs = titles.map { app.buttons["hero-tab-\($0.lowercased())"] }
        XCTAssertTrue(tabs[0].waitForExistence(timeout: 10),
                      "The team page should show its hero tab row")

        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "hero-tab-row"
        attachment.lifetime = .keepAlways
        add(attachment)

        let window = app.windows.firstMatch.frame
        let present = zip(titles, tabs).filter { $0.1.exists }
        XCTAssertEqual(present.count, titles.count,
                       "Expected all five tabs; got \(present.map(\.0))")

        // The measurements are the point, so they go in the log whether or
        // not anything fails — a passing run at one text size is evidence
        // for the next size, not a closed question.
        let frames = present.map { (title: $0.0, frame: $0.1.frame) }
        for (title, frame) in frames {
            print("hero-tab \(title): x=\(frame.minX) w=\(frame.width)")
        }
        print("window: w=\(window.width)")

        guard let first = frames.first, let last = frames.last else { return }

        // Clipping: a row wider than the screen, with the far end off it.
        XCTAssertGreaterThanOrEqual(
            first.frame.minX, window.minX,
            "\"\(first.title)\" starts off the left edge — the row is clipped")
        XCTAssertLessThanOrEqual(
            last.frame.maxX, window.maxX,
            """
            "\(last.title)" ends at \(last.frame.maxX) past the screen's \
            \(window.maxX) — the row is wider than the phone. This is the \
            iOS half of the 2026-09-20 web bug (BACKLOG E5).
            """)

        // Compression: the `HStack` holds 40pt spacing rigid, so a row that
        // has to fit takes it out of the labels. Gaps that measure right
        // while the row still spans the full screen is what a squeeze looks
        // like from here; the screenshot shows the ellipses.
        for (before, after) in zip(frames, frames.dropFirst()) {
            let gap = after.frame.minX - before.frame.maxX
            XCTAssertEqual(
                gap, tabSpacing, accuracy: 1,
                """
                Gap between "\(before.title)" and "\(after.title)" is \(gap), \
                not \(tabSpacing) — the row is being squeezed to fit.
                """)
        }
    }
}
