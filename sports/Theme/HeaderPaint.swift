import SwiftUI
import UIKit

/// An entity page's header in its own color — light mode only (Andy,
/// 2026-09-27: "in dark mode, this looks great, but when we're in light
/// mode, the background of the page header should be the team color";
/// the same day, "let's do this change for leagues as well"). TeamPage
/// paints ESPN's team color, and PlayerPage and CoachPage paint the
/// person's team's (2026-10-03); ConferencePage and PollScreen paint the
/// league's ESPN color on a whole-league page and the mark's own dominant
/// color everywhere else (`LogoContrast.dominantHex`), since ESPN ships
/// no conference colors.
///
/// The team-color hero ran once before (2026-08-25 to 2026-08-31) and came
/// out in both appearances. Dark mode keeps what replaced it: a `bgCard`
/// header that reads as one surface with the cards, where a saturated band
/// on a black page glared. Light mode is where the white header had nothing
/// to say about whose page this is.
///
/// Everything painted on the ground takes its ink from here — one ink, the
/// one with more contrast against the color, so a pale team color gets
/// black type rather than white type it can't carry.
struct HeaderPaint: Equatable {
    /// The color as ESPN sent it; the logo outline tests against it.
    let hex: String
    let background: Color
    /// White on most team colors, black on the pale ones.
    let ink: Color
    /// Whether `ink` is white — the nav bar's color scheme follows it, so
    /// the system back button and the toolbar controls flip with the type.
    let isDarkGround: Bool

    /// Nil in dark mode, for a team with no usable color, and for one so
    /// pale it would just be a slightly tinted white header.
    init?(hex: String?, colorScheme: ColorScheme) {
        guard colorScheme == .light, let hex,
              let rgb = SurfaceColors.rgb(hex: hex) else { return nil }
        let lum = SurfaceColors.luminance(rgb)
        guard lum <= 0.8 else { return nil }
        self.hex = hex
        background = Color(red: rgb.r, green: rgb.g, blue: rgb.b)
        isDarkGround = Self.prefersWhiteInk(luminance: lum)
        ink = isDarkGround ? .white : .black
    }

    /// Team colors seen this launch, by follow key — the schedule is the
    /// only payload carrying one, so without this every visit opens white
    /// and turns team-colored when the request lands.
    static var remembered: [String: String] = [:]

    /// A team's color for a page that isn't the team's own — a player's
    /// or a coach's header wears their team's (Andy, 2026-10-03). Opened
    /// from the roster, `remembered` already has it; from search or a box
    /// score it costs one `/teams/{id}` request, remembered after.
    static func teamHex(for team: Team?) -> String? {
        guard let team else { return nil }
        return team.colorHex ?? remembered[team.followKey]
    }

    static func loadTeamHex(for team: Team?) async -> String? {
        guard let team else { return nil }
        if let known = teamHex(for: team) { return known }
        guard let hex = await ESPNClient(league: team.league).teamColorHex(teamId: team.id)
        else { return nil }
        remembered[team.followKey] = hex
        return hex
    }

    /// Mark colors worked out this launch, by logo URL — a mark doesn't
    /// change color, and the pixel read is the only cost of the answer.
    private static var markColors: [URL: String] = [:]

    /// The dominant color of a mark already in `LogoCache`, or nil until
    /// `loadMarkHex` has fetched it. Synchronous so a page opened a second
    /// time paints on its first frame.
    static func markHex(for url: URL?) -> String? {
        guard let url else { return nil }
        if let known = markColors[url] { return known }
        guard let image = LogoCache.shared.cachedImage(for: url),
              let hex = LogoContrast.dominantHex(of: image) else { return nil }
        markColors[url] = hex
        return hex
    }

    /// Fetches the mark if it isn't cached yet and works out its color;
    /// the caller bumps its own state so `markHex` gets asked again.
    static func loadMarkHex(for url: URL?) async -> String? {
        guard let url else { return nil }
        if let known = markHex(for: url) { return known }
        guard let image = await LogoCache.shared.image(for: url),
              let hex = LogoContrast.dominantHex(of: image) else { return nil }
        markColors[url] = hex
        return hex
    }

    /// Second-rank ink: the inactive tabs, the badge labels.
    var secondaryInk: Color { ink.opacity(0.78) }
    /// A badge capsule — a wash of the ink over the ground, the way
    /// `bgRecessed` is one step off `bgCard`.
    var badgeFill: Color { ink.opacity(isDarkGround ? 0.18 : 0.10) }

    /// WCAG contrast against white versus against black; the larger wins.
    /// The crossover sits at a luminance of about 0.18.
    nonisolated static func prefersWhiteInk(luminance lum: Double) -> Bool {
        contrast(1, lum) >= contrast(lum, 0)
    }

    nonisolated static func contrast(_ a: Double, _ b: Double) -> Double {
        (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }
}

/// Whether a logo blends into the ground it sits on — Texas's burnt-orange
/// longhorn on Texas's burnt-orange header. ESPN's team color is usually
/// lifted from the mark, so on a team-color ground most logos do.
///
/// Reads the mark's own pixels: a 32×32 downsample, opaque pixels only
/// (anti-aliased edges are part-ground already), and a conflict is any
/// real share of them within 1.6:1 of the ground. Contrast rather than hue
/// distance, because a red mark on an equally dark green is legible only to
/// someone who can tell red from green.
nonisolated enum LogoContrast {
    /// Share of the mark's opaque pixels that may sit close to the ground
    /// before it counts — "if the logo conflicts with that color at all"
    /// (Andy), so low, but above the stray pixel.
    static let conflictShare = 0.02
    static let minimumContrast = 1.6

    static func conflicts(_ image: UIImage, groundHex: String) -> Bool {
        guard let ground = SurfaceColors.rgb(hex: groundHex),
              let pixels = opaquePixels(of: image) else { return false }
        return conflicts(pixels: pixels, ground: ground)
    }

    static func conflicts(pixels: [(r: Double, g: Double, b: Double)],
                          ground: (r: Double, g: Double, b: Double)) -> Bool {
        guard !pixels.isEmpty else { return false }
        let groundLum = SurfaceColors.luminance(ground)
        let close = pixels.lazy.filter {
            HeaderPaint.contrast(SurfaceColors.luminance($0), groundLum) < minimumContrast
        }.count
        return Double(close) / Double(pixels.count) >= conflictShare
    }

    /// The color a mark is mostly made of, for a header with no color of
    /// its own — a conference, college football. Colored pixels win over
    /// black and gray whenever there's a real share of them, so the SEC
    /// reads navy-and-gold rather than its black type; near-white never
    /// counts, since it would only make a white header. Pixels are bucketed
    /// at 16 levels a channel and the biggest bucket's average is the
    /// answer. Nil when the mark is all white or won't decode.
    static func dominantHex(of image: UIImage) -> String? {
        opaquePixels(of: image).flatMap(dominantHex(pixels:))
    }

    static func dominantHex(pixels: [(r: Double, g: Double, b: Double)]) -> String? {
        let inked = pixels.filter { SurfaceColors.luminance($0) <= 0.8 }
        let colored = inked.filter { saturation($0) >= 0.25 }
        let pool = Double(colored.count) >= Double(inked.count) * 0.1 && !colored.isEmpty
            ? colored : inked
        guard !pool.isEmpty else { return nil }
        var buckets: [Int: [(r: Double, g: Double, b: Double)]] = [:]
        for p in pool {
            let key = Int(p.r * 15.99) << 8 | Int(p.g * 15.99) << 4 | Int(p.b * 15.99)
            buckets[key, default: []].append(p)
        }
        guard let top = buckets.values.max(by: { $0.count < $1.count }) else { return nil }
        let n = Double(top.count)
        func byte(_ v: Double) -> String { String(format: "%02x", Int((min(max(v, 0), 1) * 255).rounded())) }
        return byte(top.map(\.r).reduce(0, +) / n)
            + byte(top.map(\.g).reduce(0, +) / n)
            + byte(top.map(\.b).reduce(0, +) / n)
    }

    private static func saturation(_ p: (r: Double, g: Double, b: Double)) -> Double {
        let hi = max(p.r, p.g, p.b), lo = min(p.r, p.g, p.b)
        return hi == 0 ? 0 : (hi - lo) / hi
    }

    /// The mark's opaque pixels, un-premultiplied, from a 32×32 redraw.
    private static func opaquePixels(of image: UIImage) -> [(r: Double, g: Double, b: Double)]? {
        guard let cg = image.cgImage else { return nil }
        let side = 32
        var bytes = [UInt8](repeating: 0, count: side * side * 4)
        let drawn = bytes.withUnsafeMutableBytes { buffer -> Bool in
            guard let context = CGContext(
                data: buffer.baseAddress, width: side, height: side,
                bitsPerComponent: 8, bytesPerRow: side * 4,
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.interpolationQuality = .medium
            context.draw(cg, in: CGRect(x: 0, y: 0, width: side, height: side))
            return true
        }
        guard drawn else { return nil }
        var pixels: [(r: Double, g: Double, b: Double)] = []
        for i in stride(from: 0, to: bytes.count, by: 4) {
            let a = Double(bytes[i + 3]) / 255
            guard a > 0.6 else { continue }
            pixels.append((Double(bytes[i]) / 255 / a,
                           Double(bytes[i + 1]) / 255 / a,
                           Double(bytes[i + 2]) / 255 / a))
        }
        return pixels
    }
}

/// The chrome half of a painted header: the status-bar strip, the solid
/// nav bar, and the bar's contents flipped to the header's ink. Nil paint
/// is the monochrome `bgCard` header every entity page had before.
struct HeaderChrome: ViewModifier {
    let paint: HeaderPaint?

    func body(content: Content) -> some View {
        content
            // The header's ground through the status-bar strip and the
            // top bounce.
            .heroTopBand(paint?.background ?? .bgCard)
            // Solid, seamless against the hero at rest — the
            // transparent-until-scrolled dance retired 2026-08-31 and stays
            // retired: a solid colored bar needs no glass trick to read as
            // part of the header.
            .toolbarBackground(paint?.background ?? .bgCard, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            // A dark ground turns the back button and the toolbar's
            // controls white; nil leaves the bar on the app's appearance.
            .toolbarColorScheme(paint.map { $0.isDarkGround ? .dark : .light },
                                for: .navigationBar)
    }
}

extension View {
    func headerChrome(_ paint: HeaderPaint?) -> some View {
        modifier(HeaderChrome(paint: paint))
    }
}
