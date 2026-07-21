import SwiftUI

/// Passing / rushing / receiving leaders, one line per side.
struct LeadersList: View {
    let summary: GameSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("LEADERS")
                .font(.sectionHeader)
                .foregroundStyle(.textPrimary)
                .padding(.horizontal, Spacing.lg)
                .padding(.vertical, Spacing.md)
            ForEach(summary.leaders) { category in
                Text(category.label.uppercased())
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, Spacing.lg)
                    .padding(.top, Spacing.xs)
                    .padding(.bottom, 2)
                if let away = category.away {
                    leaderRow(away, team: summary.away?.team)
                }
                if let home = category.home {
                    leaderRow(home, team: summary.home?.team)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, Spacing.md)
    }

    private func leaderRow(_ leader: LeaderCategory.Leader, team: Team?) -> some View {
        HStack(spacing: Spacing.sm) {
            Text(team?.abbreviation ?? "")
                .font(.meta)
                .foregroundStyle(.textSecondary)
                .frame(width: 44, alignment: .leading)
            Text(leader.name)
                .font(.teamName)
                .foregroundStyle(.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(leader.statLine)
                .font(.meta.monospacedDigit())
                .foregroundStyle(.textSecondary)
                .lineLimit(1)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, 3)
    }
}
