import SwiftUI

/// Passing / rushing / receiving leaders, one line per side.
struct LeadersList: View {
    let summary: GameSummary

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .caption) private var abbreviationWidth: CGFloat = 44

    private var isStacked: Bool { dynamicTypeSize.isAccessibilitySize }

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

    /// Name and stat line share a row until accessibility sizes, where the
    /// stat line drops underneath — side by side they truncate each other to
    /// a pair of ellipses.
    @ViewBuilder
    private func leaderRow(_ leader: LeaderCategory.Leader, team: Team?) -> some View {
        let content = Group {
            if isStacked {
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: Spacing.sm) {
                        abbreviationText(team)
                        nameText(leader)
                        Spacer(minLength: 0)
                    }
                    statText(leader)
                }
            } else {
                HStack(spacing: Spacing.sm) {
                    abbreviationText(team)
                    nameText(leader)
                    Spacer()
                    statText(leader)
                }
            }
        }
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 3)
    }

    private func abbreviationText(_ team: Team?) -> some View {
        Text(team?.abbreviation ?? "")
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
            .fixedSize(horizontal: true, vertical: false)
            // A gutter so both sides' names start at the same x. Scaled, not
            // a hard 44pt — at accessibility sizes "MISS" otherwise wraps to
            // "MI" over "SS". The stacked row drops the gutter entirely; its
            // stat line below starts flush left.
            .frame(minWidth: isStacked ? nil : abbreviationWidth, alignment: .leading)
    }

    private func nameText(_ leader: LeaderCategory.Leader) -> some View {
        Text(leader.name)
            .font(.teamName)
            .foregroundStyle(.textPrimary)
            .lineLimit(isStacked ? 2 : 1)
    }

    private func statText(_ leader: LeaderCategory.Leader) -> some View {
        Text(leader.statLine)
            .font(.meta.monospacedDigit())
            .foregroundStyle(.textSecondary)
            .lineLimit(isStacked ? 2 : 1)
    }
}
