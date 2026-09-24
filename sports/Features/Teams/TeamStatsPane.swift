import SwiftUI

/// The team page's Stats tab: every category ESPN tables for the season, in
/// ESPN's own names — and in football, the same categories for everyone who
/// played this team, behind a Team / Opponents switch (2026-09-24).
///
/// The Overview card leads with four of these; this is where the rest live.
/// The switch is the box score's capsule rather than a second tab row, for
/// that card's reason: a tab row sits right above it.
struct TeamStatsPane: View {
    let stats: TeamSeasonStats

    @State private var showsOpponents = false

    private var shown: [TeamSeasonStats.Category] {
        showsOpponents && !stats.opponent.isEmpty ? stats.opponent : stats.categories
    }

    var body: some View {
        VStack(spacing: Spacing.sm) {
            if !stats.opponent.isEmpty { sideSwitch }
            ForEach(shown) { category in
                LabeledValueCard(
                    title: category.title,
                    subtitle: category.id == shown.first?.id ? stats.seasonLabel : nil,
                    rows: category.stats.map { stat in
                        LabeledValueCard.Row(label: stat.fullName,
                                             value: stat.rank.map { "\(stat.value) · \($0)" } ?? stat.value,
                                             spokenLabel: stat.rank.map { "\(stat.fullName), ranked \($0)" })
                    })
            }
        }
    }

    private var sideSwitch: some View {
        HStack(spacing: 0) {
            segment("Team", active: !showsOpponents) { showsOpponents = false }
            segment("Opponents", active: showsOpponents) { showsOpponents = true }
        }
        .padding(4)
        .background(Capsule().fill(Color.bgElevated))
    }

    private func segment(_ title: String, active: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.chipEmphasis)
                .lineLimit(1)
                .foregroundStyle(active ? Color.bgPrimary : Color.textPrimary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Capsule().fill(active ? Color.textPrimary : Color.clear))
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(active ? [.isSelected] : [])
    }
}
