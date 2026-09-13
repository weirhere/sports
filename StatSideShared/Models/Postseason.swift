import Foundation

/// One round of a league's postseason, and its games.
nonisolated struct PostseasonRound: Identifiable, Sendable {
    let name: String
    let games: [Game]

    var id: String { name }

    /// When the round starts — what orders the chips.
    var kickoff: Date? { games.compactMap(\.date).min() }

    /// True once every game in the round has been played.
    var isComplete: Bool {
        !games.isEmpty && games.allSatisfy { if case .final = $0.status { true } else { false } }
    }
}

/// The postseason, split into rounds a fan would name (Andy, 2026-09-06,
/// from the ESPN and FotMob references).
///
/// The two leagues encode it completely differently, which is why this is a
/// mapping and not a field:
///
/// **The NFL** numbers its rounds as `seasontype=3` weeks — 1 Wild Card,
/// 2 Divisional, 3 Conference Championships, 5 Super Bowl. Week **4 is the
/// Pro Bowl**, which is not a playoff round at all: nothing feeds it and it
/// feeds nothing. It is no longer a round of its own (Andy, 2026-09-06) —
/// see `exhibition(from:league:)`, which hangs it under the final the way
/// FotMob hangs a World Cup's bronze final under the final.
///
/// **College football** files its entire postseason under one week — 46
/// games in `seasontype=3` week 1 (verified live 2026-09-06), bowls and
/// playoff alike — so the round lives in ESPN's printed headline and
/// nowhere else.
///
/// The bowls are then dropped (Andy, 2026-09-06: "reserve that tab just for
/// the playoffs"). Thirty-eight exhibitions in a column marked "Bowls" was
/// the biggest thing on a screen whose subject is a twelve-team bracket,
/// and nothing about them is bracket-shaped — no bowl feeds anything. They
/// keep their place on the Games tab, in date order with the rest of the
/// season, which is where a list of games belongs.
///
/// Rounds order by first kickoff rather than by a hardcoded sequence, which
/// is the one rule that reads correctly for both: the NFL's weeks are
/// already chronological, and it puts college football's bowls ahead of a
/// playoff that starts a week later without either league needing a special
/// case. A round we can't name at all falls back to "Postseason", so a
/// format change costs a label, never a missing game.
nonisolated enum Postseason {
    /// ESPN's `season.type` for the postseason.
    static let seasonType = 3

    /// And for the exhibitions. It lives beside its sibling rather than as
    /// a literal in a fourth place: the preseason grouping, the team page's
    /// phase split and the head-to-head fetch all read it.
    static let preseasonSeasonType = 1

    static func games(in games: [Game]) -> [Game] {
        games.filter { $0.seasonType == seasonType }
    }

    static func rounds(from games: [Game], league: League) -> [PostseasonRound] {
        let exhibitionIds = Set(exhibition(from: games, league: league)?.games.map(\.id) ?? [])
        let postseason = self.games(in: games).filter { !exhibitionIds.contains($0.id) }
        guard !postseason.isEmpty else { return [] }
        // A game with no round name isn't in the bracket at all.
        let bracketGames = postseason.filter { name(for: $0, league: league) != nil }
        guard !bracketGames.isEmpty else { return [] }
        let grouped = Dictionary(grouping: bracketGames) {
            name(for: $0, league: league) ?? ""
        }
        return grouped
            .map { name, games in
                PostseasonRound(name: name,
                                games: games.sorted { ($0.date ?? .distantFuture)
                                    < ($1.date ?? .distantFuture) })
            }
            .sorted { ($0.kickoff ?? .distantFuture) < ($1.kickoff ?? .distantFuture) }
    }

    /// The round a page should open on: the first one still being played,
    /// or the last one when the postseason is over — never the Wild Card
    /// round in February.
    static func defaultRound(in rounds: [PostseasonRound]) -> String? {
        rounds.first { !$0.isComplete }?.name ?? rounds.last?.name
    }

    /// The round this game belongs to, or nil where it belongs to no round
    /// — a bowl, which is postseason football but not playoff football.
    private static func name(for game: Game, league: League) -> String? {
        switch league {
        case .nfl: nflName(week: game.weekNumber)
        case .collegeFootball: collegeName(headline: game.headline)
        // The NBA and NHL playoffs are best-of-seven *series*, and this
        // bracket models single-elimination games: `feeders(of:from:)`
        // reads advancement off "a completed game's winner turns up in a
        // later game", which is true of every game of a series against
        // the same opponent. Naming no round means `rounds(from:league:)`
        // produces none and the Postseason tab never appears — the
        // deferral made explicit rather than accidental. The data is
        // there when we build it: playoff games carry
        // `competitions[].series` with each side's wins.
        case .nba, .nhl: nil
        }
    }

    private static func nflName(week: Int?) -> String {
        switch week {
        case 1: "Wild Card"
        case 2: "Divisional"
        case 3: "Conference Championships"
        case 5: "Super Bowl"
        // Week 4 never reaches here — `rounds` filters the exhibition out
        // before naming anything.
        default: "Postseason"
        }
    }

    /// The postseason games that are not part of the bracket: the NFL's Pro
    /// Bowl, filed under the same season type but fed by nothing and
    /// feeding nothing.
    ///
    /// It shows beneath the last round rather than beside it (Andy,
    /// 2026-09-06) — FotMob's treatment of a World Cup's bronze final,
    /// which has exactly the same problem: a real fixture with no place in
    /// the tree. A chip of its own put an all-star game between the
    /// conference championships and the Super Bowl, which is the one thing
    /// a bracket must never imply.
    static func exhibition(from games: [Game], league: League) -> PostseasonRound? {
        guard league == .nfl else { return nil }
        let matches = self.games(in: games)
            .filter { $0.weekNumber == 4 }
            .sorted { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }
        return matches.isEmpty ? nil : PostseasonRound(name: "Pro Bowl", games: matches)
    }

    /// Matched on ESPN's own wording, loosely: the headlines carry sponsor
    /// names and venues ("College Football Playoff Quarterfinal at the
    /// Allstate Sugar Bowl"), so the round is a substring, never the whole
    /// string. A quarterfinal played *at* a bowl is a quarterfinal, which
    /// is why the playoff rounds are all checked and a bowl is only what's
    /// left over — nil, and out of the bracket.
    private static func collegeName(headline: String?) -> String? {
        guard let headline, !headline.isEmpty else { return nil }
        let text = headline.lowercased()
        if text.contains("national championship") { return "National Championship" }
        if text.contains("semifinal") { return "Semifinals" }
        if text.contains("quarterfinal") { return "Quarterfinals" }
        if text.contains("first round") { return "First Round" }
        return nil
    }
}

extension Postseason {
    /// The games in `previous` whose winner turns up in `game` — the only
    /// advancement we can prove.
    ///
    /// Read off results, never off seeds. ESPN's scoreboard publishes no
    /// bracket tree, so the alternative would be assuming that the first
    /// two games of a round feed the first game of the next — which is
    /// wrong the moment a format reseeds, and wrong invisibly. A round
    /// nobody has played yet therefore draws no lines at all, and the
    /// bracket wires itself up as results land.
    static func feeders(of game: Game, from previous: [Game]) -> [Game] {
        let sides = Set([game.home.team.id, game.away.team.id])
        return previous.filter { earlier in
            guard let winner = earlier.winnerTeamId else { return false }
            return sides.contains(winner)
        }
    }
}

nonisolated extension Game {
    /// The winning side's team id, once there is one.
    var winnerTeamId: String? {
        if home.winner == true { return home.team.id }
        if away.winner == true { return away.team.id }
        return nil
    }
}

/// What feeds one game of the next round: an earlier game, or a team that
/// sat the round out.
nonisolated enum BracketSource: Identifiable, Sendable {
    case game(Game)
    /// A team that reached the next round without playing this one — the
    /// bye a top seed earns. ESPN shows these as their own entry, and
    /// without them a bracket has teams appearing from nowhere (Andy,
    /// 2026-09-06).
    case bye(Team)

    var id: String {
        switch self {
        case .game(let game): "game-\(game.id)"
        case .bye(let team): "bye-\(team.followKey)"
        }
    }
}

/// One round laid out against the round it feeds.
nonisolated struct BracketPairing: Sendable {
    /// The left column, top to bottom — already ordered so each next-round
    /// game's own sources sit together.
    let sources: [BracketSource]
    /// Each next-round game with the positions in `sources` that feed it.
    let links: [(game: Game, sourceIndices: [Int])]
}

extension Postseason {
    /// Pair a round against the next one, so the bracket can be *drawn*
    /// rather than merely listed (Andy, 2026-09-06: the chronological
    /// columns "doesn't make sense with how the advancements occur").
    ///
    /// Two things were wrong with listing both rounds by kickoff. The next
    /// round's games sat wherever the calendar put them, so a winner's line
    /// crossed the column to reach its game; and a team that earned a bye
    /// appeared in the second column having never been in the first.
    ///
    /// So the left column is rebuilt in *bracket* order — for each game of
    /// the next round, the sources that produce it, byes first (a bye is
    /// always the better seed) — and the caller places each next-round game
    /// level with its own sources. Lines then run straight across.
    ///
    /// Returns nil when the two rounds aren't connected by any result we
    /// can see: college football's bowls don't feed its playoff, and a
    /// round nobody has played yet proves nothing. The caller falls back to
    /// two plain columns, which is honest about knowing no more than that.
    static func pairing(round: [Game], next: [Game]) -> BracketPairing? {
        let played = Set(round.flatMap { [$0.home.team.id, $0.away.team.id] })
        var sources: [BracketSource] = []
        var index: [String: Int] = [:]
        var links: [(game: Game, sourceIndices: [Int])] = []
        var connected = false

        for game in next.sorted(by: { ($0.date ?? .distantFuture) < ($1.date ?? .distantFuture) }) {
            let feeders = self.feeders(of: game, from: round)
            if !feeders.isEmpty { connected = true }
            // A side that never appeared in this round didn't lose its way
            // here — it sat the round out. Only meaningful once something
            // in this pairing is connected at all, which the nil return
            // below enforces.
            let byes = [game.away, game.home]
                .filter { !played.contains($0.team.id) }
                .map(\.team)
            var indices: [Int] = []
            for source in byes.map(BracketSource.bye) + feeders.map(BracketSource.game) {
                if let existing = index[source.id] {
                    indices.append(existing)
                } else {
                    index[source.id] = sources.count
                    indices.append(sources.count)
                    sources.append(source)
                }
            }
            links.append((game, indices))
        }
        guard connected else { return nil }

        // A game of this round that fed nothing visible still belongs on
        // screen — a round is never partly shown.
        for game in round where index["game-\(game.id)"] == nil {
            sources.append(.game(game))
        }
        return BracketPairing(sources: sources, links: links)
    }
}
