import SwiftUI

/// One tier of the StatSide rating's full table — "Top 25" or "Unranked" —
/// as a card: the header, the column captions, then the rows.
struct StatSideRatingTable: View {
    let title: String
    let subtitle: String
    let rows: [StatSideRating.Row]

    // `StatSideRatingRow`'s column widths, so the captions sit over them.
    @ScaledMetric(relativeTo: .subheadline) private var recordWidth: CGFloat = 36
    @ScaledMetric(relativeTo: .subheadline) private var numberWidth: CGFloat = 34

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: title, subtitle: subtitle)
            captions
            LazyVStack(spacing: 0) {
                ForEach(rows) { row in
                    NavigationLink(value: row.team) {
                        StatSideRatingRow(row: row)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    /// The column captions over the four numbers, aligned to the row's
    /// trailing columns.
    private var captions: some View {
        HStack(spacing: Spacing.sm) {
            Spacer()
            caption("W-L", width: recordWidth)
            caption("DIFF", width: numberWidth)
            caption("PF", width: numberWidth)
            caption("PA", width: numberWidth)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.top, Spacing.sm)
        .accessibilityHidden(true)
    }

    private func caption(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.rowMetaMedium)
            .foregroundStyle(.textSecondary)
            .frame(minWidth: width, alignment: .trailing)
    }
}
