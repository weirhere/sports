import SwiftUI

/// One section's part in the Hide all/Show all motion (Andy, 2026-09-26).
/// The section has already closed to its header on the accordion's own
/// animation (`ScoresScreen.stackFolded`); this gathers it into a deck
/// under the first hidden section, then fades the deck up behind the
/// control. Showing runs it all back. Every effect is visual only — scale,
/// offset, opacity — so nothing outside the hidden sections shifts.
///
/// Gathering and fading are separate flags rather than one phase so the
/// screen can overlap them: each leg starts while the last is still
/// settling, and the whole reads as one motion instead of three stops.
struct StackCollapse: ViewModifier {
    let gathered: Bool
    let faded: Bool
    /// This section's place among the ones being hidden, in slate order.
    let index: Int
    /// This section's laid-out frame in the slate, and the first hidden
    /// section's top edge — where the deck gathers. Nil until measured; a
    /// section the lazy stack never built has nowhere to fly from, so it
    /// just fades.
    let frame: CGRect?
    let deckTop: CGFloat?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// How much of each card behind the first one shows below it.
    private static let peek: CGFloat = 6
    /// Cards behind the first that make up the deck. The rest don't fly:
    /// they fade where they are, under the deck passing over them. A card
    /// that far down can be built by the lazy stack mid-motion, and a
    /// freshly built card takes its end state with no animation — flying,
    /// it would appear already in the deck, even over the control.
    static let depth = 2
    /// How far the deck rises as it fades — short of the 12pt gap to the
    /// capsule, since the deck draws above the control (so the caption can
    /// come out from under it) and must never cover the button.
    private static let rise: CGFloat = 10

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale, anchor: .top)
            .offset(y: offset)
            .opacity(opacity)
            // Above the control, so the Show all caption is uncovered by the
            // deck lifting off it; the first card on top, so the deck reads
            // front to back.
            .zIndex(10 - Double(index))
    }

    private var isDeckCard: Bool { index <= Self.depth && frame != nil && deckTop != nil }

    private var scale: CGFloat {
        gathered && isDeckCard ? 1 - 0.04 * CGFloat(index) : 1
    }

    private var offset: CGFloat {
        // Under Reduce Motion the deck never gathers and doesn't rise:
        // the sections only fade.
        let lift = faded && !reduceMotion ? -Self.rise : 0
        guard gathered, isDeckCard, let frame, let deckTop else { return lift }
        return deckTop + CGFloat(index) * Self.peek - frame.minY + lift
    }

    private var opacity: Double {
        if faded { return 0 }
        return gathered && !isDeckCard ? 0 : 1
    }
}

extension View {
    func stackCollapse(gathered: Bool, faded: Bool, index: Int,
                       frame: CGRect?, deckTop: CGFloat?) -> some View {
        modifier(StackCollapse(gathered: gathered, faded: faded, index: index,
                               frame: frame, deckTop: deckTop))
    }
}
