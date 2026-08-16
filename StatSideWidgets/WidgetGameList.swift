import SwiftUI
import WidgetKit

/// The stacked game list shared by the medium and large families: a
/// ★ Following header, roomy full-width rows with hairline dividers, and
/// (large only) an updated/as-of footer. FotMob's breathing room in
/// StatSide's row language.
struct WidgetGameList: View {
    let games: [WidgetGame]
    let stale: Bool
    let asOf: Date
    let capacity: Int
    let showsFooter: Bool

    private var shown: [WidgetGame] { Array(games.prefix(capacity)) }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            WidgetHeader()
                .padding(.bottom, Spacing.xs)
            ForEach(shown) { game in
                Link(destination: game.deepLink ?? URL(string: "statside://teams")!) {
                    WidgetGameRow(game: game)
                }
                if game.id != shown.last?.id {
                    Divider().overlay(Color.divider)
                }
            }
            if showsFooter {
                Spacer(minLength: 0)
                footer
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

/// Monochrome chrome: weight and size say "header", never color.
struct WidgetHeader: View {
    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "star.fill")
                .font(.system(size: 11, weight: .semibold))
            Text("Following")
                .font(.sectionHeader)
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
            HStack(spacing: Spacing.xs) {
                if game.isLive {
                    Circle()
                        .fill(Color.liveAccent)
                        .frame(width: 6, height: 6)
                }
                Text(game.statusLine)
                    .font(game.isLive ? .metaEmphasis : .meta)
                    .foregroundStyle(game.isLive ? .textPrimary : .textSecondary)
                    .lineLimit(1)
            }
            .frame(minWidth: 60, alignment: .center)
        }
        .padding(.vertical, Spacing.sm)
    }
}
