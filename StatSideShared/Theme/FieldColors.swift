import SwiftUI
import UIKit

/// The Gamecast field's paint — the color budget's fourth exception
/// (2026-09-27). The live drive card's field renders as a field: turf, the
/// two teams' colors in their end zones, and the broadcast's yellow line to
/// gain. Nothing outside `DriveField` may use these; the rest of the card,
/// and the app, stays monochrome.
///
/// Team color has been in the app once before — TeamPage's hero, 2026-08-25
/// to 2026-08-31 — and came out because it was chrome. This is a picture of
/// a place, the way a logo is a picture of a mark, and it is only ever drawn
/// while a game is live.
nonisolated enum FieldColors {
    /// Alternating 10-yard bands. Dark mode deepens the turf rather than
    /// inverting it, so the black play arrow still reads on it.
    static let turf = dynamic(light: (0.353, 0.659, 0.396), dark: (0.239, 0.502, 0.286))
    static let turfAlternate = dynamic(light: (0.322, 0.627, 0.365), dark: (0.216, 0.459, 0.263))
    /// The broadcast's first-down line. One yellow, both modes: it only
    /// ever sits on turf.
    static let lineToGain = Color(red: 0.949, green: 0.816, blue: 0.141)
    /// Yard lines, goal lines and the drive's trail.
    static let chalk = Color.white
    /// The last play. Fixed rather than `textPrimary`, which turns white in
    /// dark mode and would vanish into the trail.
    static let ink = Color(white: 0.07)
    /// An end zone whose team shipped no usable color.
    static let endZoneFallback = Color(uiColor: UIColor { traits in
        UIColor(white: traits.userInterfaceStyle == .dark ? 0.30 : 0.78, alpha: 1)
    })

    /// A team's end zone, or the fallback gray. The primary color unless it
    /// would vanish against the page — near-black in dark mode, near-white
    /// in light — in which case the alternate, and gray when neither is
    /// usable.
    static func endZone(primary: String?, alternate: String?, isDark: Bool) -> Color {
        endZoneHex(primary: primary, alternate: alternate, isDark: isDark)
            .flatMap(rgb(hex:))
            .map { Color(red: $0.r, green: $0.g, blue: $0.b) }
            ?? endZoneFallback
    }

    /// `endZone`'s choice as the hex it picked, so the guard is testable
    /// without resolving a `Color`.
    static func endZoneHex(primary: String?, alternate: String?, isDark: Bool) -> String? {
        for candidate in [primary, alternate] {
            guard let candidate, let rgb = rgb(hex: candidate) else { continue }
            let lum = luminance(rgb)
            if isDark ? lum >= 0.012 : lum <= 0.8 { return candidate }
        }
        return nil
    }

    /// ESPN ships colors as bare hex, "970310". A leading "#" is tolerated;
    /// anything else that isn't six hex digits is no color at all.
    static func rgb(hex: String) -> (r: Double, g: Double, b: Double)? {
        let digits = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        guard digits.count == 6, let value = UInt32(digits, radix: 16) else { return nil }
        return (Double((value >> 16) & 0xFF) / 255,
                Double((value >> 8) & 0xFF) / 255,
                Double(value & 0xFF) / 255)
    }

    /// WCAG relative luminance.
    static func luminance(_ rgb: (r: Double, g: Double, b: Double)) -> Double {
        func linear(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(rgb.r) + 0.7152 * linear(rgb.g) + 0.0722 * linear(rgb.b)
    }

    private static func dynamic(light: (Double, Double, Double),
                                dark: (Double, Double, Double)) -> Color {
        Color(uiColor: UIColor { traits in
            let c = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: c.0, green: c.1, blue: c.2, alpha: 1)
        })
    }
}
