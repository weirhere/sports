import Foundation

/// What these two teams have done to each other before — the completed
/// meetings we can see, and the tally they add up to.
///
/// **The tally is of the window, and the window is not history.** ESPN
/// publishes no head-to-head resource, so a series is assembled by walking
/// one team's schedules back season by season (see `headToHead(for:)`) —
/// which means the record here is "since 2017", never "all-time". Alabama
/// and Tennessee have met 100+ times; printing "Alabama leads 7-3" without
/// saying what it counts would be a flat lie, so `windowLabel` travels with
/// the numbers and every surface renders it.
nonisolated struct HeadToHead: Sendable, Equatable {
    /// The meetings, newest first. Finals only — a scheduled rematch is not
    /// history, and neither is the game this was built for.
    let meetings: [Game]
    /// Wins for the side that is away in the game this was built for. Which
    /// end they played from in any given meeting is beside the point: the
    /// tally follows the team, not the fixture.
    let awayWins: Int
    let homeWins: Int
    /// College football could still tie until 1996 and hockey until 2005.
    /// Inside any window we fetch it should always be zero — but a series
    /// that quietly dropped a game rather than admit it was drawn would be
    /// the one bug nobody would ever see.
    let ties: Int
    /// The earliest season searched — the window's floor, not the first
    /// meeting found.
    let earliestSeason: Int
    let league: League

    var isEmpty: Bool { meetings.isEmpty }

    /// "Since 2017", "Since 2024-25" — the caption that keeps the tally
    /// honest about what it counted.
    var windowLabel: String { "Since \(league.seasonLabel(earliestSeason))" }

    /// Which side is ahead, for the weight the numbers wear. Nil when the
    /// series is level, so neither number takes the emphasis.
    var leader: LeadingSide? {
        if awayWins > homeWins { return .away }
        if homeWins > awayWins { return .home }
        return nil
    }

    enum LeadingSide: Sendable, Equatable { case away, home }

    /// The series in a sentence, for VoiceOver and anywhere a line of prose
    /// beats a scoreboard: "Georgia leads 6-4 since 2017".
    func summarySentence(away: Team, home: Team) -> String {
        guard !isEmpty else { return "No meetings \(windowLabel.lowercased())" }
        let tie = ties > 0 ? "-\(ties)" : ""
        switch leader {
        case .away:
            return "\(away.location) leads \(awayWins)-\(homeWins)\(tie) \(windowLabel.lowercased())"
        case .home:
            return "\(home.location) leads \(homeWins)-\(awayWins)\(tie) \(windowLabel.lowercased())"
        case nil:
            return "Series level at \(awayWins)-\(homeWins)\(tie) \(windowLabel.lowercased())"
        }
    }

    /// Builds the series from one team's fetched seasons.
    ///
    /// `games` is everything that team played across the window — the filter
    /// to the matchup lives here rather than at the fetch so it is testable
    /// without a network, and so the rules for what counts are written down
    /// in one place:
    ///
    /// - **Both these teams**, by id. Ids collide across leagues, never
    ///   inside one, and a window is always fetched inside one league.
    /// - **Final only.** A postponed game was never played and a scheduled
    ///   rematch has not been.
    /// - **Not this game**, by id — and not anything after it. Open a 2019
    ///   game and the series is what it was in 2019; the meetings since are
    ///   not history the 2019 page can have known about.
    /// - **Exhibitions excluded** upstream, by the fetch. A preseason game
    ///   has never counted in a head-to-head record and it does not start
    ///   here (the 2026-09-06 preseason split's reasoning, applied to a
    ///   tally instead of a card).
    static func make(from games: [Game], anchor: Game,
                     earliestSeason: Int) -> HeadToHead {
        let awayId = anchor.away.team.id
        let homeId = anchor.home.team.id
        let league = anchor.home.team.league

        var seen = Set<String>()
        let meetings = games
            .filter { game in
                guard game.id != anchor.id, seen.insert(game.id).inserted else { return false }
                guard case .final = game.status else { return false }
                let ids = [game.away.team.id, game.home.team.id]
                guard ids.contains(awayId), ids.contains(homeId) else { return false }
                // Before this one. A game with no date can't be placed
                // against the anchor, so it is kept rather than guessed at.
                guard let anchorDate = anchor.date, let date = game.date else { return true }
                return date < anchorDate
            }
            // Newest first: the last meeting is the one anybody asks about.
            // Undated meetings sort last rather than jumping the queue.
            .sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }

        var awayWins = 0, homeWins = 0, ties = 0
        for meeting in meetings {
            switch winner(of: meeting, awayId: awayId) {
            case .some(true): awayWins += 1
            case .some(false): homeWins += 1
            case nil: ties += 1
            }
        }
        return HeadToHead(meetings: meetings, awayWins: awayWins, homeWins: homeWins,
                          ties: ties, earliestSeason: earliestSeason, league: league)
    }

    /// True when the anchor's away team won this meeting, false when the
    /// home team did, nil for a draw.
    ///
    /// Scores first, ESPN's `winner` flag second: the flag is missing often
    /// enough on older payloads that trusting it alone loses games, and two
    /// numbers can't disagree with themselves. A meeting with neither is a
    /// tie by arithmetic, which is wrong — so it takes the flag's answer
    /// when there is one and is only counted level when nothing says
    /// otherwise.
    private static func winner(of meeting: Game, awayId: String) -> Bool? {
        let mine = meeting.away.team.id == awayId ? meeting.away : meeting.home
        let theirs = meeting.away.team.id == awayId ? meeting.home : meeting.away
        if let a = mine.score, let b = theirs.score, a != b { return a > b }
        if let won = mine.winner, won { return true }
        if let won = theirs.winner, won { return false }
        return nil
    }
}
