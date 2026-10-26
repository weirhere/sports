import SnapshotTesting
import SwiftUI
import Testing
import UIKit
@testable import StatSide

/// Pixel baselines for the surfaces Andy iterates on by eye (2026-10-19):
/// the Starters card, the game header in both of its states, and the
/// Scores day strip — each on an iPhone 17 Pro and an iPhone SE, light
/// and dark, with football, basketball and hockey data. The PNGs live in
/// `__Snapshots__/ComponentSnapshotTests/` beside this file and are
/// committed; a UI change re-records only the ones it touches
/// (`scripts/snapshot-tests.sh --record --filter <test>`), and
/// `scripts/ui-report.py` lays the before and after side by side.
///
/// Gated on `STATSIDE_SNAPSHOTS=1` (the script sets it): the baselines
/// are recorded on the iOS 26.5 iPhone 17 Pro simulator, and a runner on
/// another runtime renders text a pixel differently. CI runs the rest of
/// `sportsTests` and skips these.
///
/// Every snapshot is the component at the device's width, as tall as it
/// lays out — not a full screen with a component in it — rendered at the
/// device's scale with its traits, at the default text size.
///
/// One component at a time is `STATSIDE_SNAPSHOT_FILTER=dayStrip` (a
/// comma-separated list of test names; the script's `--filter`): the
/// others skip. An environment variable rather than `-only-testing`,
/// which selects this suite but matches none of its parameterized
/// functions by either `dayStrip` or `dayStrip(_:)` (Xcode 26.6).
@MainActor
@Suite(.serialized, .enabled(if: ProcessInfo.processInfo.environment["STATSIDE_SNAPSHOTS"] == "1",
                             "set STATSIDE_SNAPSHOTS=1 (scripts/snapshot-tests.sh does) to run the pixel baselines"))
struct ComponentSnapshotTests {
    enum Device: String, CaseIterable {
        case iPhone17Pro, iPhoneSE

        var width: CGFloat {
            switch self {
            case .iPhone17Pro: 402
            case .iPhoneSE: 375
            }
        }

        var scale: CGFloat {
            switch self {
            case .iPhone17Pro: 3
            case .iPhoneSE: 2
            }
        }
    }

    /// One cell of the matrix: sport × device × appearance.
    struct Variant: CustomTestStringConvertible, Sendable {
        let sport: SnapshotFixtures.Sport
        let device: Device
        let scheme: ColorScheme

        var name: String { "\(sport.rawValue)-\(device.rawValue)-\(scheme == .dark ? "dark" : "light")" }
        var testDescription: String { name }

        static let all: [Variant] = SnapshotFixtures.Sport.allCases.flatMap { sport in
            Device.allCases.flatMap { device in
                [ColorScheme.light, .dark].map { Variant(sport: sport, device: device, scheme: $0) }
            }
        }
    }

    // MARK: - The components

    @Test(.enabled(if: snapshotSelected("startersCard")), arguments: Variant.all)
    func startersCard(_ variant: Variant) {
        let roster = SnapshotFixtures.roster(variant.sport)
        // The pane's page color behind it: the field runs full bleed and
        // the "Also starting" rows, when any, sit on the page.
        let card = FormationCard(roster: roster, league: variant.sport.league,
                                 offenseTeamId: .constant(nil), layout: .field,
                                 onLayoutChange: { _ in })
            .background(Color.bgRecessed)
        assert(card, variant)
    }

    @Test(.enabled(if: snapshotSelected("gameRow")), arguments: Variant.all)
    func gameRow(_ variant: Variant) {
        // The Scores row as a day section draws it (`timeOnly`), on the
        // card surface: live with the ball, final, pre-game.
        let row = GameRow(game: SnapshotFixtures.game(variant.sport), timeOnly: true)
            .background(Color.bgCard)
        assert(row, variant)
    }

    @Test(.enabled(if: snapshotSelected("gameRowConcealed")), arguments: Variant.all)
    func gameRowConcealed(_ variant: Variant) {
        // Spoiler mode (E30): the same row with its result hidden —
        // records at the trailing edge (rewound for the finals), the live
        // dot and "Live" — or "Final" alone — over "Tap to reveal", no
        // bold or muted name.
        let game = SnapshotFixtures.concealedGame(variant.sport)
        let row = GameRow(game: game, timeOnly: true, onReveal: {})
            .background(Color.bgCard)
            .environment(\.spoilerGuard, SnapshotFixtures.spoilerGuard(hiding: game))
        assert(row, variant)
    }

    @Test(.enabled(if: snapshotSelected("gameHeaderExpanded")), arguments: Variant.all)
    func gameHeaderExpanded(_ variant: Variant) {
        // On the card surface, as the detail screen paints it.
        let header = GameHeader(game: SnapshotFixtures.game(variant.sport), summary: nil)
            .frame(maxWidth: .infinity)
            .background(Color.bgCard)
        assert(header, variant)
    }

    @Test(.enabled(if: snapshotSelected("gameHeaderCompact")), arguments: Variant.all)
    func gameHeaderCompact(_ variant: Variant) {
        // The bar's principal slot, drawn as the bar draws it — the card
        // color with the hairline under it — without the system chrome
        // (back button, pin) either side, which a snapshot can't host.
        let bar = CompactGameHeader(game: SnapshotFixtures.game(variant.sport), summary: nil)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.bgCard)
            .overlay(alignment: .bottom) { Divider().overlay(Color.divider) }
        assert(bar, variant)
    }

    @Test(.enabled(if: snapshotSelected("gameHeaderConcealed")), arguments: Variant.all)
    func gameHeaderConcealed(_ variant: Variant) {
        // Spoiler mode (E30): the status word at the logos' height, the
        // live dot inline before it while the game is on, and the Reveal
        // capsule a full-width row under the records (283); records
        // rewound; no score.
        let hidden = SnapshotFixtures.concealedGame(variant.sport).concealed()
        let header = GameHeader(concealed: hidden, onReveal: {})
            .frame(maxWidth: .infinity)
            .background(Color.bgCard)
        assert(header, variant)
    }

    @Test(.enabled(if: snapshotSelected("gameHeaderCompactConcealed")), arguments: Variant.all)
    func gameHeaderCompactConcealed(_ variant: Variant) {
        // The bar's slot for a concealed game: the status word between
        // the marks, as a postponed game draws it.
        let hidden = SnapshotFixtures.concealedGame(variant.sport).concealed()
        let bar = CompactGameHeader(game: hidden, summary: nil)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Color.bgCard)
            .overlay(alignment: .bottom) { Divider().overlay(Color.divider) }
        assert(bar, variant)
    }

    @Test(.enabled(if: snapshotSelected("dayStrip")), arguments: Variant.all)
    func dayStrip(_ variant: Variant) {
        let today = SnapshotFixtures.today(variant.sport)
        let strip = DayStrip(days: SnapshotFixtures.days(variant.sport),
                             selectedId: DayFormat.id(for: today),
                             todayId: DayFormat.id(for: today),
                             now: today,
                             onSelect: { _ in })
            .background(Color.bgPrimary)
        assert(strip, variant)
    }

    @Test(.enabled(if: snapshotSelected("storyCardStack")), arguments: Variant.all)
    func storyCardStack(_ variant: Variant) {
        // The News tab's stacked cards (Latest, Transfers, a league on the
        // Leagues page) on the recessed page, at the page's inset. The
        // fixtures carry no photos, so each card is its headline and byline
        // — in the second-rank ink, not the first: a `NavigationLink` with
        // no `NavigationStack` above it draws disabled in an offscreen
        // render. The layout is the baseline; the app paints them black.
        let stack = VStack(spacing: Spacing.sm) {
            StoryCardStack(stories: SnapshotFixtures.stories(variant.sport))
        }
        .padding(Spacing.sm)
        .background(Color.bgRecessed)
        assert(stack, variant)
    }

    @Test(.enabled(if: snapshotSelected("newsLeagueSection")), arguments: Variant.all)
    func newsLeagueSection(_ variant: Variant) {
        // One league on the News tab's Leagues page (2026-10-19): the 20pt
        // heading, then a section card — featured story, rows, See more.
        // No photos in the fixtures, so the featured card is its headline,
        // and no mark on the heading: a league's logo is a real URL, and
        // the first two recordings disagreed on whether it had loaded.
        let section = VStack(spacing: Spacing.sm) {
            NewsLeagueSection(league: variant.sport.league,
                              stories: SnapshotFixtures.stories(variant.sport),
                              showsLogo: false)
        }
        .padding(Spacing.sm)
        .background(Color.bgRecessed)
        assert(section, variant)
    }

    @Test(.enabled(if: snapshotSelected("scoresHeader")), arguments: Variant.all)
    func scoresHeader(_ variant: Variant) {
        // The Scores masthead with the focus chip (2026-10-19), one state per
        // sport row of the matrix: football All games, basketball Live,
        // hockey Tight — the three fills the chip can wear.
        let focus: SlateFocus = switch variant.sport {
        case .football: .all
        case .basketball: .live
        case .hockey: .tight
        }
        let header = ScoresHeader(focus: focus, onSelectFocus: { _ in }, onOpenCalendar: {})
            .padding(.bottom, Spacing.sm)
            .background(Color.bgPrimary)
        assert(header, variant)
    }

    @Test(.enabled(if: snapshotSelected("teamStatLeaderCard")), arguments: Variant.all)
    func teamStatLeaderCard(_ variant: Variant) {
        // A league page's Team stats card (2026-10-25): the stat's title
        // with its chevron, then the top three, the leader's number in the
        // filled capsule. On the recessed page at the pane's inset. As
        // with the story cards, a `NavigationLink` with no stack above it
        // draws its rows in the disabled ink offscreen; the layout is the
        // baseline.
        let card = VStack(spacing: Spacing.sm) {
            TeamStatLeaderCard(destination: SnapshotFixtures.teamStatRanking(variant.sport))
        }
        .padding(Spacing.sm)
        .background(Color.bgRecessed)
        .environment(SnapshotFixtures.noFollows)
        assert(card, variant)
    }

    // MARK: - Rendering

    /// The component at the device's width, in the appearance, named for
    /// the cell. `testName` is the calling test's with its `(_:)` dropped,
    /// so the file lands as `<test>.<variant>.png`.
    private func assert(_ view: some View, _ variant: Variant,
                        fileID: StaticString = #fileID, file: StaticString = #filePath,
                        testName: String = #function, line: UInt = #line, column: UInt = #column) {
        let traits = UITraitCollection(traitsFrom: [
            .init(displayScale: variant.device.scale),
            .init(userInterfaceStyle: variant.scheme == .dark ? .dark : .light),
            .init(userInterfaceIdiom: .phone),
            .init(horizontalSizeClass: .compact),
            .init(verticalSizeClass: .regular),
            .init(preferredContentSizeCategory: .large),
        ])
        let sized = view
            .frame(width: variant.device.width)
            .environment(\.colorScheme, variant.scheme)
            // The default text size, whatever the simulator is set to.
            .dynamicTypeSize(.large)
            // The live dot holds at full opacity: its pulse is a layer
            // animation on a shared clock, and a capture lands anywhere in
            // the cycle (the first comparison pass caught it four shades
            // apart). The share card's static render uses the same switch.
            .environment(\.liveDotPulses, false)
        assertSnapshot(of: sized,
                       as: .image(drawHierarchyInKeyWindow: true, layout: .sizeThatFits, traits: traits),
                       named: variant.name,
                       fileID: fileID, file: file,
                       testName: String(testName.prefix { $0 != "(" }),
                       line: line, column: column)
    }
}

/// Whether `STATSIDE_SNAPSHOT_FILTER` names this test, or names nothing.
nonisolated private func snapshotSelected(_ test: String) -> Bool {
    guard let filter = ProcessInfo.processInfo.environment["STATSIDE_SNAPSHOT_FILTER"],
          !filter.isEmpty else { return true }
    return filter.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.contains(test)
}
