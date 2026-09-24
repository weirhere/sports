import SwiftUI

/// A card of label/value rows — the player page's Profile language
/// (`TeamRecordCard`'s pairs), lifted out so a player's season and a team's
/// season read in the same words as a player's height (2026-09-24).
struct LabeledValueCard: View {
    struct Row: Identifiable, Hashable {
        let label: String
        let value: String
        /// What VoiceOver reads for the label — ESPN's "Passing Yards"
        /// where the visible label is its "YDS". Defaults to `label`.
        var spokenLabel: String?
        var id: String { label }
    }

    let title: String
    var subtitle: String?
    let rows: [Row]

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: title, subtitle: subtitle)
            ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
                rowView(row)
                if index < rows.count - 1 {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg)
                }
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    private func rowView(_ row: Row) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(row.label)
                .font(.rowName)
                .foregroundStyle(.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(row.value)
                .font(.rowNameEmphasis)
                .monospacedDigit()
                .foregroundStyle(.textPrimary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.spokenLabel ?? row.label) \(row.value)")
    }
}
