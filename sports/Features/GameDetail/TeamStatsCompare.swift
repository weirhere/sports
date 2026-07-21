import SwiftUI

/// Away vs home stats as opposing monochrome bars growing out from the
/// center — length carries the comparison, not color.
struct TeamStatsCompare: View {
    let summary: GameSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("TEAM STATS")
                    .font(.sectionHeader)
                    .foregroundStyle(.textPrimary)
                Spacer()
                Text("\(summary.away?.team.abbreviation ?? "AWAY") · \(summary.home?.team.abbreviation ?? "HOME")")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.md)
            ForEach(summary.teamStats) { stat in
                statRow(stat)
            }
        }
        .padding(.bottom, Spacing.sm)
    }

    private func statRow(_ stat: StatComparison) -> some View {
        VStack(spacing: Spacing.xs) {
            HStack {
                Text(stat.away)
                    .font(.meta.monospacedDigit())
                    .foregroundStyle(.textPrimary)
                    .frame(width: 64, alignment: .leading)
                Spacer()
                Text(stat.label)
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                Spacer()
                Text(stat.home)
                    .font(.meta.monospacedDigit())
                    .foregroundStyle(.textPrimary)
                    .frame(width: 64, alignment: .trailing)
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

    private func shares(_ stat: StatComparison) -> (away: CGFloat, home: CGFloat)? {
        guard let away = stat.awayValue, let home = stat.homeValue, away + home > 0 else {
            return nil
        }
        return (CGFloat(away / (away + home)), CGFloat(home / (away + home)))
    }
}
