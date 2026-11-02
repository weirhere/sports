import CoreGraphics

/// The game page's tab swipe and the box score's sideways tables share one
/// axis, and this is how the drag learns which of them it was for.
///
/// Deliberately not `@Observable`: the tables write `tableMoved` on every
/// frame they scroll, and nothing draws from it — the swipe only reads it
/// once, as the finger lifts.
final class TabSwipeLedger {
    /// Where the drag under the finger began, nil between drags. A drag is
    /// told apart by its start rather than by a begin/end flag, so one
    /// SwiftUI cancels without an `onEnded` can't leave the next one
    /// carrying its verdict.
    private var dragStart: CGPoint?
    /// Whether a table scrolled at any point during this drag.
    private(set) var tableMoved = false

    func dragChanged(startingAt start: CGPoint) {
        guard start != dragStart else { return }
        dragStart = start
        tableMoved = false
    }

    /// A table moved. Ignored between drags, so a table still coasting
    /// after the lift can't mark the next drag.
    func tableScrolled() {
        if dragStart != nil { tableMoved = true }
    }

    /// Whether the drag that just ended scrolled a table, clearing it.
    func dragEnded() -> Bool {
        defer {
            dragStart = nil
            tableMoved = false
        }
        return tableMoved
    }
}
