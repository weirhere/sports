import SwiftUI
import WidgetKit

/// The stacked game list shared by the medium and large families: a
/// ★ Following header, rounded bgHeader card rows 2pt apart (no dividers),
/// and (large only) an updated/as-of footer. FotMob's breathing room in
/// StatSide's row language.
struct WidgetGameList: View {
    @Environment(\.widgetFamily) private var family
    let games: [WidgetGame]
    let stale: Bool
    let asOf: Date
    let capacity: Int
    let showsFooter: Bool

    private var shown: [WidgetGame] { Array(games.prefix(capacity)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader()
                .padding(.bottom, family == .systemMedium ? Spacing.sm : Spacing.md)
            VStack(spacing: 2) {
                ForEach(shown) { game in
                    Link(destination: game.deepLink ?? URL(string: "statside://teams")!) {
                        WidgetGameRow(game: game)
                    }
                }
            }
            if showsFooter {
                footer
                    .padding(.top, Spacing.md)
            } else if stale {
                StaleMarker(asOf: asOf)
                    .padding(.top, 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    @ViewBuilder
    private var footer: some View {
        Group {
            if stale {
                StaleMarker(asOf: asOf)
            } else {
                Text("Updated \(asOf.formatted(.dateTime.hour().minute()))")
                    .font(.meta)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }
}

/// Monochrome chrome: weight and size say "header", never color. The medium
/// family scales the masthead down — its content box fits two cards only if
/// the chrome shrinks with it, and consistent padding beats consistent type.
struct WidgetHeader: View {
    @Environment(\.widgetFamily) private var family

    var body: some View {
        let compact = family == .systemMedium
        HStack(spacing: Spacing.xs) {
            // 20, not the mock's 24 icon box: the SF Symbol fills its frame
            // edge-to-edge while the mock's star has ~2pt of box padding,
            // so 20 is the optical match.
            Image(systemName: "star.fill")
                .resizable()
                .scaledToFit()
                .frame(width: compact ? 16 : 20, height: compact ? 16 : 20)
            Text("Following")
                .font(compact ? .sectionHeaderProminentCompact : .sectionHeaderProminent)
                .tracking(compact ? -0.28 : -0.32)  // the mock's -2%
        }
        .foregroundStyle(.textPrimary)
    }
}

/// One game: two team lines (scores inline, absent entirely pre-game) and
/// a trailing status column — kickoff time, live clock, or FINAL.
struct WidgetGameRow: View {
    let game: WidgetGame

    var body: some View {
        HStack(spacing: Spacing.md) {
            // maxWidth lets each team line's internal spacer push its score
            // to the block's trailing edge, scores forming their own column.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                WidgetTeamRow(line: game.away, emphasize: game.isLive, showScore: game.showsScores)
                WidgetTeamRow(line: game.home, emphasize: game.isLive, showScore: game.showsScores)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Trailing-aligned so the (shorter) network line hangs off the
            // time's right edge, per the Figma mock.
            VStack(alignment: .trailing, spacing: 1) {
                HStack(spacing: Spacing.xs) {
                    if game.isLive {
                        Circle()
                            .fill(Color.liveAccent)
                            .frame(width: 6, height: 6)
                    }
                    Text(game.statusLine)
                        .font(game.isLive ? .metaEmphasis : .metaMedium)
                        .foregroundStyle(game.isLive ? .textPrimary : .textSecondary)
                        .lineLimit(1)
                }
                if let network = game.network {
                    Text(network)
                        .font(.metaMedium)
                        .foregroundStyle(.textSecondary)
                        .lineLimit(1)
                }
            }
            .frame(minWidth: 60, alignment: .center)
        }
        .padding(Spacing.sm)
        // Cards split the leftover height evenly (the mock's stretch-to-fill
        // rows) instead of leaving a dead gap above the footer.
        .frame(maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.bgHeader)
        )
    }
}
