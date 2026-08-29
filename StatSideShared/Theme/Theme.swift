import SwiftUI
import UIKit

// MARK: - Color tokens
// The mono ramp plus the single live accent. Views reference these semantic
// names only — never raw colors. Light and dark are the same design inverted.
extension Color {
    // UIKit's dynamic provider is the only way to define scheme-adaptive colors
    // in code without asset-catalog entries; UIKit stays contained to this file.
    private init(lightWhite: CGFloat, darkWhite: CGFloat) {
        self.init(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark
                ? UIColor(white: darkWhite, alpha: 1)
                : UIColor(white: lightWhite, alpha: 1)
        })
    }

    static let bgPrimary = Color(lightWhite: 1.00, darkWhite: 0.00)
    /// The page surface accordion cards sit on. FotMob-strength gray: dark
    /// enough that white cards pop by contrast alone, no shadow needed.
    /// Not darker than 0.93 — textSecondary sits directly on it (onboarding
    /// subtitle) and 0.93 is the floor that keeps 4.5:1 (see textSecondary).
    static let bgRecessed = Color(lightWhite: 0.93, darkWhite: 0.08)
    static let bgElevated = Color(lightWhite: 0.93, darkWhite: 0.10)
    /// Accordion header fill: a whisper off the card, FotMob-subtle. The
    /// card-vs-page contrast comes from bgRecessed, not from this tint.
    /// Light value is #f8f8f8.
    static let bgHeader = Color(lightWhite: 248 / 255, darkWhite: 0.05)
    /// Soft black, not #000: true black on white causes eye strain at
    /// reading sizes. Still ~17:1 on bgPrimary. Dark mode keeps pure white —
    /// the strain problem is black-on-white, and white-on-black text at our
    /// sizes hasn't shown halation. Matches the Figma `text/primary` variable.
    static let textPrimary = Color(lightWhite: 0.10, darkWhite: 1.00)
    /// 0.42, not 0.44: the darkest surfaces secondary text sits on are
    /// bgElevated and bgRecessed (0.93), and 0.44 lands at 4.22:1 there —
    /// under WCAG AA's 4.5:1. At 0.42 every surface clears it (worst case
    /// 4.55:1); dark mode clears comfortably (6.5:1+).
    static let textSecondary = Color(lightWhite: 0.42, darkWhite: 0.62)
    static let divider = Color(lightWhite: 0.88, darkWhite: 0.20)

    /// The live indicator and live-score emphasis — green since
    /// 2026-08-29 (Andy's call, formerly the app's red). Shares rankUp's
    /// green so the app carries exactly one green.
    static let liveAccent = rankUp

    /// Rankings movement: up. Light-mode green is darkened to clear WCAG AA
    /// (4.5:1) against bgPrimary; dark mode brightens instead.
    static let rankUp = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 0.20, green: 0.82, blue: 0.40, alpha: 1)
            : UIColor(red: 0.00, green: 0.52, blue: 0.22, alpha: 1)
    })

    /// Rankings movement: down — the app's one red, no longer shared with
    /// the live accent.
    static let rankDown = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1)
            : UIColor(red: 0.84, green: 0.00, blue: 0.08, alpha: 1)
    })

    /// Backing disc behind conference marks in section headers: clear in
    /// light mode, a soft light disc in dark so navy marks (Big Ten, ACC)
    /// don't sink into black. Chrome, not color — stays in budget.
    static let logoBacking = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(white: 0.92, alpha: 1)
            : .clear
    })
}

// MARK: - Team color (the hero exception)
// The team-page hero paints in the team's own color (Andy's call,
// 2026-08-25 — the color budget's fourth exception). ESPN serves a bare
// six-digit hex; anything else degrades to nil and the hero stays mono.
extension Color {
    init?(espnHex: String?) {
        guard let hex = espnHex?.trimmingCharacters(in: .whitespaces),
              hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        self.init(red: Double((value >> 16) & 0xFF) / 255,
                  green: Double((value >> 8) & 0xFF) / 255,
                  blue: Double(value & 0xFF) / 255)
    }

    /// True when white text would fail on this team color (a handful of
    /// golds and silvers); the hero flips to black ink instead.
    static func espnHexIsLight(_ hex: String?) -> Bool {
        guard let hex = hex?.trimmingCharacters(in: .whitespaces),
              hex.count == 6, let value = UInt32(hex, radix: 16) else { return false }
        let r = Double((value >> 16) & 0xFF) / 255
        let g = Double((value >> 8) & 0xFF) / 255
        let b = Double(value & 0xFF) / 255
        return (0.2126 * r + 0.7152 * g + 0.0722 * b) > 0.6
    }
}

// Lets views write .foregroundStyle(.textSecondary) with dot syntax.
extension ShapeStyle where Self == Color {
    static var textPrimary: Color { .textPrimary }
    static var textSecondary: Color { .textSecondary }
    static var liveAccent: Color { .liveAccent }
    static var rankUp: Color { .rankUp }
    static var rankDown: Color { .rankDown }
}

// MARK: - Card surface
// The elevated-card treatment shared by Scores, Rankings, and Teams:
// content on bgPrimary, rounded, with a soft shadow, sitting on bgRecessed.
extension View {
    func cardSurface() -> some View {
        // Clipped so full-bleed child backgrounds (accordion headers) follow
        // the card's rounded corners instead of poking square corners past them.
        clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.bgPrimary)
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            )
    }
}

// MARK: - Spacing tokens

enum Spacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let xl: CGFloat = 24
}

// MARK: - Type tokens
// Weight and size create hierarchy, not color. Scores always use monospaced
// digits so they don't jitter as clocks tick.
//
// Sizes are design-exact at the default text size and follow the user's
// Dynamic Type setting via UIFontMetrics (UIKit stays contained to this
// file, same deal as the colors). Computed vars, not lets: a text-size
// change re-renders every view, which re-resolves the token at the new size.
extension Font {
    static var score: Font { scaled(17, .semibold, relativeTo: .body).monospacedDigit() }
    static var scoreLive: Font { scaled(17, .heavy, relativeTo: .body).monospacedDigit() }
    static var scoreMuted: Font { scaled(17, .regular, relativeTo: .body).monospacedDigit() }
    static var teamName: Font { scaled(15, .regular, relativeTo: .subheadline) }
    static var teamNameEmphasis: Font { scaled(15, .semibold, relativeTo: .subheadline) }
    static var meta: Font { scaled(12, .regular, relativeTo: .caption1) }
    static var metaEmphasis: Font { scaled(12, .semibold, relativeTo: .caption1) }
    static var sectionHeader: Font { scaled(13, .semibold, relativeTo: .footnote) }
    /// The widget's ★ Following masthead: heavy enough to anchor the whole
    /// surface, since the widget has no navigation chrome above it.
    static var sectionHeaderProminent: Font { scaled(16, .heavy, relativeTo: .callout) }
    /// The masthead scaled for the medium family, whose ~138pt content box
    /// can't fit the full-size header plus two cards without crushing padding.
    static var sectionHeaderProminentCompact: Font { scaled(14, .heavy, relativeTo: .footnote) }
    static var chip: Font { scaled(14, .medium, relativeTo: .callout) }
    /// Live-game counterpart to `chip`: same size, weight carries the emphasis.
    static var chipEmphasis: Font { scaled(14, .semibold, relativeTo: .callout) }
    /// Between meta and metaEmphasis: the widget's card rows want records and
    /// times a step stronger than regular against the bgHeader card fill.
    static var metaMedium: Font { scaled(12, .medium, relativeTo: .caption1) }
    /// The team-page hero's name line — the one place the app goes bigger
    /// than 17: the hero has no nav title above it, so the name carries the
    /// whole identity weight (same reasoning as the widget masthead).
    static var heroTitle: Font { scaled(24, .heavy, relativeTo: .title2) }
    /// The 2240-spec game-row scale (Andy's Figma, 2026-08-25): names and
    /// scores at 13 medium, metadata at 10. Semibold carries the live
    /// emphasis at this scale.
    static var rowName: Font { scaled(13, .medium, relativeTo: .subheadline) }
    static var rowNameEmphasis: Font { scaled(13, .semibold, relativeTo: .subheadline) }
    static var rowMeta: Font { scaled(10, .regular, relativeTo: .caption2) }
    static var rowMetaMedium: Font { scaled(10, .medium, relativeTo: .caption2) }
    /// The hero tab labels — bold 14 with −2% tracking, per the Figma
    /// header component ("follow specs exactly", 2026-08-25).
    static var tab: Font { scaled(14, .bold, relativeTo: .callout) }

    private static func scaled(_ size: CGFloat, _ weight: UIFont.Weight,
                               relativeTo style: UIFont.TextStyle) -> Font {
        Font(UIFontMetrics(forTextStyle: style).scaledFont(for: .systemFont(ofSize: size, weight: weight)))
    }
}
