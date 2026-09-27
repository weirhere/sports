import SwiftUI
import UIKit

/// TeamPage's header in the team's own color — light mode only (Andy,
/// 2026-09-27: "in dark mode, this looks great, but when we're in light
/// mode, the background of the page header should be the team color").
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
struct TeamHeaderPaint: Equatable {
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

    /// Colors seen this launch, by follow key — the schedule is the only
    /// payload carrying one, so without this every visit opens white and
    /// turns team-colored when the request lands.
    static var remembered: [String: String] = [:]

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
            TeamHeaderPaint.contrast(SurfaceColors.luminance($0), groundLum) < minimumContrast
        }.count
        return Double(close) / Double(pixels.count) >= conflictShare
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
