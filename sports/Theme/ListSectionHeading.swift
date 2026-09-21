import SwiftUI

/// Floating sentence-case heading between cards on a recessed list —
/// the FotMob-style label the P1 review settled on ("Following",
/// "All conferences"), replacing the caps section labels.
struct ListSectionHeading: View {
    let title: String

    var body: some View {
        Text(title)
            .font(.teamNameEmphasis)
            .foregroundStyle(.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.md)
            // `lg`, not `sm` (Andy, 2026-09-21). At 8pt the heading sat as
            // close to the card above it as that card's own rows sat to
            // each other, so a section boundary read as one more row. The
            // gap is the only thing separating two lists here — there is
            // no rule, no ground change and no caps — so it has to be
            // bigger than the gap between cards, not equal to it.
            .padding(.top, Spacing.lg)
            .padding(.bottom, Spacing.xs)
            .accessibilityAddTraits(.isHeader)
    }
}
