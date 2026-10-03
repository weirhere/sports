import SwiftUI

/// Where a page's scroll should land, and when to land it again: a change
/// to either field re-fires. `target` is a scroll id to put at the top with
/// the header fully expanded; nil is the top of the page.
struct ScrollLanding: Equatable {
    /// What the landing belongs to — the tab, so flipping tabs lands again
    /// even when two tabs share a nil target.
    var key: String
    var target: String?
}

/// An entity page's scroll: the hero, a strip that sticks once the hero is
/// gone (the tab row and the chips), and the pane under them.
///
/// The header is drawn over the content rather than as its first rows
/// (Andy, 2026-09-27). A Games tab opens scrolled to this week, and the
/// header has to be fully expanded when it does — which a hero at the top
/// of the content can't be, with every earlier week between it and the
/// card in view. So the header sits wherever it would if it were content
/// directly above the page's landing point:
///
/// - **Scrolling down** collapses the hero 1:1 with the finger, exactly as
///   content would scroll away, and then the strip pins.
/// - **Scrolling up** past the landing point leaves it fully expanded, and
///   what's above — the earlier weeks — slides in beneath it. Scrolling
///   down again from there collapses it straight away.
/// - **Landing** (a tab flip, a slate change) re-expands it.
///
/// The header stays inside the scroll view, offset to where it should
/// draw, so a drag that starts on it still scrolls the page.
struct CollapsingHeaderScrollView<Hero: View, Strip: View, Content: View>: View {
    let landing: ScrollLanding
    /// How far the hero has collapsed, 0 to its height — what the pages
    /// hand the nav bar's inline title off on.
    @Binding var collapse: CGFloat
    @ViewBuilder var hero: Hero
    @ViewBuilder var strip: Strip
    /// Handed the header's full height, which is how far below the top a
    /// landing target has to sit to clear it (`ConferenceGamesList.scrollInset`).
    @ViewBuilder var content: (_ headerHeight: CGFloat) -> Content

    @State private var heroHeight: CGFloat = 0
    @State private var stripHeight: CGFloat = 0
    @State private var offset: CGFloat = 0
    /// The offset at which the hero is fully expanded — the landing point,
    /// dragged along whenever the reader scrolls above it.
    @State private var base: CGFloat = 0
    /// Set while a landing's scroll is settling, so the jump itself can't
    /// read as a scroll and collapse the header for a frame.
    @State private var isLanding = false

    private static var topId: String { "collapsing-header-top" }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                ZStack(alignment: .top) {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: heroHeight + stripHeight)
                            .id(Self.topId)
                        content(heroHeight + stripHeight)
                    }
                    header
                        // Where content directly above the landing point
                        // would be — never below the page's own top, so a
                        // top bounce carries it down with everything else.
                        .offset(y: max(0, offset - collapse))
                }
            }
            .onScrollGeometryChange(for: CGFloat.self) { geometry in
                geometry.contentOffset.y + geometry.contentInsets.top
            } action: { _, scrolled in
                track(scrolled)
            }
            // The header is this page's own opaque top edge, so iOS 26's
            // scroll-edge treatment under the bar only ever tinted it: a
            // page that lands scrolled (a Games tab on this week) showed a
            // band the bar doesn't have at the top of the page.
            .modifier(TopScrollEdgeEffectHidden())
            .task(id: landing) {
                isLanding = true
                defer { isLanding = false }
                if let target = landing.target {
                    // Past the tab's push transition: until the outgoing
                    // pane leaves, the content is still its height, and a
                    // scroll into the incoming one clamps short.
                    try? await Task.sleep(for: .milliseconds(400))
                    proxy.scrollTo(target, anchor: .top)
                } else {
                    // Back to the top at once — no animation, no wait
                    // (Andy, 2026-09-27).
                    proxy.scrollTo(Self.topId, anchor: .top)
                }
                // A frame or two for the jump's geometry to arrive while
                // `isLanding` still rebases on it.
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
    }

    private var header: some View {
        VStack(spacing: 0) {
            hero
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    heroHeight = $0
                }
            strip
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    stripHeight = $0
                }
        }
    }

    private func track(_ scrolled: CGFloat) {
        offset = scrolled
        if isLanding || scrolled < base {
            // Never above the page's top: a flick that overshoots into the
            // top bounce would otherwise leave the landing point at the
            // bounce's depth, and the settle back to 0 would read as
            // collapse, handing the bar its title with the hero in full
            // view (Andy, 2026-10-02, on the game page's compact score).
            base = max(scrolled, 0)
        }
        let next = min(max(scrolled - base, 0), heroHeight)
        if next != collapse { collapse = next }
    }
}

/// `scrollEdgeEffectHidden` is iOS 26 only; before it there's no effect to hide.
private struct TopScrollEdgeEffectHidden: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.scrollEdgeEffectHidden(true, for: .top)
        } else {
            content
        }
    }
}

