import Foundation

nonisolated struct Game: Identifiable, Hashable, Sendable {
    let id: String
    let date: Date?
    /// ESPN publishes a placeholder kickoff (midnight ET, `timeValid: false`)
    /// until a game's time is announced. True means `date`'s day is real but
    /// its clock time is noise — render "TBD", never "12:00 AM".
    ///
    /// That day is real *in Eastern*, which is not where most readers are:
    /// midnight ET is the previous calendar day everywhere west of it. The
    /// mapper re-anchors the placeholder to the reader's own day before it
    /// ever reaches this struct (`DayFormat.placeholderKickoff`), so `date`
    /// here always names the right day in the local calendar.
    var timeTBD: Bool = false
    let name: String?
    let shortName: String?
    let weekNumber: Int?
    /// ESPN's season type (2 regular, 3 postseason) when the payload says.
    /// Week numbers restart in the postseason, so grouping a season's
    /// slate by week needs this to keep a title game out of "Week 1".
    var seasonType: Int? = nil
    /// ESPN's name for this particular game, where it has one: the bowl,
    /// or the playoff round. Only postseason games carry it, and college
    /// football's postseason is unreadable without it.
    var headline: String? = nil
    let status: GameStatus
    let home: Competitor
    let away: Competitor
    let broadcast: String?

    var isLive: Bool {
        if case .live = status { return true }
        return false
    }

    /// What a navigation destination's identity keys on, so a game
    /// replaced at the same path position gets its own page rather than
    /// the previous game's (`Team.followKey`'s job, one layer over).
    ///
    /// League-qualified for `FollowKey`'s reason: ESPN's ids collide
    /// across leagues, and an event id is no safer than a team id.
    var routeKey: String { "\(home.team.league.rawValue):\(id)" }

    /// True when either side is ranked in the Top 25.
    var involvesRankedTeam: Bool {
        home.rank != nil || away.rank != nil
    }

    /// This team's fortunes right now, nil unless the game is live and the
    /// team is in it. Missing scores count as 0 — a just-kicked game reads
    /// as tied, never as no answer.
    func liveResult(for teamId: String) -> LiveResult? {
        guard isLive else { return nil }
        let mine: Int?
        let theirs: Int?
        if home.team.id == teamId {
            (mine, theirs) = (home.score, away.score)
        } else if away.team.id == teamId {
            (mine, theirs) = (away.score, home.score)
        } else {
            return nil
        }
        if (mine ?? 0) > (theirs ?? 0) { return .winning }
        if (mine ?? 0) < (theirs ?? 0) { return .losing }
        return .tied
    }
}

/// A live game's answer to "how's my team doing" — the standings dot's
/// three states.
nonisolated enum LiveResult: Sendable {
    case winning, losing, tied
}

nonisolated enum GameStatus: Hashable, Sendable {
    case pre(detail: String?)
    case live(displayClock: String?, period: Int?, detail: String?,
              phase: LivePhase, possessionTeamId: String?)
    case final(detail: String?)
    /// Postponed, canceled, or anything ESPN invents later. Renders its detail.
    case other(detail: String?)

    /// The live status line every surface renders — "Q3 5:24", "Half",
    /// "End Q1", "OT 0:48" — nil unless the game is live. One formatter so
    /// the row, detail header, widget, share text, and share card can't
    /// drift apart again; callers supply their own fallback for the rare
    /// live game with nothing to say (`?? "Live"`).
    func liveStatusText(in league: League = .collegeFootball) -> String? {
        guard case .live(let clock, let period, let detail, let phase, _) = self else { return nil }
        func label(_ period: Int) -> String { Self.periodLabel(period, in: league) }
        switch phase {
        case .halftime:
            return "Half"
        case .endOfPeriod:
            // The clock has run out, so "Q2 0:00" would claim a running
            // clock; the period alone carries the truth.
            return period.map { "End \(label($0))" } ?? detail
        case .playing:
            let line = [period.map(label), clock].compactMap(\.self).joined(separator: " ")
            return line.isEmpty ? detail : line
        }
    }

    /// "Q3" in football and basketball, "P2" in hockey, and past
    /// regulation whatever the overtime count is.
    ///
    /// No shootout label here on purpose: the status line only renders
    /// while a game is live, and a shootout arrives as a final. If one ever
    /// does show live, "1OT" is a wrong word rather than a wrong number.
    static func periodLabel(_ period: Int, in league: League = .collegeFootball) -> String {
        let format = league.periodFormat
        if period <= format.regulationCount { return "\(format.shortName)\(period)" }
        if period == format.regulationCount + 1 { return "OT" }
        return "\(period - format.regulationCount)OT"
    }
}

/// Where a live game's clock cycle stands. ESPN sends halftime and
/// end-of-quarter as `state: "in"` with the clock parked at 0:00, so a
/// renderer joining quarter + clock would show "Q2 0:00" where every other
/// scores app says "Half" — the boundary maps the status name into this
/// so renderers never re-derive it.
nonisolated enum LivePhase: Hashable, Sendable {
    case playing
    case halftime
    case endOfPeriod
}

nonisolated struct Competitor: Hashable, Sendable {
    let team: Team
    let score: Int?
    let record: String?   // overall record summary, e.g. "4-1"
    let rank: Int?        // curated rank when ≤ 25, else nil
    let isHome: Bool
    let winner: Bool?
}
