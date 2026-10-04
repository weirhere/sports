import SwiftUI

/// Paints the entity pages' hero color through the top safe area — the
/// status-bar strip and the transparent nav bar — from *outside* the
/// ScrollView, whose clipping swallowed the old in-content extension (a
/// `-1000`pt inflated background never reached the strip; 2026-08-31).
///
/// The band's height tracks the scroll: exactly the top inset at rest,
/// growing through the top bounce, shrinking to zero as the hero scrolls
/// under (its bottom edge is the hero's top edge, so it can't bleed behind
/// content — the objection that reverted the fixed-band first cut). By the
/// time it's gone the solid toolbar handoff has the strip covered.
///
/// `ownsBar` (painted entity headers, 2026-10-03): while the band covers the
/// bar, the bar's own background stays hidden, so the color the push slides
/// in is the page's and not the bar's. A solid bar is drawn by the
/// navigation stack and cross-fades in place during a push, so the strip
/// behind back/bell/follow/share turned team-colored at once while the name,
/// logo and tabs were still sliding in. The bar goes solid only once the
/// band has shrunk away, by when the hero beneath it is the same color.
struct HeroTopBand: ViewModifier {
    let color: Color
    var ownsBar = false

    @State private var bandHeight: CGFloat = 0
    @State private var heroUnderBar = false

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                let scrolled = geometry.contentOffset.y + geometry.contentInsets.top
                return max(0, geometry.contentInsets.top - scrolled)
            } action: { _, height in
                bandHeight = height
                if heroUnderBar != (height == 0) { heroUnderBar = height == 0 }
            }
            .background(alignment: .top) {
                color
                    .frame(height: bandHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
            }
            .modifier(BarVisibility(applies: ownsBar, visible: heroUnderBar))
    }
}

private struct BarVisibility: ViewModifier {
    let applies: Bool
    let visible: Bool

    func body(content: Content) -> some View {
        if applies {
            content.toolbarBackground(visible ? .visible : .hidden, for: .navigationBar)
        } else {
            content
        }
    }
}

extension View {
    /// The hero pages' top-strip paint; pass the hero's own background.
    func heroTopBand(_ color: Color, ownsBar: Bool = false) -> some View {
        modifier(HeroTopBand(color: color, ownsBar: ownsBar))
    }
}
