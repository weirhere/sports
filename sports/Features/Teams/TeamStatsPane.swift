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
        CapsuleSwitch(options: [(false, "Team"), (true, "Opponents")], selection: $showsOpponents)
    }
}
