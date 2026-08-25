import SwiftUI

/// Away vs home stats as opposing monochrome bars growing out from the
/// center — length carries the comparison, not color.
struct TeamStatsCompare: View {
    let summary: GameSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var valueWidth: CGFloat = 64

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

    var body: some View {
        // The card's CardHeader names the section and carries the column
        // legend now; this view is just the bars.
        VStack(alignment: .leading, spacing: 0) {
            ForEach(summary.teamStats) { stat in
                statRow(stat)
            }
        }
        .padding(.bottom, Spacing.sm)
    }

    /// Three across the row until accessibility sizes, where the label takes
    /// its own line above the two values — otherwise "27:28" splits into
    /// "27:2" over "8".
    private func statRow(_ stat: StatComparison) -> some View {
        VStack(spacing: Spacing.xs) {
            if isStacked {
                labelText(stat)
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack {
                    valueText(stat.away, alignment: .leading)
                    Spacer(minLength: Spacing.md)
                    valueText(stat.home, alignment: .trailing)
                }
            } else {
                HStack {
                    valueText(stat.away, alignment: .leading)
                        .frame(minWidth: valueWidth, alignment: .leading)
                    Spacer()
                    labelText(stat)
                    Spacer()
                    valueText(stat.home, alignment: .trailing)
                        .frame(minWidth: valueWidth, alignment: .trailing)
                }
            }
            if let shares = shares(stat) {
                GeometryReader { proxy in
                    let half = proxy.size.width / 2 - 1
                    HStack(spacing: 2) {
                        HStack {
                            Spacer(minLength: 0)
                            Capsule()
                                .fill(Color.textPrimary)
                                .frame(width: max(2, half * shares.away), height: 3)
                        }
                        HStack {
                            Capsule()
                                .fill(Color.textPrimary)
                                .frame(width: max(2, half * shares.home), height: 3)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .frame(height: 3)
            }
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 5)
    }

    private func labelText(_ stat: StatComparison) -> some View {
        Text(stat.label)
            .font(.meta)
            .foregroundStyle(.textSecondary)
    }

    private func valueText(_ value: String, alignment: TextAlignment) -> some View {
        Text(value)
            .font(.meta.monospacedDigit())
            .foregroundStyle(.textPrimary)
            .multilineTextAlignment(alignment)
            .lineLimit(1)
            // Values are short and load-bearing — they hold their natural
            // width and the label gives ground instead.
            .fixedSize(horizontal: true, vertical: false)
    }

    private func shares(_ stat: StatComparison) -> (away: CGFloat, home: CGFloat)? {
        guard let away = stat.awayValue, let home = stat.homeValue, away + home > 0 else {
            return nil
        }
        return (CGFloat(away / (away + home)), CGFloat(home / (away + home)))
    }
}
