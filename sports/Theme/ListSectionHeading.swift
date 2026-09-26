import SwiftUI

/// Floating sentence-case heading between cards on a recessed list —
/// the FotMob-style label the P1 review settled on ("Following",
/// "All conferences"), replacing the caps section labels.
///
/// `trailing` is an optional right-aligned accessory on the heading's own
/// line — the Leagues tab's Edit/Done link (Andy, 2026-09-25).
struct ListSectionHeading<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Spacing.sm) {
            Text(title)
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)
            trailing
        }
        .padding(.horizontal, Spacing.md)
        // `lg`, not `sm` (Andy, 2026-09-21). At 8pt the heading sat as
        // close to the card above it as that card's own rows sat to
        // each other, so a section boundary read as one more row. The
        // gap is the only thing separating two lists here — there is
        // no rule, no ground change and no caps — so it has to be
        // bigger than the gap between cards, not equal to it.
        .padding(.top, Spacing.lg)
        .padding(.bottom, Spacing.xs)
    }
}

extension ListSectionHeading where Trailing == EmptyView {
    init(title: String) {
        self.init(title: title) { EmptyView() }
    }
}
