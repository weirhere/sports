import SwiftUI
import UIKit

/// The Gamecast surfaces' paint — the color budget's fourth exception
/// (2026-09-27, widened the same day from "the field" to "the surface").
/// Each surface renders as the place it pictures: turf with the teams'
/// colors in their end zones and the broadcast's yellow line to gain;
/// a maple court; white ice with its red lines. Team colors mark whose
/// shot is whose. Nothing outside `DriveField`, `CourtSurface`,
/// `RinkSurface`, `ShotMarksLayer` and the Roster tab's `FormationField`
/// and `FormationCard` (whose title and chips sit on the same paint) may
/// use these; the rest of the card, and the app, stays monochrome.
///
/// Team color has been in the app once before — TeamPage's hero, 2026-08-25
/// to 2026-08-31 — and came out because it was chrome. This is a picture of
/// a place, the way a logo is a picture of a mark. It was live-only until
/// 2026-10-18, when the formation field — drawn before kickoff and after
/// the final — took the same paint (Andy's call).
nonisolated enum SurfaceColors {
    /// Alternating 10-yard bands. A broadcast's deep turf, not a lawn:
    /// deep enough that off-white names read on it at 4.5:1 and the
    /// chalk doesn't glare, light enough that the black play arrow still
    /// reads (Andy, 2026-10-18, against FotMob's pitch; it was a brighter
    /// (0.353, 0.659, 0.396) in light mode, which carried dark names
    /// muddily). Dark mode deepens it a shade rather than inverting it.
    static let turf = dynamic(light: (0.180, 0.470, 0.270), dark: (0.160, 0.440, 0.250))
    static let turfAlternate = dynamic(light: (0.161, 0.439, 0.247), dark: (0.145, 0.412, 0.231))
    /// Names and captions on turf: off-white, a step down from the chalk,
    /// so the field has one white (the lines) and the type sits under it.
    /// Fixed, because the turf is the same green in both modes.
    static let turfInk = Color(white: 0.94)
    /// The broadcast's first-down line. One yellow, both modes: it only
    /// ever sits on turf.
    static let lineToGain = Color(red: 0.949, green: 0.816, blue: 0.141)
    /// Yard lines, goal lines and the drive's trail.
    static let chalk = Color.white
    /// The last play. Fixed rather than `textPrimary`, which turns white in
    /// dark mode and would vanish into the trail.
    static let ink = Color(white: 0.07)
    /// The court's boards: maple, with the key a shade darker. Dark mode
    /// deepens the wood the way it deepens the turf.
    static let maple = dynamic(light: (0.902, 0.800, 0.612), dark: (0.612, 0.498, 0.322))
    static let paint = dynamic(light: (0.851, 0.725, 0.514), dark: (0.541, 0.431, 0.267))
    /// Ice stays light in both modes — dark ice isn't ice — a touch
    /// dimmer in dark so it doesn't glare off a black page.
    static let ice = dynamic(light: (0.961, 0.973, 0.980), dark: (0.875, 0.898, 0.918))
    static let boards = dynamic(light: (0.604, 0.639, 0.671), dark: (0.420, 0.455, 0.486))
    /// The rink's red lines are the app's one red, not a hockey red.
    static let rinkRed = Color.rankDown
    /// The blue lines, in gray: no blue joins the app for them (D13).
    static let blueLine = Color(white: 0.56)
    /// What type on a surface is drawn in. `text` is the names, captions
    /// and title; `counter` is the type on a `text`-filled chip.
    struct Ink {
        let text: Color
        let counter: Color
    }

    /// Each Starters surface's ink: off-white on turf, green in light mode
    /// and dark gray in dark (dark names on the green read muddy — Andy,
    /// 2026-10-18, against FotMob's pitch); `textPrimary` on maple and ice,
    /// which are light in light mode and the page's grays in dark. The ice
    /// had fixed dark ink until its dark mode turned gray (2026-10-27).
    static func ink(for league: League) -> Ink {
        switch league {
        case .collegeFootball, .nfl: Ink(text: turfInk, counter: ink)
        case .nba, .nhl: Ink(text: .textPrimary, counter: .bgPrimary)
        }
    }

    /// The Starters field's paint. Light mode is the Gamecast's, a picture
    /// of the place; dark mode is the page's own grays — the field
    /// `bgElevated` with `bgHeader` bands, the heading and the lines
    /// `divider` — so the section reads as a darker card with markings
    /// rather than a lit pitch on a black page, and the rink's red line
    /// goes gray with the rest (the Figma sheet's Theme/Dark mode, Andy,
    /// 2026-10-27: "Implement the updated figma designs into the
    /// codebase"). The live Gamecast surfaces keep their colors in dark.
    enum Starters {
        static let turf = grayInDark(SurfaceColors.turf, white: 0.17)
        static let turfAlternate = grayInDark(SurfaceColors.turfAlternate, white: 0.15)
        static let turfHeading = grayInDark(SurfaceColors.turfHeading, white: 0.20)
        static let maple = grayInDark(SurfaceColors.maple, white: 0.15)
        static let paint = grayInDark(SurfaceColors.paint, white: 0.20)
        static let ice = grayInDark(SurfaceColors.ice, white: 0.15)
        static let iceHeading = grayInDark(SurfaceColors.iceHeading, white: 0.20)
        static let rinkRed = grayInDark(SurfaceColors.rinkRed, white: 0.20)
        static let blueLine = grayInDark(SurfaceColors.blueLine, white: 0.20)

        private static func grayInDark(_ light: Color, white: CGFloat) -> Color {
            Color(uiColor: UIColor { traits in
                traits.userInterfaceStyle == .dark
                    ? UIColor(white: white, alpha: 1)
                    : UIColor(light).resolvedColor(with: traits)
            })
        }
    }

    /// The surface's unmarked paint — what the field's own margin, above
    /// its first yard line, is painted in.
    static func base(for league: League) -> Color {
        switch league {
        case .collegeFootball, .nfl: Starters.turf
        case .nba: Starters.maple
        case .nhl: Starters.ice
        }
    }

    /// What the Starters section's title and chips sit on above the field:
    /// the same paint a shade deeper, so the strip reads as the section's
    /// heading and the field starts where the shade changes (Andy,
    /// 2026-10-18 — on one green the title and the first row ran together).
    /// Deeper rather than lighter on turf and maple so the ink keeps its
    /// contrast (off-white on `turfHeading` is 6.1:1); ice, which can't go
    /// darker without stopping being ice, dims a touch instead.
    static func heading(for league: League) -> Color {
        switch league {
        case .collegeFootball, .nfl: Starters.turfHeading
        case .nba: Starters.paint
        case .nhl: Starters.iceHeading
        }
    }
    static let turfHeading = dynamic(light: (0.150, 0.400, 0.230), dark: (0.135, 0.370, 0.210))
    static let iceHeading = dynamic(light: (0.918, 0.933, 0.945), dark: (0.835, 0.858, 0.878))

    /// A surface color as the bare hex `LogoImage(outlineAgainst:)` takes,
    /// resolved for one appearance — so a mark on the Starters strips is
    /// checked against the turf it actually sits on.
    static func hex(_ color: Color, isDark: Bool) -> String {
        let traits = UITraitCollection(userInterfaceStyle: isDark ? .dark : .light)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).resolvedColor(with: traits).getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "%02x%02x%02x", Int((r * 255).rounded()), Int((g * 255).rounded()),
                      Int((b * 255).rounded()))
    }

    /// An end zone or shot mark whose team shipped no usable color.
    static let teamMarkFallback = Color(uiColor: UIColor { traits in
        UIColor(white: traits.userInterfaceStyle == .dark ? 0.30 : 0.78, alpha: 1)
    })

    /// A team's end zone or shot mark, or the fallback gray. The primary
    /// color unless it would vanish against what's behind it — near-black
    /// in dark mode, near-white in light — in which case the alternate, and
    /// gray when neither is usable. Court and ice are light in both modes,
    /// so their marks always ask with `isDark: false`.
    static func teamMark(primary: String?, alternate: String?, isDark: Bool) -> Color {
        teamMarkHex(primary: primary, alternate: alternate, isDark: isDark)
            .flatMap(rgb(hex:))
            .map { Color(red: $0.r, green: $0.g, blue: $0.b) }
            ?? teamMarkFallback
    }

    /// `teamMark`'s choice as the hex it picked, so the guard is testable
    /// without resolving a `Color`.
    static func teamMarkHex(primary: String?, alternate: String?, isDark: Bool) -> String? {
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
