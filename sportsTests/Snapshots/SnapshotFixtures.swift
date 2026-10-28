import Foundation
@testable import StatSide

/// Hand-built data for the component snapshots: one game per sport, a
/// lineup for each, and a fixed "today". Authored rather than decoded
/// from the ESPN fixtures so a baseline never moves because a payload
/// capture was refreshed, and so every URL is nil — a mark or headshot
/// that fetched would race the render and the placeholder disc is the
/// deterministic frame.
///
/// Three states on purpose, one per sport, so the headers cover the
/// shapes they have: football is live with the ball, basketball is
/// final, hockey is pre-game.
enum SnapshotFixtures {
    enum Sport: String, CaseIterable {
        case football, basketball, hockey

        var league: League {
            switch self {
            case .football: .collegeFootball
            case .basketball: .nba
            case .hockey: .nhl
            }
        }
    }

    // MARK: - Teams

    private static func team(_ id: String, _ location: String, _ name: String,
                             _ abbreviation: String, league: League) -> Team {
        Team(id: id, location: location, name: name, abbreviation: abbreviation,
             displayName: "\(location) \(name)", shortDisplayName: name,
             logoURL: nil, conferenceId: nil, league: league)
    }

    static let georgia = team("61", "Georgia", "Bulldogs", "UGA", league: .collegeFootball)
    static let alabama = team("333", "Alabama", "Crimson Tide", "ALA", league: .collegeFootball)
    static let celtics = team("2", "Boston", "Celtics", "BOS", league: .nba)
    static let knicks = team("18", "New York", "Knicks", "NY", league: .nba)
    static let mapleLeafs = team("21", "Toronto", "Maple Leafs", "TOR", league: .nhl)
    static let bruins = team("1", "Boston", "Bruins", "BOS", league: .nhl)

    // MARK: - Days

    /// Noon local on a fixed date, so the day is the same whatever time
    /// zone the simulator runs in.
    static func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        var parts = DateComponents()
        parts.year = year
        parts.month = month
        parts.day = day
        parts.hour = 12
        return Calendar.current.date(from: parts)!
    }

    /// "Today" for each sport's strip: a football Saturday, a January
    /// weeknight, a March Saturday.
    static func today(_ sport: Sport) -> Date {
        switch sport {
        case .football: day(2026, 10, 17)
        case .basketball: day(2027, 1, 20)
        case .hockey: day(2027, 3, 13)
        }
    }

    /// Yesterday through ten days out. Yesterday first, so the strip's
    /// centring scroll on "Today" clamps at the leading edge and the
    /// render doesn't depend on whether it ran.
    static func days(_ sport: Sport) -> [DaySlot] {
        let calendar = Calendar.current
        let base = today(sport)
        return (-1...10).compactMap { calendar.date(byAdding: .day, value: $0, to: base) }
            .map { DaySlot($0, calendar: calendar) }
    }

    // MARK: - Games

    private static func competitor(_ team: Team, score: Int?, record: String, rank: Int? = nil,
                                   isHome: Bool, winner: Bool? = nil) -> Competitor {
        Competitor(team: team, score: score, record: record, rank: rank, isHome: isHome, winner: winner)
    }

    static func game(_ sport: Sport) -> Game {
        switch sport {
        case .football:
            // Live, third quarter, Georgia driving.
            Game(id: "snap-cfb", date: day(2026, 10, 17), name: nil, shortName: "UGA @ ALA", weekNumber: 8,
                 status: .live(displayClock: "5:24", period: 3, detail: nil, phase: .playing,
                               possessionTeamId: georgia.id),
                 home: competitor(alabama, score: 17, record: "6-1", rank: 4, isHome: true),
                 away: competitor(georgia, score: 24, record: "7-0", rank: 1, isHome: false),
                 broadcast: "CBS")
        case .basketball:
            // Final.
            Game(id: "snap-nba", date: day(2027, 1, 20), name: nil, shortName: "BOS @ NY", weekNumber: nil,
                 status: .final(detail: "Final"),
                 home: competitor(knicks, score: 112, record: "28-15", isHome: true, winner: true),
                 away: competitor(celtics, score: 108, record: "30-13", isHome: false, winner: false),
                 broadcast: "TNT")
        case .hockey:
            // Pre-game, a Saturday night face-off.
            Game(id: "snap-nhl", date: faceOff, name: nil, shortName: "TOR @ BOS", weekNumber: nil,
                 status: .pre(detail: nil),
                 home: competitor(bruins, score: nil, record: "38-20-6", isHome: true),
                 away: competitor(mapleLeafs, score: nil, record: "40-19-5", isHome: false),
                 broadcast: "ESPN+")
        }
    }

    /// The same three matchups as finals, for spoiler mode's baselines
    /// (E30): football and hockey are `game(_:)`'s pairs played out,
    /// basketball is already a final. Hockey ends in overtime so the
    /// concealed row exercises `RecordRewind`'s third-field rule: Toronto
    /// 40-19-5 → 39-19-5, Boston's OT loss 38-20-6 → 38-20-5.
    static func finalGame(_ sport: Sport) -> Game {
        switch sport {
        case .football:
            Game(id: "snap-cfb-final", date: day(2026, 10, 17), name: nil, shortName: "UGA @ ALA",
                 weekNumber: 8, status: .final(detail: "Final"),
                 home: competitor(alabama, score: 17, record: "6-2", rank: 4, isHome: true, winner: false),
                 away: competitor(georgia, score: 24, record: "8-0", rank: 1, isHome: false, winner: true),
                 broadcast: "CBS")
        case .basketball:
            game(.basketball)
        case .hockey:
            Game(id: "snap-nhl-final", date: faceOff, name: nil, shortName: "TOR @ BOS", weekNumber: nil,
                 status: .final(detail: "Final/OT"),
                 home: competitor(bruins, score: 2, record: "38-20-6", isHome: true, winner: false),
                 away: competitor(mapleLeafs, score: 3, record: "40-19-5", isHome: false, winner: true),
                 broadcast: "ESPN+")
        }
    }

    /// One concealed game per sport (E30), covering both hidden states:
    /// football is the live game, basketball and hockey the finals.
    static func concealedGame(_ sport: Sport) -> Game {
        sport == .football ? game(.football) : finalGame(sport)
    }

    /// A guard that hides `game`: spoiler mode on, its home team followed.
    static func spoilerGuard(hiding game: Game) -> SpoilerGuard {
        SpoilerGuard(isEnabled: true, followedKeys: [game.home.team.followKey], revealedKeys: [])
    }

    /// 7:00 PM local on the hockey day.
    private static var faceOff: Date {
        var parts = Calendar.current.dateComponents([.year, .month, .day], from: today(.hockey))
        parts.hour = 19
        parts.minute = 0
        return Calendar.current.date(from: parts)!
    }

    // MARK: - Lineups

    private static func person(_ id: Int, _ jersey: String, _ position: String, _ name: String,
                               league: League) -> GameRoster.Person {
        GameRoster.Person(id: String(id), name: name, shortName: GameRoster.Side.shortName(name),
                          jersey: jersey, position: position, positionName: nil, headshotURL: nil,
                          unit: Formation.unit(for: position, league: league))
    }

    private static func side(_ team: Team, kind: GameRoster.LineupKind,
                             _ starters: [(String, String, String)]) -> GameRoster.Side {
        var side = GameRoster.Side(team: team)
        side.starters = starters.enumerated().map { offset, entry in
            person(Int(team.id)! * 1000 + offset, entry.0, entry.1, entry.2, league: team.league)
        }
        side.lineupKind = kind
        return side
    }

    static func roster(_ sport: Sport) -> GameRoster {
        switch sport {
        case .football:
            GameRoster(phase: .live,
                       away: side(georgia, kind: .declared, georgiaStarters),
                       home: side(alabama, kind: .declared, alabamaStarters))
        case .basketball:
            GameRoster(phase: .played,
                       away: side(celtics, kind: .declared, [
                           ("7", "PG", "Jaylen Brown"), ("9", "SG", "Derrick White"),
                           ("0", "SF", "Jayson Tatum"), ("8", "PF", "Kristaps Porzingis"),
                           ("40", "C", "Luke Kornet"),
                       ]),
                       home: side(knicks, kind: .declared, [
                           ("11", "PG", "Jalen Brunson"), ("25", "SG", "Mikal Bridges"),
                           ("3", "SF", "Josh Hart"), ("32", "PF", "Karl-Anthony Towns"),
                           ("4", "C", "Mitchell Robinson"),
                       ]))
        case .hockey:
            GameRoster(phase: .live,
                       away: side(mapleLeafs, kind: .onIce, [
                           ("34", "C", "Auston Matthews"), ("16", "RW", "Mitch Marner"),
                           ("88", "LW", "William Nylander"), ("44", "LD", "Morgan Rielly"),
                           ("22", "RD", "Jake McCabe"), ("60", "G", "Joseph Woll"),
                       ]),
                       home: side(bruins, kind: .onIce, [
                           ("63", "LW", "Brad Marchand"), ("88", "RW", "David Pastrnak"),
                           ("13", "C", "Charlie Coyle"), ("73", "RD", "Charlie McAvoy"),
                           ("25", "LD", "Brandon Carlo"), ("1", "G", "Jeremy Swayman"),
                       ]))
        }
    }

    /// Eleven and eleven, every position one the formation table places.
    private static let georgiaStarters: [(String, String, String)] = [
        ("15", "QB", "Carson Beck"), ("4", "RB", "Nate Frazier"),
        ("1", "WR", "Dominic Lovett"), ("2", "WR", "Colbie Young"), ("11", "WR", "Arian Smith"),
        ("18", "TE", "Oscar Delp"),
        ("74", "LT", "Earnest Greene"), ("66", "LG", "Dylan Fairchild"), ("56", "C", "Jared Wilson"),
        ("51", "RG", "Tate Ratledge"), ("76", "RT", "Xavier Truss"),
        ("95", "DE", "Mykel Williams"), ("88", "DT", "Christen Miller"), ("96", "NT", "Nazir Stackhouse"),
        ("97", "DE", "Warren Brinson"),
        ("3", "LB", "Jalon Walker"), ("6", "LB", "Smael Mondon"), ("5", "OLB", "Chaz Chambliss"),
        ("7", "CB", "Daniel Harris"), ("13", "CB", "Julian Humphrey"),
        ("14", "FS", "Malaki Starks"), ("23", "SS", "Dan Jackson"),
    ]

    private static let alabamaStarters: [(String, String, String)] = [
        ("10", "QB", "Jalen Milroe"), ("20", "RB", "Jam Miller"),
        ("5", "WR", "Germie Bernard"), ("7", "WR", "Ryan Williams"), ("4", "WR", "Kendrick Law"),
        ("12", "TE", "CJ Dippre"),
        ("71", "LT", "Kadyn Proctor"), ("58", "LG", "Tyler Booker"), ("62", "C", "Parker Brailsford"),
        ("51", "RG", "Jaeden Roberts"), ("50", "RT", "Elijah Pritchett"),
        ("17", "DE", "Que Robinson"), ("48", "DT", "Tim Keenan"), ("92", "NT", "Jah-Marien Latham"),
        ("97", "DE", "LT Overton"),
        ("31", "LB", "Deontae Lawson"), ("34", "LB", "Justin Jefferson"), ("8", "OLB", "Jihaad Campbell"),
        ("2", "CB", "Zabien Brown"), ("3", "CB", "Domani Jackson"),
        ("1", "FS", "Keon Sabb"), ("9", "SS", "Malachi Moore"),
    ]

    // MARK: - Stories

    /// Three headlines a league page might lead with. No photo and no
    /// date — the meta line would otherwise be "2h ago" relative to the
    /// run — so the card is the headline over its byline.
    static func stories(_ sport: Sport) -> [NewsStory] {
        let headlines: [(String, String)] = switch sport {
        case .football:
            [("Georgia holds off Alabama in overtime to stay unbeaten", "AP"),
             ("Transfer portal tracker: the quarterbacks on the move", "ESPN"),
             ("Week 9 bowl projections: who's in, who's out", "ESPN")]
        case .basketball:
            [("Knicks waive Bruce Brown, keep James Wiseman ahead of opener", "ESPN"),
             ("Celtics' bench carries a rout of the Nets", "AP"),
             ("NBA preseason buzz: the latest on trades, news and intel", "ESPN")]
        case .hockey:
            [("Maple Leafs edge Bruins in a shootout", "AP"),
             ("Still awaiting trade, Hellebuyck could rejoin Jets when suspension ends", "ESPN"),
             ("Power rankings: the Atlantic is a two-team race", "ESPN")]
        }
        return headlines.enumerated().map { index, pair in
            NewsStory(id: "\(sport.rawValue)-\(index)", kind: .headline, league: sport.league,
                      headline: pair.0, dek: nil, attribution: pair.1, published: nil,
                      gameId: nil, teams: [])
        }
    }

    // MARK: - Team stats

    static let ohioState = team("194", "Ohio State", "Buckeyes", "OSU", league: .collegeFootball)
    static let rangers = team("19", "New York", "Rangers", "NYR", league: .nhl)
    static let lakers = team("13", "Los Angeles", "Lakers", "LAL", league: .nba)

    /// One leader card's table per sport (2026-10-25): a lower-is-better
    /// stat for football, a signed one for basketball and hockey's
    /// three-digit save percentage — the three formats most likely to
    /// crowd the capsule.
    static func teamStatRanking(_ sport: Sport) -> TeamStatRankingDestination {
        let (definitionId, entries): (String, [(Team, Double)]) = switch sport {
        case .football: ("pointsAllowed", [(georgia, 9.4), (ohioState, 11.3), (alabama, 15.0)])
        case .basketball: ("pointDifferential", [(celtics, 12.6), (knicks, 8.1), (lakers, -2.4)])
        case .hockey: ("savePct", [(bruins, 0.925), (rangers, 0.911), (mapleLeafs, 0.904)])
        }
        let league = sport.league
        let definition = league.teamStatDefinitions.first { $0.id == definitionId }!
        let rows = entries.enumerated().map { index, entry in
            TeamStatRanking.Row(rank: index + 1, team: entry.0, value: entry.1,
                                display: definition.format.string(entry.1))
        }
        return TeamStatRankingDestination(ranking: TeamStatRanking(definition: definition, rows: rows),
                                          scopeName: league.shortName,
                                          seasonLabel: league.seasonLabel(2026))
    }

    /// One player leader card's table per sport (2026-10-26): a half-sack
    /// count, a percentage, and hockey's signed plus/minus — no headshots,
    /// so each disc is the placeholder.
    static func playerStatRanking(_ sport: Sport) -> PlayerStatRankingDestination {
        let (definitionId, entries): (String, [(String, String, Team, Double)]) = switch sport {
        case .football: ("sacks", [("Jalon Walker", "LB", georgia, 9.5),
                                   ("Arvell Reese", "LB", ohioState, 8),
                                   ("LT Overton", "DE", alabama, 6.5)])
        case .basketball: ("fieldGoalPct", [("Jalen Brunson", "G", knicks, 54.2),
                                            ("Jayson Tatum", "F", celtics, 49.8),
                                            ("LeBron James", "F", lakers, 48.1)])
        case .hockey: ("plusMinus", [("Charlie McAvoy", "D", bruins, 14),
                                     ("Adam Fox", "D", rangers, 9),
                                     ("Morgan Rielly", "D", mapleLeafs, 7)])
        }
        let league = sport.league
        let definition = league.playerStatDefinitions.first { $0.id == definitionId }!
        let rows = entries.enumerated().map { index, entry in
            PlayerStatRanking.Row(rank: index + 1,
                                  player: LeaguePlayer(athleteId: "\(index)", name: entry.0, headshotURL: nil,
                                                       position: entry.1, team: entry.2, league: league),
                                  value: entry.3, display: definition.format.string(entry.3))
        }
        return PlayerStatRankingDestination(ranking: PlayerStatRanking(definition: definition, rows: rows),
                                            scopeName: league.shortName,
                                            seasonLabel: league.seasonLabel(2026))
    }

    // MARK: - StatSide rating

    static let miami = team("2390", "Miami", "Hurricanes", "MIA", league: .collegeFootball)
    static let notreDame = team("87", "Notre Dame", "Fighting Irish", "ND", league: .collegeFootball)
    static let indiana = team("84", "Indiana", "Hoosiers", "IU", league: .collegeFootball)
    static let ucla = team("26", "UCLA", "Bruins", "UCLA", league: .collegeFootball)

    /// The rating's top five, 2026 through week 9, as the published list
    /// had them on 2026-10-28.
    static var statSideRating: StatSideRatingDestination {
        let rows = [(miami, 7, 0, 98.2, 1, 5), (ohioState, 6, 1, 97.2, 6, 4), (notreDame, 6, 1, 97.2, 8, 1),
                    (indiana, 7, 1, 96.9, 4, 7), (ucla, 7, 0, 96.4, 2, 15)]
            .enumerated().map { index, line in
                StatSideRating.Row(rank: index + 1, team: line.0, wins: line.1, losses: line.2,
                                   score: line.3, resumeRank: line.4, performanceRank: line.5)
            }
        return StatSideRatingDestination(rows: rows, seasonLabel: "2026 · Week 9")
    }

    /// A follow list with nobody in it, so no row draws emphasized.
    static var noFollows: FollowingStore {
        let defaults = UserDefaults(suiteName: "snapshot-no-follows")!
        defaults.removePersistentDomain(forName: "snapshot-no-follows")
        return FollowingStore(defaults: defaults)
    }
}
