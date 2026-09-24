import SwiftUI

/// What the game belongs to, when it is, where to watch it, and what
/// it'll be like out — the pre-kick card the venue and the surface split
/// away from. A league row over icon-led lines, no zones between them.
struct KickoffInfoRows: View {
    let game: Game
    let summary: GameSummary
    /// The Settings switch (`UIStateStore.showsLines`), passed in so the
    /// gate stays a pure static.
    var showsLines = false

    /// Whether the card has anything to say — its gate, the
    /// `GameInfoRows.hasVenueContent` precedent.
    static func hasContent(game: Game, summary: GameSummary, showsLines: Bool = false) -> Bool {
        game.date != nil || game.broadcast != nil || !weatherLine(of: summary).isEmpty
            || !GameLeagueRow.destinations(for: game).isEmpty
            || line(game: game, summary: summary, showsLines: showsLines) != nil
    }

    /// The pre-game line (Coard Miller, 2026-09-24: the spread and the
    /// total are how a fan picks which games to follow). Before kickoff
    /// only: ESPN keeps shipping `pickcenter` on a final, but a line is a
    /// question about a game that hasn't happened, and this card outlives
    /// the kickoff. And only with Betting lines switched on in Settings.
    static func line(game: Game, summary: GameSummary, showsLines: Bool) -> GameLine? {
        guard showsLines, case .pre = GameHeaderState.status(game, summary) else { return nil }
        return summary.line
    }

    static func weatherLine(of summary: GameSummary) -> String {
        [summary.weatherTemperature.map { "\($0)°" }, summary.weatherCondition]
            .compactMap { $0 }.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            let tables = GameLeagueRow.destinations(for: game)
            if !tables.isEmpty {
                GameLeagueRow(league: game.home.team.league, destinations: tables)
            }
            if let date = game.date {
                GameInfoLine(symbol: "calendar",
                             text: game.timeTBD
                                ? "\(GameRow.relativeKickParts(date, weekday: .abbreviated).day) · Kickoff TBD"
                                : GameRow.relativeKick(date, weekday: .abbreviated))
            }
            if let broadcast = game.broadcast {
                GameInfoLine(symbol: "tv", text: broadcast)
            }
            let weather = Self.weatherLine(of: summary)
            if !weather.isEmpty {
                GameInfoLine(symbol: "cloud.sun", text: weather)
            }
            if let line = Self.line(game: game, summary: summary, showsLines: showsLines) {
                GameInfoLine(symbol: "plusminus", text: line.text)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Line, \(line.accessibilityText)")
            }
        }
        .padding(.vertical, Spacing.xs)
    }
}
