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
            .padding(.top, Spacing.sm)
            .accessibilityAddTraits(.isHeader)
    }
}
