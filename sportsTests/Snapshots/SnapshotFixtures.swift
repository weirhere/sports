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
}
