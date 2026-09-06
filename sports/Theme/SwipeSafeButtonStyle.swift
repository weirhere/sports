import SwiftUI

/// A `.plain`-looking button for rows that live inside a horizontally
/// swipeable pane.
///
/// `.buttonStyle(.plain)` fires on touch-up whenever the touch is still
/// inside the button's frame. A full-width row is *wider* than any swipe,
/// so a horizontal drag never leaves it: the Scores day swipe committed
/// and the row's `NavigationLink` pushed a detail page on the way out
/// (found 2026-09-06 cutting 2.1; live in 2.0). Vertical drags were never
/// affected — the enclosing ScrollView claims those and cancels the press
/// for us.
///
/// So this style triggers on a `TapGesture`, whose movement tolerance is
/// the system's own, instead of on a bare touch-up. The button keeps its
/// identity — VoiceOver still sees a button and still activates it through
/// `trigger()` — and nothing here paints, so it renders exactly as
/// `.plain` does.
///
/// It is deliberately local to the row rather than a `.disabled()` flag
/// driven from the pane's drag state: a flag would have to reach every row
/// through the environment and flip mid-drag, invalidating the whole
/// scores tree on the very gesture the E5 pass made cheap.
struct SwipeSafeButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            // Rows are laid out with spacers and gaps; without this the tap
            // only lands on the ink, which `.plain` didn't require.
            .contentShape(Rectangle())
            .onTapGesture { configuration.trigger() }
    }
}

extension PrimitiveButtonStyle where Self == SwipeSafeButtonStyle {
    /// `.plain`, minus the touch-up that a horizontal swipe could ride out.
    static var swipeSafe: SwipeSafeButtonStyle { SwipeSafeButtonStyle() }
}
