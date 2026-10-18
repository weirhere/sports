import Foundation

/// A lineup arranged on its playing surface — rows of players from the
/// line of engagement outward, so the view can put one team's rows above
/// the midline and the other's below it and have the two face each other.
///
/// Football is the hard one and the reason this exists (Andy, 2026-10-18:
/// *"it's hard when during the game the lineup is drastically changing
/// whether offense or defense is on the field"*). The answer is to draw
/// what a snap looks like: one side's offense across the line from the
/// other side's defense, eleven on eleven, and let the card flip which
/// team has the ball. So `make` takes a `unit` in football and arranges
/// only that platoon; a basketball or hockey lineup is one unit and the
/// parameter is ignored.
///
/// Placement is by position abbreviation, read off the team roster where
/// it has one and ESPN's position table otherwise (`ESPNPositions`).
/// Specific sides ("LT", "RCB") go to their side; generic ones ("OT",
/// "CB") alternate; anything the layout can't name is returned in
/// `unplaced` and listed under the field rather than dropped. The
/// arrangement is a picture of who is in, not a scouting report —
/// a tackle drawn on the wrong side is still the right tackle.
nonisolated struct Formation: Sendable, Hashable {
    /// One row of the half. A `line` shares the row's width evenly; `wings`
    /// are the players who line up wide of everyone else — receivers and
    /// tight ends off the ball, cornerbacks — pinned to the two edges with
    /// the middle left open. Nine across one row (three wideouts, a tight
    /// end and five linemen) left every name too small to read (Andy,
    /// 2026-10-18), and splitting the wings out is what a real formation
    /// does anyway: only seven have to be on the line, and the slot and
    /// the tight end are routinely a step off it.
    enum Row: Sendable, Hashable {
        case line([GameRoster.Person])
        case wings(left: [GameRoster.Person], right: [GameRoster.Person])

        var players: [GameRoster.Person] {
            switch self {
            case .line(let players): players
            case .wings(let left, let right): left + right
            }
        }

        var isEmpty: Bool { players.isEmpty }
    }

    /// Row 0 sits on the midline; the last row is deepest in the half.
    let rows: [Row]
    /// Starters with no position the layout knows.
    let unplaced: [GameRoster.Person]

    var isEmpty: Bool { rows.allSatisfy(\.isEmpty) }

    private init(rows: [Row], unplaced: [GameRoster.Person]) {
        self.rows = rows.filter { !$0.isEmpty }
        self.unplaced = unplaced
    }

    static func make(starters: [GameRoster.Person], league: League,
                     unit: GameRoster.Unit? = nil) -> Formation {
        switch league {
        case .collegeFootball, .nfl: football(starters, unit: unit ?? .offense)
        case .nba: basketball(starters)
        case .nhl: hockey(starters)
        }
    }

    /// Football's platoon for a position, nil for the other leagues and
    /// for a position the table doesn't know.
    static func unit(for position: String?, league: League) -> GameRoster.Unit? {
        guard league == .collegeFootball || league == .nfl, let position else { return nil }
        let code = position.uppercased()
        if FootballPositions.offense.contains(code) { return .offense }
        if FootballPositions.defense.contains(code) { return .defense }
        if FootballPositions.specialTeams.contains(code) { return .specialTeams }
        return nil
    }

    // MARK: - Football

    private static func football(_ starters: [GameRoster.Person], unit: GameRoster.Unit) -> Formation {
        typealias P = FootballPositions
        // A starter the table can't place belongs to neither picture, so
        // he's listed under whichever is showing.
        var unplaced = starters.filter { $0.unit == nil }
        let mine = starters.filter { $0.unit == unit }
        switch unit {
        case .offense:
            var receivers: [GameRoster.Person] = [], tightEnds: [GameRoster.Person] = []
            var line: [GameRoster.Person] = [], quarterbacks: [GameRoster.Person] = []
            var backs: [GameRoster.Person] = []
            for person in mine {
                let code = person.position?.uppercased() ?? ""
                if P.receivers.contains(code) { receivers.append(person) }
                else if code == "TE" { tightEnds.append(person) }
                else if P.line.contains(code) { line.append(person) }
                else if code == "QB" { quarterbacks.append(person) }
                else if P.backs.contains(code) { backs.append(person) }
                else { unplaced.append(person) }
            }
            // Wideouts alternate out from the left; tight ends from the
            // right, so a one-TE set puts him beside the right tackle.
            let wide = split(receivers, left: [], right: [], flank: P.receivers, tiesLeft: true)
            let ends = split(tightEnds, left: [], right: [], flank: ["TE"], tiesLeft: false)
            let interior = arrange(line.filter { P.guardsAndCenters.contains($0.position?.uppercased() ?? "") },
                                   left: ["LG"], middle: ["C", "OL"], right: ["RG"], flank: ["G", "OG"])
            let tackles = split(line.filter { !P.guardsAndCenters.contains($0.position?.uppercased() ?? "") },
                                left: ["LT"], right: ["RT"], flank: ["OT", "T"], tiesLeft: true)
            let front = tackles.left + interior + tackles.right
            let flankers = Row.wings(left: wide.left + ends.left, right: ends.right + wide.right)
            return Formation(rows: [.line(front), flankers, .line(quarterbacks), .line(backs)], unplaced: unplaced)
        case .defense:
            var linemen: [GameRoster.Person] = [], linebackers: [GameRoster.Person] = []
            var corners: [GameRoster.Person] = [], safeties: [GameRoster.Person] = []
            for person in mine {
                let code = person.position?.uppercased() ?? ""
                if P.defensiveLine.contains(code) { linemen.append(person) }
                else if P.linebackers.contains(code) { linebackers.append(person) }
                else if P.cornerbacks.contains(code) { corners.append(person) }
                else if P.safeties.contains(code) { safeties.append(person) }
                else { unplaced.append(person) }
            }
            let ends = split(linemen.filter { P.defensiveEnds.contains($0.position?.uppercased() ?? "") },
                             left: ["LDE"], right: ["RDE"], flank: ["DE", "EDGE"], tiesLeft: true)
            let inside = arrange(linemen.filter { !P.defensiveEnds.contains($0.position?.uppercased() ?? "") },
                                 left: ["LDT"], middle: ["NT", "NG", "MG", "UT", "DL"], right: ["RDT"],
                                 flank: ["DT"])
            let front = ends.left + inside + ends.right
            let outside = split(linebackers.filter { P.outsideLinebackers.contains($0.position?.uppercased() ?? "") },
                                left: ["LOLB", "WLB", "LLB"], right: ["ROLB", "SLB", "RLB"],
                                flank: ["OLB"], tiesLeft: true)
            let middleBackers = arrange(linebackers.filter { !P.outsideLinebackers.contains($0.position?.uppercased() ?? "") },
                                        left: ["LILB"], middle: ["MLB"], right: ["RILB"], flank: ["ILB", "LB"])
            let cornerSplit = split(corners, left: ["LCB"], right: ["RCB", "NB"], flank: ["CB", "DB"], tiesLeft: true)
            let backers = outside.left + middleBackers + outside.right
            let deep = arrange(safeties, left: ["FS", "LSF"], middle: [], right: ["SS", "RSF"], flank: ["S"])
            return Formation(rows: [.line(front), .line(backers),
                                    .wings(left: cornerSplit.left, right: cornerSplit.right),
                                    .line(deep)], unplaced: unplaced)
        case .specialTeams:
            return Formation(rows: [.line(mine)], unplaced: unplaced)
        }
    }

    // MARK: - Basketball

    private static func basketball(_ starters: [GameRoster.Person]) -> Formation {
        var guards: [GameRoster.Person] = [], frontcourt: [GameRoster.Person] = []
        var unplaced: [GameRoster.Person] = []
        for person in starters {
            switch person.position?.uppercased() ?? "" {
            case "PG", "SG", "G": guards.append(person)
            case "SF", "PF", "F", "GF", "C", "FC": frontcourt.append(person)
            default: unplaced.append(person)
            }
        }
        // Guards nearest half court, the center between the forwards.
        let backcourt = arrange(guards, left: ["PG"], middle: [], right: ["SG"], flank: ["G"])
        let front = arrange(frontcourt, left: ["SF"], middle: ["C", "FC"], right: ["PF"], flank: ["F", "GF"])
        return Formation(rows: [.line(backcourt), .line(front)], unplaced: unplaced)
    }

    // MARK: - Hockey

    private static func hockey(_ starters: [GameRoster.Person]) -> Formation {
        var forwards: [GameRoster.Person] = [], defense: [GameRoster.Person] = []
        var goalies: [GameRoster.Person] = [], unplaced: [GameRoster.Person] = []
        for person in starters {
            switch person.position?.uppercased() ?? "" {
            case "LW", "C", "RW", "W", "F": forwards.append(person)
            case "LD", "RD", "D": defense.append(person)
            case "G": goalies.append(person)
            default: unplaced.append(person)
            }
        }
        let line = arrange(forwards, left: ["LW"], middle: ["C", "F"], right: ["RW"], flank: ["W"])
        let pairing = arrange(defense, left: ["LD"], middle: [], right: ["RD"], flank: ["D"])
        return Formation(rows: [.line(line), .line(pairing), .line(goalies)], unplaced: unplaced)
    }

    // MARK: - Placement

    /// Sorts people onto a left side, a middle and a right side by
    /// position: `left` and `right` name the positions that belong to a
    /// side (in preference order), `flank` the generic ones that could go
    /// either way — those go to whichever side is shorter, ties to the
    /// left unless told otherwise — and everything else is the middle, in
    /// `middle`'s order with unknowns after.
    private static func split(_ people: [GameRoster.Person], left: [String], right: [String],
                              flank: Set<String>, tiesLeft: Bool)
        -> (left: [GameRoster.Person], right: [GameRoster.Person], middle: [GameRoster.Person]) {
        func code(_ person: GameRoster.Person) -> String { person.position?.uppercased() ?? "" }
        var lefts = people.filter { left.contains(code($0)) }
            .sorted { (left.firstIndex(of: code($0)) ?? 0) < (left.firstIndex(of: code($1)) ?? 0) }
        var rights = people.filter { right.contains(code($0)) }
            .sorted { (right.firstIndex(of: code($0)) ?? 0) < (right.firstIndex(of: code($1)) ?? 0) }
        var middle: [GameRoster.Person] = []
        for person in people where !left.contains(code(person)) && !right.contains(code(person)) {
            if flank.contains(code(person)) {
                let goesLeft = lefts.count < rights.count || (lefts.count == rights.count && tiesLeft)
                // Outward: a second left wideout stands outside the first.
                if goesLeft { lefts.insert(person, at: 0) } else { rights.append(person) }
            } else {
                middle.append(person)
            }
        }
        return (lefts, rights, middle)
    }

    private static func arrange(_ people: [GameRoster.Person], left: [String], middle: [String],
                                right: [String], flank: Set<String>) -> [GameRoster.Person] {
        let parts = split(people, left: left, right: right, flank: flank, tiesLeft: true)
        let ordered = parts.middle.enumerated().sorted { lhs, rhs in
            let l = middle.firstIndex(of: lhs.element.position?.uppercased() ?? "") ?? middle.count
            let r = middle.firstIndex(of: rhs.element.position?.uppercased() ?? "") ?? middle.count
            return l != r ? l < r : lhs.offset < rhs.offset
        }.map(\.element)
        return parts.left + ordered + parts.right
    }
}

/// ESPN's football position abbreviations, by where they line up. Both
/// the team roster's spellings ("OT", "G", "S") and the game-day
/// roster's table (`ESPNPositions`) are covered.
nonisolated enum FootballPositions {
    static let receivers: Set<String> = ["WR", "FL", "SE"]
    static let line: Set<String> = ["LT", "LG", "C", "RG", "RT", "OT", "OG", "OL", "G", "T"]
    static let guardsAndCenters: Set<String> = ["LG", "C", "RG", "OG", "G", "OL"]
    static let backs: Set<String> = ["RB", "FB", "HB", "TB", "LHB", "RHB", "B"]
    static let offense: Set<String> = receivers.union(line).union(backs).union(["TE", "QB"])

    static let defensiveEnds: Set<String> = ["LDE", "RDE", "DE", "EDGE"]
    static let defensiveLine: Set<String> = defensiveEnds.union(["LDT", "RDT", "DT", "NT", "NG", "MG", "UT", "DL"])
    static let outsideLinebackers: Set<String> = ["LOLB", "ROLB", "OLB", "WLB", "SLB", "LLB", "RLB"]
    static let linebackers: Set<String> = outsideLinebackers.union(["LILB", "RILB", "ILB", "MLB", "LB"])
    static let cornerbacks: Set<String> = ["LCB", "RCB", "CB", "NB", "DB"]
    static let safeties: Set<String> = ["FS", "SS", "S", "LSF", "RSF"]
    static let defense: Set<String> = defensiveLine.union(linebackers).union(cornerbacks).union(safeties)

    static let specialTeams: Set<String> = ["PK", "K", "P", "LS", "KR", "PR", "H"]
}
