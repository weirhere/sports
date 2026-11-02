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
        /// Where the row goes, when its value is a team the app has a page
        /// for: a pro's college (2026-11-02). Nil leaves the row as it was.
        var team: Team?
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

    @ViewBuilder
    private func rowView(_ row: Row) -> some View {
        if let team = row.team {
            NavigationLink(value: team) { rowContent(row, isLink: true) }
                .buttonStyle(.plain)
        } else {
            rowContent(row, isLink: false)
        }
    }

    private func rowContent(_ row: Row, isLink: Bool) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(row.label)
                .font(.rowName)
                .foregroundStyle(.textSecondary)
            Spacer(minLength: Spacing.sm)
            Text(row.value)
                .font(.rowNameEmphasis)
                .monospacedDigit()
                .foregroundStyle(.textPrimary)
            if isLink {
                // `RosterCoachRow`'s chevron, so a row that goes somewhere
                // says so the way every other one in the app does.
                Image(systemName: "chevron.right")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.textSecondary)
                    .accessibilityHidden(true)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.md)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(row.spokenLabel ?? row.label) \(row.value)")
    }
}
