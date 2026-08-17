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
                .widgetURL(URL(string: "statside://teams"))
        case .noGames:
            EmptyStateView(title: "No games this week",
                           subtitle: "Your teams' next kickoff will show up here.")
        case .games(let games, let stale):
            switch family {
            case .accessoryRectangular:
                AccessoryGameView(game: games[0])
                    .widgetURL(games[0].deepLink)
            case .systemLarge:
                WidgetGameList(games: games, stale: stale, asOf: entry.date,
                               capacity: 5, showsFooter: true)
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
            Text(game.statusLine)
                .font(.caption2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Shared pieces

struct WidgetTeamRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let line: WidgetTeamLine
    let emphasize: Bool
    var showScore = true

    var body: some View {
        HStack(spacing: Spacing.sm) {
            logo
            if let rank = line.rank {
                Text("\(rank)")
                    .font(.metaEmphasis)
                    .foregroundStyle(.textSecondary)
            }
            Text(line.abbreviation)
                .font(emphasize ? .teamNameEmphasis : .teamName)
                .foregroundStyle(line.muted ? .textSecondary : .textPrimary)
                .lineLimit(1)
            // Every state, unlike the app's GameRow: a widget glance skips
            // the team page, so the record stays as season context even
            // once the score arrives.
            if let record = line.record {
                Text(record)
                    .font(.meta)
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
                .frame(width: 20, height: 20)
        } else {
            Circle()
                .fill(Color.bgElevated)
                .frame(width: 20, height: 20)
        }
    }
}

struct WidgetScoreText: View {
    let line: WidgetTeamLine
    let emphasize: Bool

    var body: some View {
        Text(line.score.map(String.init) ?? "–")
            .font(line.muted ? .scoreMuted : (emphasize ? .scoreLive : .score))
            .foregroundStyle(line.muted ? .textSecondary : .textPrimary)
    }
}

/// Honest-not-wrong: a failed refresh re-serves the last snapshot with a
/// quiet timestamp instead of pretending it's current.
struct StaleMarker: View {
    let asOf: Date

    var body: some View {
        Text("as of \(asOf.formatted(.dateTime.hour().minute()))")
            .font(.meta)
            .foregroundStyle(.textSecondary)
            .lineLimit(1)
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
