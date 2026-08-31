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
struct HeroTopBand: ViewModifier {
    let color: Color

    @State private var bandHeight: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                let scrolled = geometry.contentOffset.y + geometry.contentInsets.top
                return max(0, geometry.contentInsets.top - scrolled)
            } action: { _, height in
                bandHeight = height
            }
            .background(alignment: .top) {
                color
                    .frame(height: bandHeight)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .ignoresSafeArea(edges: .top)
            }
    }
}

extension View {
    /// The hero pages' top-strip paint; pass the hero's own background.
    func heroTopBand(_ color: Color) -> some View {
        modifier(HeroTopBand(color: color))
    }
}
