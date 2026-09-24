import SwiftUI

/// A card holding one table of ESPN's numbers: a leading label column, then
/// ESPN's own column headers, scrolling sideways when they don't fit.
///
/// `BoxScoreList`'s table, generalised for rows that are seasons rather
/// than players (2026-09-24) — the player page's Career tab. Columns come
/// from the payload and are never named here, for the box score's reason:
/// ESPN's column sets vary by league, position and even game state.
struct StatTableCard: View {
    struct Row: Identifiable, Hashable {
        let id: String
        /// "2025-26".
        let title: String
        /// "LAL" — the club, beside the season in quieter ink.
        var subtitle: String?
        let values: [String]
    }

    let title: String
    let columns: [String]
    /// Spoken column names, positionally paired with `columns`; falls back
    /// to the visible header.
    var spokenColumns: [String] = []
    let rows: [Row]
    /// A closing line in heavier ink — ESPN's career totals.
    var footer: Row?

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var statColumnWidth: CGFloat = 40

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: title)
            if dynamicTypeSize.isAccessibilitySize {
                stacked
            } else {
                table
            }
        }
        .cardSurface()
    }

    private var table: some View {
        ScrollView(.horizontal) {
            Grid(alignment: .leading, horizontalSpacing: Spacing.sm, verticalSpacing: Spacing.xs) {
                GridRow {
                    Text("")
                    ForEach(Array(columns.enumerated()), id: \.offset) { _, column in
                        Text(column)
                            .font(.rowMeta)
                            .foregroundStyle(.textSecondary)
                            .frame(minWidth: statColumnWidth, alignment: .trailing)
                            .accessibilityHidden(true)
                    }
                }
                Divider().overlay(Color.divider).gridCellColumns(columns.count + 1)
                ForEach(rows) { row in
                    GridRow {
                        titleCell(row, emphasized: false)
                        cells(row.values, emphasized: false)
                    }
                }
                if let footer {
                    Divider().overlay(Color.divider).gridCellColumns(columns.count + 1)
                    GridRow {
                        titleCell(footer, emphasized: true)
                        cells(footer.values, emphasized: true)
                    }
                }
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.sm)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }

    private func titleCell(_ row: Row, emphasized: Bool) -> some View {
        HStack(spacing: Spacing.xs) {
            Text(row.title)
                .font(emphasized ? .rowNameEmphasis : .rowName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            if let subtitle = row.subtitle {
                Text(subtitle)
                    .font(.rowMeta)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
        }
        .fixedSize()
    }

    /// Each cell speaks its own column, so a VoiceOver swipe along a season
    /// says "passing yards, 4,183" rather than a bare number.
    private func cells(_ values: [String], emphasized: Bool) -> some View {
        ForEach(Array(values.enumerated()), id: \.offset) { index, value in
            Text(value)
                .font((emphasized ? Font.metaEmphasis : .meta).monospacedDigit())
                .foregroundStyle(emphasized ? Color.textPrimary : Color.textSecondary)
                .lineLimit(1)
                .frame(minWidth: statColumnWidth, alignment: .trailing)
                .accessibilityLabel("\(spoken(index)), \(value)")
        }
    }

    private func spoken(_ index: Int) -> String {
        if spokenColumns.indices.contains(index) { return spokenColumns[index] }
        return columns.indices.contains(index) ? columns[index] : ""
    }

    /// Accessibility sizes can't hold a table: each row becomes its title
    /// with the numbers spelled out beneath, as `BoxScoreList` does.
    private var stacked: some View {
        VStack(alignment: .leading, spacing: Spacing.md) {
            ForEach(rows + (footer.map { [$0] } ?? [])) { row in
                VStack(alignment: .leading, spacing: 2) {
                    titleCell(row, emphasized: row.id == footer?.id)
                    ForEach(Array(zip(columns, row.values).enumerated()), id: \.offset) { _, pair in
                        Text("\(pair.0) \(pair.1)")
                            .font(.meta.monospacedDigit())
                            .foregroundStyle(.textSecondary)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
    }
}
