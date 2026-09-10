import Foundation

#if canImport(ActivityKit)
import ActivityKit

/// Turns a `Game` (plus its maybe-nil fresher `GameSummary`) into the two
/// halves of a Live Activity.
///
/// This is `GameHeaderState`'s trick applied one surface further out: the
/// card must never re-derive a clock, a status or a merge of its own, or it
/// becomes the sixth renderer to get halftime wrong (decision 2026-08-31).
/// Everything here routes through `GameHeaderState`, which routes through
/// `GameStatus.liveStatusText(in:)`.
nonisolated enum LiveActivityContent {

    // MARK: - Attributes

    /// The fixed half. Built once when the activity starts.
    static func attributes(for game: Game) -> GameActivityAttributes {
        GameActivityAttributes(
            gameId: game.id,
            leagueToken: game.home.team.league.rawValue,
            away: side(game.away),
            home: side(game.home),
            kickoff: game.date
        )
    }

    private static func side(_ competitor: Competitor) -> GameActivityAttributes.Side {
        GameActivityAttributes.Side(
            // `location` is the last resort and never nil — an FCS visitor
            // ESPN gives no abbreviation to still names itself.
            abbreviation: competitor.team.abbreviation
                ?? competitor.team.shortDisplayName
                ?? competitor.team.location,
            record: competitor.record,
            logo: competitor.team.logoURL,
            darkLogo: competitor.team.logoURL?.darkTeamLogoVariant
        )
    }

    // MARK: - Content state

    /// The moving half. Rebuilt on every update.
    static func state(for game: Game,
                      summary: GameSummary? = nil,
                      now: Date = .now) -> GameActivityAttributes.ContentState {
        let merged = GameHeaderState.status(game, summary)
        let phase = phase(for: merged)
        let competitors = GameHeaderState.showsScores(game, summary)
        return GameActivityAttributes.ContentState(
            awayScore: competitors ? GameHeaderState.competitor(game.away, summary?.away).score : nil,
            homeScore: competitors ? GameHeaderState.competitor(game.home, summary?.home).score : nil,
            phase: phase,
            headline: headline(game, merged, phase: phase),
            detail: detail(game, summary, phase: phase),
            asOf: now
        )
    }

    /// `.other` — postponed, canceled, whatever ESPN invents next — maps to
    /// `.final` rather than growing a fifth case. The card's job in all of
    /// those is the same: stop claiming a clock is running and say the one
    /// word ESPN gave us. The activity is ended shortly after either way.
    static func phase(for status: GameStatus) -> GameActivityAttributes.Phase {
        switch status {
        case .pre:
            return .pre
        case .live(_, _, _, let live, _):
            return live == .playing ? .live : .intermission
        case .final, .other:
            return .final
        }
    }

    /// The centre slot. Before kickoff the time is the headline, at the
    /// card's largest size — the detail header made the same call on
    /// 2026-09-09, and the two surfaces should not disagree about which
    /// fact a pre-game screen is about.
    private static func headline(_ game: Game,
                                 _ status: GameStatus,
                                 phase: GameActivityAttributes.Phase) -> String {
        switch phase {
        case .pre:
            guard let date = game.date else { return "TBD" }
            guard !game.timeTBD else { return "TBD" }
            // "Sat 3:30 PM" — the weekday earns its place even on a card
            // started two hours out, because a Saturday slate runs into
            // the small hours and the day is what disambiguates it.
            return date.formatted(.dateTime.weekday(.abbreviated).hour().minute())
        case .live, .intermission:
            return status.liveStatusText(in: game.home.team.league) ?? "Live"
        case .final:
            if case .final(let detail) = status { return detail ?? "Final" }
            if case .other(let detail) = status { return detail ?? "—" }
            return "Final"
        }
    }

    /// The line under the headline: where to watch before kickoff, what's
    /// happening during. Nothing at a break or after the whistle — there is
    /// no live situation during halftime, and a final has nothing left to
    /// tune into (the widget's own rule, 2026-08-23).
    private static func detail(_ game: Game,
                               _ summary: GameSummary?,
                               phase: GameActivityAttributes.Phase) -> String? {
        switch phase {
        case .pre:
            return game.broadcast
        case .live:
            return situationLine(game, summary) ?? game.broadcast
        case .intermission, .final:
            return nil
        }
    }

    /// "3rd & 7 · UGA ball".
    ///
    /// Football only, and enforced by the payload rather than by a league
    /// check: `GameSummary.situation` is derived from `drives.current`, and
    /// ESPN ships drives for nothing else. Basketball and hockey therefore
    /// get no second line at all, which is the don't ("the test is whether
    /// the payload carries it") holding by construction.
    static func situationLine(_ game: Game, _ summary: GameSummary?) -> String? {
        guard let situation = summary?.situation else { return nil }
        let possessor = possessingAbbreviation(game, situation.possessionTeamId)
        let parts = [
            situation.downDistanceText,
            possessor.map { "\($0) ball" }
        ].compactMap(\.self)
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private static func possessingAbbreviation(_ game: Game, _ teamId: String?) -> String? {
        guard let teamId else { return nil }
        if game.away.team.id == teamId { return game.away.team.abbreviation }
        if game.home.team.id == teamId { return game.home.team.abbreviation }
        return nil
    }
}
#endif
