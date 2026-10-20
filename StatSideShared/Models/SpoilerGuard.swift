import Foundation

/// Spoiler mode's one rule (E30, 2026-10-19, from pingroomio's launch-day
/// note: *"a way to hide scores until you've watched the game"*): which
/// games hide their result, and what a hidden game looks like.
///
/// **Followed teams by default, every game by choice.** A fan time-shifts
/// their own team's game, not the other twenty on the slate, and My
/// teams is the scope every other team-driven surface already settled on
/// (the widget, the reminders) — team follows, not conference follows,
/// the Following section's own test applied to a different question.
/// All games is pingroomio's second note the same day (*"I'd start with
/// a global switch"*): it covers the primetime game between two teams
/// you don't follow, at the price of the whole slate reading as a
/// schedule, which is why it is the choice and not the default.
///
/// **A final hides for seven days.** Without a window every final a
/// followed team ever played would hide — the head-to-head pane's ten
/// meetings, a conference page's season — and "rewind the record one
/// game" only holds if at most one game per team is hidden at a time.
/// A week outlives any sensible time-shift and is shorter than the gap
/// between a team's games in every league but basketball and hockey,
/// where a fan who hasn't watched Tuesday's game by the next Tuesday has
/// seen the standings anyway.
///
/// **Revealed per game, by a tap.** "Watched" is something the app cannot
/// know, so the reveal is the user's word for it; `SpoilerStore` keeps the
/// revealed keys for longer than the window, so a reveal always outlives
/// its concealment.
///
/// A value, not a store, and in the shared target: the widget needs the
/// same answer from the same inputs (E30 PR 2), and `Hashable` so the
/// sections memo can key on it.
nonisolated struct SpoilerGuard: Hashable, Sendable {
    var isEnabled: Bool
    /// `Team.followKey`s — `"cfb:61"`.
    var followedKeys: Set<String>
    /// `Game.routeKey`s — `"cfb:401…"`. ESPN event ids collide across
    /// leagues like team ids do, so a bare id would reveal two games.
    var revealedKeys: Set<String>
    /// Which games the mode reaches. Declared after the sets, with a
    /// default, so a caller that never heard of scopes still builds the
    /// My teams guard.
    var scope: Scope = .followedTeams

    /// The two reaches of the mode. Raw values are what `SpoilerStore`
    /// persists and what a UI suite pins (`-spoiler.scope all`).
    enum Scope: String, CaseIterable, Hashable, Sendable {
        /// Games with a followed team in them.
        case followedTeams = "followed"
        /// Every game on the slate.
        case allGames = "all"
    }

    /// How long after kickoff a final stays hidden.
    static let finalWindow: TimeInterval = 7 * 86_400

    static let off = SpoilerGuard(isEnabled: false, followedKeys: [], revealedKeys: [])

    /// Whether `game`'s result is hidden right now.
    func conceals(_ game: Game, now: Date = .now) -> Bool {
        guard isEnabled else { return false }
        if scope == .followedTeams {
            guard followedKeys.contains(game.home.team.followKey)
                    || followedKeys.contains(game.away.team.followKey) else { return false }
        }
        guard !revealedKeys.contains(game.routeKey) else { return false }
        switch game.status {
        case .live:
            return true
        case .final:
            // No date is no evidence the game is old; keep it hidden.
            guard let date = game.date else { return true }
            return now.timeIntervalSince(date) <= Self.finalWindow
        case .pre, .other:
            return false
        }
    }
}

nonisolated extension Game {
    /// This game with each side's record replaced — the one field
    /// `withLiveState` leaves alone. Nil keeps the side's own.
    func withRecords(home homeRecord: String?, away awayRecord: String?) -> Game {
        func side(_ competitor: Competitor, record: String?) -> Competitor {
            Competitor(team: competitor.team, score: competitor.score,
                       record: record ?? competitor.record, rank: competitor.rank,
                       isHome: competitor.isHome, winner: competitor.winner)
        }
        var copy = Game(id: id, date: date, timeTBD: timeTBD, name: name, shortName: shortName,
                        weekNumber: weekNumber, seasonType: seasonType, seasonYear: seasonYear,
                        headline: headline, status: status,
                        home: side(home, record: homeRecord),
                        away: side(away, record: awayRecord),
                        broadcast: broadcast)
        copy.line = line
        copy.isConferenceGame = isConferenceGame
        copy.broadcasts = broadcasts
        copy.venue = venue
        copy.venueCity = venueCity
        copy.venueIndoor = venueIndoor
        return copy
    }

    /// This game with its result taken out: no scores, no winner flags,
    /// no line, the status collapsed to a bare live or final (no clock,
    /// period, possession or "OT"), and each side's record rewound one
    /// game (`RecordRewind`). Everything else is kept — the teams, ranks,
    /// kickoff, network, venue, and the headline, which names the bowl or
    /// the playoff round, not who won it.
    ///
    /// Views render the concealed copy rather than being told to look
    /// away: a view that forgets the flag still can't print a score it
    /// was never handed. Pre-game and postponed games come back unchanged;
    /// there is nothing to conceal.
    func concealed() -> Game {
        let bare: GameStatus
        switch status {
        case .live:
            bare = .live(displayClock: nil, period: nil, detail: nil, phase: .playing,
                         possessionTeamId: nil)
        case .final:
            bare = .final(detail: nil)
        case .pre, .other:
            return self
        }
        let league = home.team.league
        func side(_ competitor: Competitor, against other: Competitor) -> Competitor {
            Competitor(team: competitor.team, score: nil,
                       record: RecordRewind.rewound(competitor.record, for: competitor, against: other,
                                                    status: status, league: league),
                       rank: competitor.rank, isHome: competitor.isHome, winner: nil)
        }
        var copy = Game(id: id, date: date, timeTBD: timeTBD, name: name, shortName: shortName,
                        weekNumber: weekNumber, seasonType: seasonType, seasonYear: seasonYear,
                        headline: headline, status: bare,
                        home: side(home, against: away),
                        away: side(away, against: home),
                        broadcast: broadcast)
        // Deliberately not the line: who was favored, next to a final with
        // no score, is half the result.
        copy.isConferenceGame = isConferenceGame
        copy.broadcasts = broadcasts
        copy.venue = venue
        copy.venueCity = venueCity
        copy.venueIndoor = venueIndoor
        return copy
    }
}
