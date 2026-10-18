import Foundation

/// Assembling a game's roster out of the sources that exist, because ESPN
/// has no one resource that answers "who is in this game" for American
/// sports the way its soccer `rosters` block does.
///
/// Per side, up to three requests on top of the summary the page already
/// holds: the team's own `/roster` (names, photos, the head coach — current
/// season only, since ESPN serves no other), the core API's game-day
/// roster (starters and inactives, where the league publishes them), and,
/// before an NBA or NHL game, the depth chart (the only pre-game "who
/// starts" either league has). Six requests at most, once per visit to the
/// tab and never polled — a lineup moves at kickoff and at a scratch, both
/// of which flip the summary's status and re-run this through the tab's
/// task id.
///
/// Each request is allowed to fail alone: a roster that 404s leaves the
/// box score to name the players, a depth chart that errors leaves the
/// roster with no starters on top. Only a game where *every* request
/// failed throws, because an empty tab and a broken one look the same on
/// screen and only one of them should offer Retry.
nonisolated extension ScoresProviding {
    func gameRoster(for game: Game, summary: GameSummary?, phase: GameRoster.Phase,
                    currentSeason: Bool) async throws -> GameRoster {
        let league = game.home.team.league
        let away = game.away.team, home = game.home.team
        let wantsDepthChart = phase == .upcoming && (league == .nba || league == .nhl)

        async let awayRoster: TeamRoster? = currentSeason ? try? roster(teamId: away.id) : nil
        async let homeRoster: TeamRoster? = currentSeason ? try? roster(teamId: home.id) : nil
        async let awayLineup: [LineupEntry]? = try? gameLineup(eventId: game.id, teamId: away.id)
        async let homeLineup: [LineupEntry]? = try? gameLineup(eventId: game.id, teamId: home.id)
        async let awayDepth: [DepthSlot]? = wantsDepthChart ? try? depthChart(teamId: away.id) : nil
        async let homeDepth: [DepthSlot]? = wantsDepthChart ? try? depthChart(teamId: home.id) : nil

        let results = (await awayRoster, await homeRoster, await awayLineup,
                       await homeLineup, await awayDepth, await homeDepth)
        let anyAnswered = results.0 != nil || results.1 != nil || results.2 != nil
            || results.3 != nil || results.4 != nil || results.5 != nil
        // The summary is a source too: a page whose box score names the
        // players has a roster to show even when every request above
        // failed, so the throw is reserved for the truly empty case.
        guard anyAnswered || summary?.boxScore.isEmpty == false else {
            throw ESPNError.badStatus(0)
        }

        func input(_ team: Team, roster: TeamRoster?, lineup: [LineupEntry]?,
                   depth: [DepthSlot]?) -> GameRoster.SideInput {
            GameRoster.SideInput(
                team: team,
                roster: roster,
                lineup: lineup ?? [],
                depthChart: depth ?? [],
                boxScore: summary?.boxScore.first { $0.teamId == team.id },
                injuries: summary?.injuries.first { $0.teamId == team.id }?.injuries ?? [],
                onIce: summary?.onIce[team.id] ?? [])
        }
        return GameRoster.make(
            phase: phase, league: league,
            away: input(away, roster: results.0, lineup: results.2, depth: results.4),
            home: input(home, roster: results.1, lineup: results.3, depth: results.5))
    }
}
