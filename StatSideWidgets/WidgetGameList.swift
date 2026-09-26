import SwiftUI
import WidgetKit

/// The stacked game list shared by the medium and large families: a
/// ★ Following header, rounded bgHeader card rows 2pt apart (no dividers),
/// and (large only) an updated/as-of footer, which doubles as the widget's
/// manual refresh. FotMob's breathing room in StatSide's row language.
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
                    Link(destination: game.deepLink ?? DeepLinkURL.teams) {
                        WidgetGameRow(game: game, stretches: shown.count == capacity)
                    }
                }
            }
            // A short list keeps its cards at their own height and leaves
            // the gap here, so the footer still sits at the bottom. Not on
            // a full one, where it would compete with the cards for height.
            if shown.count < capacity {
                Spacer(minLength: 0)
            }
            // Medium shows the line only when it has bad news to break:
            // its content box can't fit the masthead and two cards with
            // chrome to spare (decision log, 2026-08-23), so the footer is
            // large's. A stale medium still gets it — and with it, the
            // refresh that clears the staleness.
            if showsFooter || stale {
                WidgetUpdatedFooter(asOf: asOf, stale: stale)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, showsFooter ? Spacing.md : 2)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
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
/// a trailing status column — kickoff time, live clock, or Final.
///
/// The status column is a FIXED width, which is the whole point: on a
/// `minWidth` it grew with its own content, so a row reading "ACC Network"
/// pushed its scores further left than a row reading "FOX" and the score
/// column zig-zagged down the list. The app's `GameRow` pins the same
/// column at 80pt for the same reason (Andy, 2026-09-05).
///
/// 84pt rather than 64 since hockey arrived (Andy, 2026-09-09): football's
/// networks are three to five characters ("FOX", "ESPN") and the NHL's
/// regional ones are fourteen to sixteen ("The Spot - MTN", "FanDuel SN
/// South"), which truncated mid-name. The 20pt comes out of the team
/// block, which spends it on two- and three-letter abbreviations.
struct WidgetGameRow: View {
    let game: WidgetGame
    /// Whether the card grows to take its share of the leftover height.
    /// Only a full list does: two games in the large widget's four slots
    /// each stretched to double height, the teams floating in a tall grey
    /// box (Andy, 2026-09-25).
    var stretches = true

    @ScaledMetric(relativeTo: .caption2) private var statusWidth: CGFloat = 84

    var body: some View {
        // sm rather than the app's md on each side of the divider: the
        // widget card has a fraction of a phone row's width to spend.
        HStack(spacing: Spacing.sm) {
            // maxWidth lets each team line's internal spacer push its score
            // to the block's trailing edge, scores forming their own column.
            VStack(alignment: .leading, spacing: Spacing.xs) {
                WidgetTeamRow(line: game.away, emphasize: game.isLive, showScore: game.showsScores)
                WidgetTeamRow(line: game.home, emphasize: game.isLive, showScore: game.showsScores)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            // Every row, pre-game included: records now take the score's
            // trailing slot, so there is always a number column to divide
            // from, and the hairline keeps one x down the whole list.
            Rectangle()
                .fill(Color.divider)
                .frame(width: 1)
                .frame(maxHeight: .infinity)
            statusColumn
                .frame(width: statusWidth, alignment: .trailing)
        }
        // Ideal height, so the divider stretches to the team block rather
        // than to the card's stretched-to-fill height.
        .fixedSize(horizontal: false, vertical: true)
        .padding(Spacing.sm)
        // A full list's cards split the leftover height evenly (the mock's
        // stretch-to-fill rows) instead of leaving a dead gap above the
        // footer. A short one has too much leftover to split.
        .frame(maxHeight: stretches ? .infinity : nil)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.bgHeader)
        )
    }

    /// Trailing-aligned so the (shorter) network line hangs off the time's
    /// right edge, per the Figma mock — and so time and network hold the
    /// same right edge whether or not the row has scores.
    ///
    /// Type matches the app's status column exactly: 10 medium over 10
    /// regular (Andy, 2026-09-05). Supersedes the 12pt `metaMedium` these
    /// lines took in the 2026-08-23 widget remix.
    private var statusColumn: some View {
        VStack(alignment: .trailing, spacing: 2) {
            HStack(spacing: Spacing.xs) {
                if game.isLive {
                    Circle()
                        .fill(Color.liveAccent)
                        .frame(width: 6, height: 6)
                }
                Text(game.statusLine)
                    .font(.rowMetaMedium)
                    .foregroundStyle(.textPrimary)
                    .lineLimit(1)
            }
            // The kickoff time under its day, `GameRow`'s own split: the
            // joined "Sun, Sep 13 1:00 PM" overflowed the fixed column and
            // truncated mid-time (Andy, 2026-09-06).
            if let detail = game.statusDetail {
                Text(detail)
                    .font(.rowMeta)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            if let network = game.network {
                Text(network)
                    .font(.rowMeta)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
        }
    }
}
