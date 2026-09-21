import Foundation
import SwiftUI
import Testing
import UIKit
@testable import StatSide

// WCAG AA, held to the tokens rather than to a screenshot.
//
// The bug this exists for (E5, filed 2026-09-20, fixed 2026-09-21):
// `HeroTabBar` drew its unselected tabs in `textPrimary.opacity(0.5)`,
// which composites to white 0.55 on a light card — 3.35:1 at bold 14,
// under AA's 4.5:1. Dark mode cleared it comfortably, which is how it
// survived a year of looking at the thing: half the audit passes.
//
// An opacity over an unknown backdrop is what can't be checked. A token
// on a named surface can, so these are pairs, not colours.

/// WCAG relative luminance of a token, resolved for one appearance.
private func luminance(_ color: Color, _ style: UIUserInterfaceStyle) -> Double {
    let resolved = UIColor(color)
        .resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
    // The ramp is built from `UIColor(white:alpha:)`, so these colours
    // live in the grayscale space and `getRed` is documented to refuse
    // it. `getWhite` is the one that always answers there; the RGB path
    // is for anything that isn't on the mono ramp.
    if !resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) {
        var white: CGFloat = 0
        _ = resolved.getWhite(&white, alpha: &alpha)
        (red, green, blue) = (white, white, white)
    }
    func channel(_ raw: CGFloat) -> Double {
        let value = Double(raw)
        return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }
    return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
}

/// The WCAG ratio for ink on a surface, always ≥ 1.
private func contrast(_ ink: Color, on surface: Color,
                      _ style: UIUserInterfaceStyle) -> Double {
    let (a, b) = (luminance(ink, style), luminance(surface, style))
    let (lighter, darker) = (max(a, b), min(a, b))
    return (lighter + 0.05) / (darker + 0.05)
}

private let appearances: [(name: String, style: UIUserInterfaceStyle)] = [
    ("light", .light), ("dark", .dark),
]

/// Every surface a text token legitimately sits on, worst case included.
private let ramp: [(name: String, color: Color)] = [
    ("bgCard", .bgCard), ("bgPrimary", .bgPrimary), ("bgRecessed", .bgRecessed),
    ("bgElevated", .bgElevated), ("bgHeader", .bgHeader),
]

/// AA for text below 18.66pt bold — which is every label in this app.
private let aa = 4.5

@MainActor
@Suite struct ContrastTests {
    @Test func theHeroTabRowClearsAAInBothAppearances() {
        // The tab row is drawn on `bgCard` at all four call sites
        // (TeamPage, ConferencePage, PollScreen, game detail), but the
        // whole ramp is asserted so moving it can't quietly reintroduce
        // this.
        for (appearance, style) in appearances {
            for (surface, color) in ramp {
                let inactive = contrast(.textSecondary, on: color, style)
                #expect(inactive >= aa,
                        "inactive tab on \(surface) in \(appearance): \(inactive)")
                let active = contrast(.textPrimary, on: color, style)
                #expect(active >= aa,
                        "active tab on \(surface) in \(appearance): \(active)")
            }
        }
    }

    @Test func theTwoTabStatesStayTellableApart() {
        // The fix raises the inactive ink, so the guard it needs is the
        // opposite one: selected and unselected must not converge into a
        // row where nothing says where you are. The underline stays out
        // (2026-08-31), so this delta is the only signal there is.
        for (appearance, style) in appearances {
            let separation = contrast(.textPrimary, on: .textSecondary, style)
            #expect(separation >= 2.0,
                    "active vs inactive ink in \(appearance): \(separation)")
        }
    }

    @Test func theSecondaryInkClearsAAEverywhereItSits() {
        // `textSecondary`'s own doc comment reasons its way to 0.42 with
        // a worst case of 4.55:1. That number was arithmetic in a comment
        // and is now a test, since the tab row is the second thing to
        // depend on it being true.
        for (appearance, style) in appearances {
            let worst = ramp
                .map { contrast(.textSecondary, on: $0.color, style) }
                .min() ?? 0
            #expect(worst >= aa, "worst surface in \(appearance): \(worst)")
        }
    }

    @Test func aHalfStrengthPrimaryIsWhatFailed() {
        // The regression itself, kept as a measurement rather than a
        // memory: 50% ink over a light card is the composite that put the
        // row under AA. Nothing draws this any more — the point is that
        // the next person reaching for `.opacity(0.5)` on a label can see
        // the number it produces.
        let composited = Color(white: 0.55)
        let ratio = contrast(composited, on: .bgCard, .light)
        #expect(ratio < aa, "the old inactive ink should measure under AA: \(ratio)")
        #expect(ratio > 3.0, "and it should be the ~3.35:1 the audit found: \(ratio)")
    }
}
