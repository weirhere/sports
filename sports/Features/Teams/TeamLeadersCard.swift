import SwiftUI

/// Who leads the team, category by category — passing, rushing, receiving
/// and the defence in football, points, rebounds and assists in the NBA,
/// points, goals and the goalie in the NHL (2026-09-24). Every row pushes
/// the player's page.
///
/// The game page's Leaders card answers "who did it tonight"; this answers
/// "who has done it all season", in the same row language: headshot disc,
/// name, the number that earned the row.
struct TeamLeadersCard: View {
    let leaders: [TeamStatsModel.Leader]
    /// "2025-26" when the season shown isn't the one in progress.
    var seasonLabel: String?

    @ScaledMetric(relativeTo: .subheadline) private var headshotSize: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: "Leaders", subtitle: seasonLabel)
            ForEach(Array(leaders.enumerated()), id: \.element.id) { index, leader in
                NavigationLink(value: leader.player) {
                    row(leader)
                }
                .buttonStyle(.plain)
                if index < leaders.count - 1 {
                    Divider().overlay(Color.divider).padding(.leading, Spacing.lg + headshotSize + Spacing.md)
                }
            }
        }
        .cardSurface()
    }

    /// Football's leaders carry a whole line — "47/74, 566 YDS, 5 TD, 1 INT"
    /// — which reads under the name, where there is room for it. A single
    /// number ("33.5") stands on the right in the row's emphasis, as the
    /// game page's Leaders card sets a value.
    private func isStatLine(_ leader: TeamStatsModel.Leader) -> Bool {
        leader.entry.value.contains(",")
    }

    private func row(_ leader: TeamStatsModel.Leader) -> some View {
        HStack(spacing: Spacing.md) {
            LogoImage(url: leader.headshotURL?.headshotThumbnail ?? leader.headshotURL,
                      contentMode: .fill)
                .frame(width: headshotSize, height: headshotSize)
                .background(Circle().fill(Color.bgElevated))
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 2) {
                Text(leader.entry.title)
                    .font(.rowMeta)
                    .foregroundStyle(.textSecondary)
                Text(leader.name)
                    .font(.rowName)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
                if isStatLine(leader) {
                    Text(leader.entry.value)
                        .font(.rowMeta.monospacedDigit())
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }
            }
            Spacer(minLength: Spacing.sm)
            if !isStatLine(leader) {
                Text(leader.entry.value)
                    .font(.rowNameEmphasis.monospacedDigit())
                    .foregroundStyle(.textPrimary)
            }
            Image(systemName: "chevron.right")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.textSecondary)
        }
        .padding(.horizontal, Spacing.lg)
        .padding(.vertical, Spacing.sm)
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(leader.entry.title) leader, \(leader.name), \(leader.entry.value)")
        .accessibilityHint("View player page")
    }
}
