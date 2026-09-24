import SwiftUI

/// A card of three to five big numbers over their labels — a player's
/// season so far, or a team's. One shape for both, so a player's "566 YDS"
/// and a team's "32.0 TP/G" read as the same kind of fact (2026-09-24).
struct StatTilesCard: View {
    struct Tile: Identifiable, Hashable {
        let label: String
        let spokenLabel: String
        let value: String
        /// A quieter third line — football's opponent ranks, when shown.
        var detail: String?
        var id: String { label }
    }

    let title: String
    var subtitle: String?
    let tiles: [Tile]
    /// Draws the header's chevron, for a card the caller wraps in a link.
    var isLink = false

    var body: some View {
        VStack(spacing: 0) {
            CardHeader(title: title, subtitle: subtitle, isLink: isLink)
            HStack(alignment: .top, spacing: 0) {
                ForEach(tiles) { tile in
                    VStack(spacing: 2) {
                        Text(tile.value)
                            .font(.score)
                            .foregroundStyle(.textPrimary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        Text(tile.label)
                            .font(.rowMeta)
                            .foregroundStyle(.textSecondary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        if let detail = tile.detail {
                            Text(detail)
                                .font(.rowMeta)
                                .foregroundStyle(.textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel([tile.spokenLabel, tile.value, tile.detail]
                        .compactMap(\.self).joined(separator: ", "))
                }
            }
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.md)
        }
        .cardSurface()
    }
}
