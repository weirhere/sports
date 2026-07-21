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
    /// One step off bgPrimary — the surface accordion cards sit on.
    static let bgRecessed = Color(lightWhite: 0.96, darkWhite: 0.08)
    static let bgElevated = Color(lightWhite: 0.96, darkWhite: 0.10)
    static let textPrimary = Color(lightWhite: 0.00, darkWhite: 1.00)
    static let textSecondary = Color(lightWhite: 0.44, darkWhite: 0.62)
    static let divider = Color(lightWhite: 0.88, darkWhite: 0.20)

    /// The app's only accent color: the live indicator and live-score emphasis.
    static let liveAccent = Color(uiColor: UIColor { traits in
        traits.userInterfaceStyle == .dark
            ? UIColor(red: 1.00, green: 0.27, blue: 0.23, alpha: 1)
            : UIColor(red: 0.84, green: 0.00, blue: 0.08, alpha: 1)
    })
}

// Lets views write .foregroundStyle(.textSecondary) with dot syntax.
extension ShapeStyle where Self == Color {
    static var textPrimary: Color { .textPrimary }
    static var textSecondary: Color { .textSecondary }
    static var liveAccent: Color { .liveAccent }
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
extension Font {
    static let score = Font.system(size: 17, weight: .semibold).monospacedDigit()
    static let scoreLive = Font.system(size: 17, weight: .heavy).monospacedDigit()
    static let scoreMuted = Font.system(size: 17, weight: .regular).monospacedDigit()
    static let teamName = Font.system(size: 15)
    static let teamNameEmphasis = Font.system(size: 15, weight: .semibold)
    static let meta = Font.system(size: 12)
    static let metaEmphasis = Font.system(size: 12, weight: .semibold)
    static let sectionHeader = Font.system(size: 13, weight: .semibold)
    static let chip = Font.system(size: 14, weight: .medium)
}
