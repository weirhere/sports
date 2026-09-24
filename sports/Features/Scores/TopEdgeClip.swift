import SwiftUI

/// Clips at the top edge only, leaving the sides and bottom open.
///
/// The slate's transitions must not paint over the masthead and day strip
/// above it, but its scroll view must still reach under the tab bar below
/// it — which `.clipped()`, cutting all four edges at the safe area, forbids.
struct TopEdgeClip: Shape {
    func path(in rect: CGRect) -> Path {
        // Far enough past the frame to cover any safe area or overscroll.
        let overhang: CGFloat = 10_000
        return Path(CGRect(x: rect.minX - overhang, y: rect.minY,
                           width: rect.width + overhang * 2,
                           height: rect.height + overhang))
    }
}
