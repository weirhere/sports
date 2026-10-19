import SwiftUI

/// The page's ground, thinning to nothing over the edge of a scroll that
/// runs under pinned chrome (Andy, 2026-10-19). The Leagues tab's masthead
/// and search field, and the Search tab's field at the foot, sit on the
/// same `bgRecessed` as the page rather than on a lighter bar, and this is
/// what keeps the join legible: content doesn't stop at a line, it fades
/// out under the chrome. Laid over the scroll's edge, never over the
/// chrome, and it takes no touches.
struct ScrollEdgeFade: View {
    enum Edge { case top, bottom }

    let edge: Edge
    var height: CGFloat = 20

    var body: some View {
        LinearGradient(
            colors: [Color.bgRecessed, Color.bgRecessed.opacity(0)],
            startPoint: edge == .top ? .top : .bottom,
            endPoint: edge == .top ? .bottom : .top
        )
        .frame(height: height)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
