import SwiftUI
import XCTest
@testable import StatSide

/// Not a test of behavior — a camera for open question #2 (live accent
/// color). Renders the live GameRow with the red accent and with a
/// monochrome dot, light and dark, and attaches PNGs for review.
@MainActor
final class LiveAccentRenderTests: XCTestCase {
    func testRenderLiveAccentComparison() throws {
        for scheme in [ColorScheme.light, .dark] {
            // Static dots — otherwise the renderer catches the pulse
            // mid-dim and both come out pale.
            let renderer = ImageRenderer(content: comparison
                .frame(width: 393)
                .background(Color.bgPrimary)
                .environment(\.colorScheme, scheme)
                .environment(\.liveDotPulses, false))
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage, "render should produce an image")
            let attachment = XCTAttachment(image: image)
            attachment.name = "live-accent-\(scheme == .light ? "light" : "dark")"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    private var comparison: some View {
        VStack(alignment: .leading, spacing: 0) {
            caption("RED ACCENT (current)")
            GameRow(game: Self.liveGame)
            caption("MONOCHROME")
            GameRow(game: Self.liveGame)
                .environment(\.liveDotColor, .textPrimary)
        }
        .padding(.vertical, Spacing.md)
    }

    private func caption(_ text: String) -> some View {
        Text(text)
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
    }

    private static let liveGame: Game = {
        let georgia = Team(id: "61", location: "Georgia", name: "Bulldogs", abbreviation: "UGA",
                           displayName: "Georgia Bulldogs", shortDisplayName: "Georgia",
                           logoURL: nil, conferenceId: 8)
        let tennessee = Team(id: "2633", location: "Tennessee", name: "Volunteers", abbreviation: "TENN",
                             displayName: "Tennessee Volunteers", shortDisplayName: "Tennessee",
                             logoURL: nil, conferenceId: 8)
        return Game(
            id: "live", date: .now, name: nil, shortName: "UGA @ TENN", weekNumber: 5,
            status: .live(displayClock: "5:24", period: 3, detail: nil, possessionTeamId: "61"),
            home: Competitor(team: tennessee, score: 17, record: "4-1", rank: 12, isHome: true, winner: nil),
            away: Competitor(team: georgia, score: 24, record: "5-0", rank: 3, isHome: false, winner: nil),
            broadcast: "ESPN")
    }()
}
