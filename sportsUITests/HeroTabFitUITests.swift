import XCTest

/// Does the team page's six-tab hero row actually fit a phone?
///
/// Filed off the web bug fixed 2026-09-20, where the same five tabs —
/// Overview, Games, Standings, Roster, Trophies — overflowed a 390pt
/// viewport and widened the whole document. SwiftUI has no document to
/// widen, so iOS cannot fail that way; `HeroTabBar` is a plain `HStack`
/// with fixed 40pt spacing, which means an over-wide row is paid for in
/// the labels instead. The question this answers is which, and whether a
/// user ever sees it.
///
/// **Rewritten 2026-09-21, when the question got answered.** Andy's
/// screenshot showed the row *wrapping* — "Overvie/w", "Standi/ngs" —
/// rather than truncating, and `HeroTabBar` became a horizontal
/// `ScrollView`. So "does the row fit?" is no longer the question: it
/// deliberately does not fit, and that is now correct. What must hold
/// instead is that the labels are never squeezed to buy the fit (the
/// 40pt gaps are the tell, and `fixedSize` makes them rigid) and that a
/// tab scrolled off the edge is still reachable.
///
/// Still a measurement as much as a guard: the frames go in the log on
/// every run. Run it at `large` and again at an accessibility size, and
/// read the attached screenshot alongside the numbers — a truncated label
/// still reports its full string through `label`, so an ellipsis is
/// visible to the eye and to nothing else.
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
        // and ESPN serves it a roster — the full six-tab row, which is the
        // only one of the three hero pages at risk. Conference and poll
        // pages carry three tabs (Standings, Games, Postseason) and have
        // room to spare.
        XCTAssertTrue(openTeamPage("Georgia Bulldogs", in: app),
                      "Search should land on the Georgia team page")

        // Six since the Stats tab (2026-09-24).
        let titles = ["Overview", "Games", "Stats", "Standings", "Roster", "Trophies"]
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
                       "Expected all six tabs; got \(present.map(\.0))")

        // The measurements are the point, so they go in the log whether or
        // not anything fails — a passing run at one text size is evidence
        // for the next size, not a closed question.
        let frames = present.map { (title: $0.0, frame: $0.1.frame) }
        for (title, frame) in frames {
            print("hero-tab \(title): x=\(frame.minX) w=\(frame.width)")
        }
        print("window: w=\(window.width)")

        guard let first = frames.first, let last = frames.last else { return }

        // The row starts at the leading edge. It may well end past the
        // trailing one — that is the scroller doing its job — but nothing
        // should begin off the left of the screen at rest.
        XCTAssertGreaterThanOrEqual(
            first.frame.minX, window.minX,
            "\"\(first.title)\" starts off the left edge")

        // No wrapping. `Games` is the shortest label and the last to wrap,
        // so every tab matching its height is the cheap proof that none of
        // them broke onto a second line — the exact failure Andy shot on
        // 2026-09-21, where even "Game/s" had split.
        let single = frames.map(\.frame.height).min() ?? 0
        for (title, frame) in frames {
            XCTAssertEqual(
                frame.height, single, accuracy: 1,
                """
                "\(title)" is \(frame.height)pt tall against a single-line \
                \(single)pt — the label wrapped. HeroTabBar's lineLimit(1) \
                and fixedSize are what stop this.
                """)
        }

        // No compression. `fixedSize` means the labels refuse to squeeze, so
        // the 40pt gaps must survive intact; a gap that measures short is
        // the row buying its fit out of the text instead of scrolling.
        for (before, after) in zip(frames, frames.dropFirst()) {
            let gap = after.frame.minX - before.frame.maxX
            XCTAssertEqual(
                gap, tabSpacing, accuracy: 1,
                """
                Gap between "\(before.title)" and "\(after.title)" is \(gap), \
                not \(tabSpacing) — the row is being squeezed to fit.
                """)
        }

        // Reachability: whatever hangs off the trailing edge must still be
        // gettable. This is the assertion that earns the ScrollView — a row
        // that overflows without scrolling would pass everything above.
        if last.frame.maxX > window.maxX {
            let row = app.scrollViews["hero-tab-row"]
            XCTAssertTrue(row.exists, "The hero tab row should be a scroller")
            row.swipeLeft()
            let trailing = app.buttons["hero-tab-\(last.title.lowercased())"]
            XCTAssertTrue(trailing.waitForExistence(timeout: 5),
                          "\"\(last.title)\" should survive the scroll")
            XCTAssertTrue(trailing.isHittable,
                          """
                          "\(last.title)" is still not hittable after scrolling \
                          the row — it overflows and cannot be reached.
                          """)
        }
    }
}
