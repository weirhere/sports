import SwiftUI

/// Placeholder section stack shown while the first load is in flight.
///
/// It mirrors the slate it stands in for — accordion-shaped cards on the
/// recessed page — rather than sitting bare on the page itself. That is not
/// a styling preference. The bars are `bgElevated`, which in **light mode
/// is the same 0.93 white as the `bgRecessed` page** they used to be drawn
/// on, so every bar, disc and section header was invisible and the whole
/// screen read as three featureless gray slabs with two hairlines across
/// them (Andy's field report, 2026-09-17: "why are no games showing up on
/// any day"). A loading state that looks like a broken screen is worse than
/// no loading state at all.
///
/// The `#Preview` is why it survived: it alone set a `bgCard` background,
/// where 0.93 bars on 1.00 white look exactly as intended. It now previews
/// on `bgRecessed`, the surface the screen actually uses.
struct SkeletonRows: View {
    var body: some View {
        // Spacing.sm and the same outer padding as the real slate's
        // LazyVStack, so the cards don't jump when the games land.
        LazyVStack(spacing: Spacing.sm) {
            ForEach(0..<3, id: \.self) { _ in
                VStack(spacing: 0) {
                    HStack {
                        bar(width: 90, height: 13)
                        Spacer()
                    }
                    .padding(.horizontal, Spacing.lg)
                    .padding(.vertical, Spacing.md)
                    .frame(maxWidth: .infinity)
                    .background(Color.bgHeader)
                    ForEach(0..<3, id: \.self) { _ in
                        HStack(spacing: Spacing.md) {
                            VStack(alignment: .leading, spacing: 6) {
                                teamBar
                                teamBar
                            }
                            Spacer()
                            bar(width: 56, height: 12)
                        }
                        .padding(.horizontal, Spacing.lg)
                        .padding(.vertical, 8)
                    }
                }
                .cardSurface()
            }
        }
        .padding(Spacing.sm)
        .opacity(pulsing ? 0.45 : 1)
        // One element, one label: VoiceOver should say the screen is
        // loading, not read out nine anonymous shapes.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading games")
        .onAppear {
            withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        }
    }

    @State private var pulsing = false

    private var teamBar: some View {
        HStack(spacing: 6) {
            Circle().fill(Color.bgElevated).frame(width: 20, height: 20)
            bar(width: 120, height: 12)
        }
    }

    private func bar(width: CGFloat, height: CGFloat) -> some View {
        Capsule().fill(Color.bgElevated).frame(width: width, height: height)
    }
}

// bgRecessed, not bgCard: the page the skeleton is drawn on. Previewing it
// on a card is what hid the light-mode collision for a month.
#Preview {
    SkeletonRows().background(Color.bgRecessed)
}
