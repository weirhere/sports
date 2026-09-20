import AppIntents
import SwiftUI
import WidgetKit

/// Routes an entry to its family-specific layout. Same design language as
/// the app's game rows: monochrome chrome, logos in color, red only on live.
struct NextGameWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: NextGameEntry

    var body: some View {
        switch entry.state {
        case .noFollows:
            EmptyStateView(title: "Follow your teams",
                           subtitle: "Pick teams in StatSide and their games live here.")
                .widgetURL(DeepLinkURL.teams)
        case .noGames:
            // "This week" was true when the provider asked for one; it now
            // asks for a fortnight, and a team on a bye has no games in
            // either sense.
            EmptyStateView(title: "No games scheduled",
                           subtitle: "Your teams' next kickoff will show up here.")
        case .games(let games, let stale):
            switch family {
            case .accessoryRectangular:
                AccessoryGameView(game: games[0])
                    .widgetURL(games[0].deepLink)
            case .systemLarge:
                WidgetGameList(games: games, stale: stale, asOf: entry.date,
                               capacity: 4, showsFooter: true)
            default:
                WidgetGameList(games: games, stale: stale, asOf: entry.date,
                               capacity: 2, showsFooter: false)
            }
        }
    }
}

// MARK: - Lock screen

struct AccessoryGameView: View {
    let game: WidgetGame

    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            if game.showsScores, game.away.score != nil || game.home.score != nil {
                Text("\(game.away.abbreviation) \(game.away.score.map(String.init) ?? "–")")
                    .font(.headline.monospacedDigit())
                Text("\(game.home.abbreviation) \(game.home.score.map(String.init) ?? "–")")
                    .font(.headline.monospacedDigit())
            } else {
                Text("\(game.away.abbreviation) vs \(game.home.abbreviation)")
                    .font(.headline)
            }
            // One line to spend here, so the day and time rejoin.
            Text([game.statusLine, game.statusDetail].compactMap(\.self).joined(separator: " "))
                .font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shared pieces

struct WidgetTeamRow: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.widgetFamily) private var family
    let line: WidgetTeamLine
    let emphasize: Bool
    var showScore = true

    /// Medium's content box can't fit two 60pt cards; 16pt logos let the
    /// team line compress to its text height while padding stays at 8.
    private var logoSize: CGFloat { family == .systemMedium ? 16 : 20 }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            logo
            if let rank = line.rank {
                Text("\(rank)")
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
            }
            Text(line.abbreviation)
                .font(emphasize ? .chipEmphasis : .chip)
                .foregroundStyle(line.muted ? .textSecondary : .textPrimary)
                .lineLimit(1)
            // Every state, unlike the app's GameRow: a widget glance skips
            // the team page, so the record stays as season context even
            // once the score arrives.
            if let record = line.record {
                Text(record)
                    .font(.metaMedium)
                    .foregroundStyle(.textSecondary)
                    .lineLimit(1)
            }
            if showScore {
                Spacer(minLength: Spacing.xs)
                WidgetScoreText(line: line, emphasize: emphasize)
            }
        }
    }

    @ViewBuilder
    private var logo: some View {
        // Dark mode prefers the ESPN 500-dark mark; a team without one
        // falls back to its light logo, then to the placeholder disc.
        let image = colorScheme == .dark ? (line.darkLogo ?? line.logo) : line.logo
        if let image {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .frame(width: logoSize, height: logoSize)
        } else {
            Circle()
                .fill(Color.bgElevated)
                .frame(width: logoSize, height: logoSize)
        }
    }
}

/// The app's game-row score, exactly (Andy, 2026-09-06): 13 medium, 13
/// semibold live, and a losing side that gives up its *colour* rather than
/// its weight. The widget used to spend the 17pt `score` tokens the game
/// detail header uses, which made a 60pt card's numbers shout over the
/// team names beside them.
struct WidgetScoreText: View {
    let line: WidgetTeamLine
    let emphasize: Bool

    var body: some View {
        Text(line.score.map(String.init) ?? "–")
            .font(scoreFont)
            .foregroundStyle(line.muted ? .textSecondary : .textPrimary)
    }

    private var scoreFont: Font {
        // Live spends weight, per the budget — semibold at the row scale.
        // A muted loser keeps the base weight; only the ink changes.
        if emphasize, !line.muted { return .rowNameEmphasis.monospacedDigit() }
        return .rowName.monospacedDigit()
    }
}

/// The footer line — and the widget's only control.
///
/// Honest-not-wrong on the copy, as it always was: a failed refresh
/// re-serves the last snapshot under "as of" rather than presenting an old
/// score as current. What's new (Andy, 2026-09-20) is that the line is a
/// button, with the ↻ leading it and the pair taking one tap. The
/// timestamp is where a person already looks when they suspect the score is
/// stale — putting the remedy anywhere else would be a control nobody
/// finds — and a reload a person asked for is the one WidgetKit's budget
/// doesn't charge for, so this is the only refresh the app can promise.
///
/// Monochrome and `.plain` at the `meta` weight the line already had: the
/// refresh is chrome, and the colour budget's red belongs to live.
struct WidgetUpdatedFooter: View {
    let asOf: Date
    let stale: Bool

    private var timestamp: String {
        let time = asOf.formatted(.dateTime.hour().minute())
        return stale ? "as of \(time)" : "Updated \(time)"
    }

    var body: some View {
        Button(intent: RefreshWidgetIntent()) {
            HStack(spacing: Spacing.xs) {
                Image(systemName: "arrow.clockwise")
                Text(timestamp)
                    .lineLimit(1)
            }
            .font(.meta)
            .foregroundStyle(.textSecondary)
            // A 10pt glyph and a five-character time make a target about
            // as tall as a fingernail, so the line buys height it doesn't
            // draw. Padding before `contentShape`, so the bought area is
            // what takes the tap rather than the glyphs themselves.
            .padding(.vertical, 4)
            .padding(.horizontal, Spacing.sm)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        // VoiceOver hears the action first and the timestamp as its value,
        // rather than "as of 8:01 PM, button" — which says what it shows
        // and not what it does.
        .accessibilityLabel("Refresh scores")
        .accessibilityValue(timestamp)
    }
}

struct EmptyStateView: View {
    let title: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.teamNameEmphasis)
                .foregroundStyle(.textPrimary)
            Text(subtitle)
                .font(.meta)
                .foregroundStyle(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
