import SwiftUI

/// A card with the two teams side by side — away on the left, home on the
/// right, the order American sports list them in (Andy, 2026-10-18) —
/// each column a run of the caller's cells under the team's own mark.
/// FotMob's bench, coach and injuries cards share this shape.
struct RosterSidesCard<Item: Identifiable, Cell: View>: View {
    /// Nil for a card whose team columns are its whole header — the
    /// NBA's and NHL's one starters card under the section's own title.
    let title: String?
    var subtitle: String? = nil
    let away: Team
    let home: Team
    let awayItems: [Item]
    let homeItems: [Item]
    @ViewBuilder let cell: (Item, Team) -> Cell

    var body: some View {
        VStack(spacing: 0) {
            if let title {
                CardHeader(title: title, subtitle: subtitle)
            }
            HStack(alignment: .top, spacing: 0) {
                column(away, items: awayItems)
                column(home, items: homeItems)
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    private func column(_ team: Team, items: [Item]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: Spacing.xs) {
                LogoImage(url: team.logoURL)
                    .frame(width: 16, height: 16)
                Text(team.abbreviation ?? team.location)
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, Spacing.xs)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(team.location)
            if items.isEmpty {
                Text("None")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.sm)
            } else {
                // Lazy for the same reason the team Roster tab is: a
                // college roster is a hundred photos a column.
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(items) { item in
                        cell(item, team)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }
}
