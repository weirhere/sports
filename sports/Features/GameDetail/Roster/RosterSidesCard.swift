import SwiftUI

/// A card with the two teams side by side — away on the left, home on the
/// right, the order American sports list them in (Andy, 2026-10-18) —
/// each column a run of the caller's cells under the team's own mark.
/// FotMob's bench, coach and injuries cards share this shape.
///
/// The columns can be cut into captioned groups (Andy, same day): a
/// football bench reads Offense, Defense, Special teams, each caption a
/// row across the whole card with the two columns under it, so the two
/// sides' kickers sit level instead of wherever their numbers fell. The
/// team marks stay at the top, once; a card with one uncaptioned group
/// is the plain two-column card.
struct RosterSidesCard<Item: Identifiable, Cell: View>: View {
    /// One captioned run of both columns.
    struct Group: Identifiable {
        let id: String
        /// Nil for a run that is the card's whole body.
        let caption: String?
        let away: [Item]
        let home: [Item]
    }

    /// Nil for a card whose team columns are its whole header — the
    /// NBA's and NHL's one starters card under the section's own title.
    let title: String?
    var subtitle: String? = nil
    let away: Team
    let home: Team
    let groups: [Group]
    @ViewBuilder let cell: (Item, Team) -> Cell

    init(title: String?, subtitle: String? = nil, away: Team, home: Team,
         groups: [Group], @ViewBuilder cell: @escaping (Item, Team) -> Cell) {
        self.title = title
        self.subtitle = subtitle
        self.away = away
        self.home = home
        self.groups = groups
        self.cell = cell
    }

    /// The plain card: one run per column, no caption.
    init(title: String?, subtitle: String? = nil, away: Team, home: Team,
         awayItems: [Item], homeItems: [Item], @ViewBuilder cell: @escaping (Item, Team) -> Cell) {
        self.init(title: title, subtitle: subtitle, away: away, home: home,
                  groups: [Group(id: "all", caption: nil, away: awayItems, home: homeItems)],
                  cell: cell)
    }

    var body: some View {
        VStack(spacing: 0) {
            if let title {
                CardHeader(title: title, subtitle: subtitle)
            }
            HStack(alignment: .top, spacing: 0) {
                mark(away)
                mark(home)
            }
            if groups.isEmpty {
                HStack(alignment: .top, spacing: 0) {
                    column([], team: away)
                    column([], team: home)
                }
            }
            ForEach(Array(groups.enumerated()), id: \.element.id) { index, group in
                if let caption = group.caption {
                    if index > 0 {
                        Divider().overlay(Color.divider).padding(.horizontal, Spacing.md)
                    }
                    Text(caption)
                        .font(.meta)
                        .textCase(.uppercase)
                        .foregroundStyle(.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)
                        .padding(.bottom, Spacing.xs)
                        .accessibilityAddTraits(.isHeader)
                }
                HStack(alignment: .top, spacing: 0) {
                    column(group.away, team: away)
                    column(group.home, team: home)
                }
            }
        }
        .padding(.bottom, Spacing.xs)
        .cardSurface()
    }

    private func mark(_ team: Team) -> some View {
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
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(team.location)
    }

    private func column(_ items: [Item], team: Team) -> some View {
        VStack(alignment: .leading, spacing: 0) {
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
