import SwiftUI
import XCTest
@testable import StatSide

/// The share card is a fixed artifact: 600 pt wide, always light, type
/// pinned regardless of the sharer's settings. These render every status
/// through `ImageRenderer` (attaching PNGs for eyeball review, the
/// `LiveAccentRenderTests` workflow) and assert the invariants that would
/// fail silently — a dark card in a dark room, a blown-out accessibility
/// render, a crash with no logos.
@MainActor
final class GameShareCardTests: XCTestCase {
    private static let cardWidth: CGFloat = 600
    private static let scale: CGFloat = 3

    func testRendersEveryStatus() throws {
        let cases: [(name: String, view: GameShareCardView)] = [
            ("pre", Self.preCard), ("live", Self.liveCard),
            ("final", Self.finalCard), ("other", Self.otherCard),
        ]
        for (name, view) in cases {
            let image = try XCTUnwrap(render(view), "\(name) card should render")
            XCTAssertEqual(image.size.width * image.scale, Self.cardWidth * Self.scale,
                           "\(name) card width should be fixed")
            let attachment = XCTAttachment(image: image)
            attachment.name = "share-card-\(name)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testRendersWithoutLogos() throws {
        // Airplane mode, cold cache: the card degrades to placeholder
        // discs — it must still produce a valid image, never fail.
        let image = try XCTUnwrap(render(Self.finalCard))
        XCTAssertGreaterThan(image.size.height, 0)
    }

    func testCardStaysLightInsideDarkMode() throws {
        // The render site forces light; a dark ancestor must not leak in.
        let renderer = ImageRenderer(content: AnyView(Self.finalCard
            .frame(width: Self.cardWidth)
            .environment(\.colorScheme, .light))
            .environment(\.colorScheme, .dark))
        renderer.scale = Self.scale
        renderer.isOpaque = true
        let image = try XCTUnwrap(renderer.uiImage)
        let corner = try XCTUnwrap(pixel(of: image, x: 2, y: 2))
        XCTAssertGreaterThan(corner.red, 0.95, "card background should stay white")
        XCTAssertGreaterThan(corner.green, 0.95)
        XCTAssertGreaterThan(corner.blue, 0.95)
    }

    func testRenderIsDeterministic() throws {
        // Catches animation leaking into the render — a pulsing dot
        // captured mid-dim would differ run to run.
        let first = try XCTUnwrap(render(Self.liveCard)?.pngData())
        let second = try XCTUnwrap(render(Self.liveCard)?.pngData())
        XCTAssertEqual(first, second)
    }

    func testTypeIsPinnedAgainstContentSize() throws {
        // The theme's Font tokens bake against UITraitCollection.current,
        // so this renders under an accessibility content size and asserts
        // byte-equality — the version of this test that would actually
        // catch a theme token sneaking into the card.
        let normal = try XCTUnwrap(render(Self.finalCard)?.pngData())
        var scaled: Data?
        UITraitCollection(preferredContentSizeCategory: .accessibilityExtraExtraExtraLarge)
            .performAsCurrent {
                scaled = render(Self.finalCard)?.pngData()
            }
        XCTAssertEqual(normal, try XCTUnwrap(scaled),
                       "share card must not follow the sharer's text size")
    }

    func testTransferableExportsPNGThroughItemProvider() async throws {
        // NSItemProvider.register(_:) drives the same DataRepresentation
        // chain the share sheet does — this is the end-to-end contract:
        // pick a target, get a PNG. Logo URLs are nil here so the export
        // must succeed without any network.
        let game = Game(
            id: "test", date: nil, name: "Vanderbilt at Texas", shortName: "VAN @ TEX",
            weekNumber: 10,
            status: .final(detail: "Final"),
            home: Competitor(
                team: Team(id: "tex", location: "Texas", name: "Longhorns", abbreviation: "TEX",
                           displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil),
                score: 34, record: "8-3", rank: 20, isHome: true, winner: true),
            away: Competitor(
                team: Team(id: "van", location: "Vanderbilt", name: "Commodores", abbreviation: "VAN",
                           displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: nil),
                score: 31, record: "9-2", rank: 9, isHome: false, winner: false),
            broadcast: nil)
        let card = GameShareCard(game: game, summary: nil, shareText: game.shareText)

        let provider = NSItemProvider()
        provider.register(card)
        XCTAssertTrue(provider.registeredTypeIdentifiers.contains("public.png"),
                      "PNG should be the preferred representation")

        let data = try await withCheckedThrowingContinuation { continuation in
            _ = provider.loadDataRepresentation(forTypeIdentifier: "public.png") { data, error in
                if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: error ?? GameShareCard.RenderError.imageUnavailable) }
            }
        }
        XCTAssertEqual(Array(data.prefix(4)), [0x89, 0x50, 0x4E, 0x47], "export should be a PNG")
        XCTAssertGreaterThan(data.count, 1_000)

        let image = try XCTUnwrap(UIImage(data: data))
        let attachment = XCTAttachment(image: image)
        attachment.name = "share-card-exported"
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    // MARK: - Render plumbing

    private func render(_ view: GameShareCardView) -> UIImage? {
        let renderer = ImageRenderer(content: view
            .frame(width: Self.cardWidth)
            .environment(\.colorScheme, .light))
        renderer.scale = Self.scale
        renderer.isOpaque = true
        return renderer.uiImage
    }

    private func pixel(of image: UIImage, x: Int, y: Int)
        -> (red: CGFloat, green: CGFloat, blue: CGFloat)? {
        guard let cgImage = image.cgImage else { return nil }
        var raw = [UInt8](repeating: 0, count: 4)
        guard let context = CGContext(
            data: &raw, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return nil }
        context.draw(cgImage, in: CGRect(x: -x, y: -(cgImage.height - 1 - y),
                                         width: cgImage.width, height: cgImage.height))
        return (CGFloat(raw[0]) / 255, CGFloat(raw[1]) / 255, CGFloat(raw[2]) / 255)
    }

    // MARK: - Fixtures

    private static let preCard = GameShareCardView(
        away: .init(name: "Ball State", record: "0-0", score: nil, rank: nil, winner: nil, logo: nil),
        home: .init(name: "Ohio State", record: "0-0", score: nil, rank: 1, winner: nil, logo: nil),
        statusLine: "Sat, Sep 5 at 12:30 PM\nBTN",
        showsScores: false,
        isLive: false)

    private static let liveCard = GameShareCardView(
        away: .init(name: "Georgia", record: "7-0", score: 24, rank: 5, winner: nil, logo: nil),
        home: .init(name: "Florida", record: "4-3", score: 20, rank: nil, winner: nil, logo: nil),
        statusLine: "Q3 5:24",
        showsScores: true,
        isLive: true)

    private static let finalCard = GameShareCardView(
        away: .init(name: "Vanderbilt", record: "9-2", score: 31, rank: 9, winner: false, logo: nil),
        home: .init(name: "Texas", record: "8-3", score: 34, rank: 20, winner: true, logo: nil),
        statusLine: "Final",
        showsScores: true,
        isLive: false)

    private static let otherCard = GameShareCardView(
        away: .init(name: "Rice", record: "2-4", score: nil, rank: nil, winner: nil, logo: nil),
        home: .init(name: "Memphis", record: "6-1", score: nil, rank: 25, winner: nil, logo: nil),
        statusLine: "Postponed",
        showsScores: false,
        isLive: false)
}
