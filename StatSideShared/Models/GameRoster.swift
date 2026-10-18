import Foundation

/// Who is in a game — the Roster tab's model (E29, 2026-10-18).
///
/// One shape across three states of a game. Before kickoff it answers
/// "who is planning to play": the projected starters over the rest of the
/// roster. Live it answers "who is playing": the starters (or, in hockey,
/// the skaters on the ice right now) over the bench. After the final it
/// answers "who played": the starters over everyone else who got on the
/// field. The lists are the same three in every state — `starters`,
/// `others`, `inactive` — and the tab names them for the state it is in.
///
/// Assembled, not fetched: `GameRoster.make` joins up to four sources per
/// side (the team's own roster, the game-day roster, a depth chart and
/// the summary's box score and injuries), each of which may be missing,
/// and the result is whatever the sources support. A side with nothing
/// behind it is empty, which is what hides the tab's cards rather than
/// failing the page.
nonisolated struct GameRoster: Sendable {
    enum Phase: Sendable, Hashable {
        case upcoming, live, played
    }

    /// Football's platoons. A starter belongs to one; the formation draws
    /// one at a time, the other team's opposite unit facing it.
    enum Unit: Sendable, Hashable, CaseIterable {
        case offense, defense, specialTeams
    }

    /// Where a side's `starters` came from, which is what the card calls
    /// them: a depth chart or a pre-game declaration is a projection, a
    /// game-day roster or box score is the lineup, hockey's `onIce` is
    /// the five or six skaters out there now.
    enum LineupKind: Sendable, Hashable {
        case none, declared, projected, onIce
    }

    struct Person: Identifiable, Hashable, Sendable {
        /// ESPN's athlete id, the key every source shares.
        let id: String
        /// The full name where any source had it; ESPN's short form
        /// ("E. Greene III") where only the game-day roster did.
        var name: String
        /// What fits under a formation disc: the game-day roster's own
        /// short form, which already initials a team's two Joneses.
        var shortName: String
        var jersey: String?
        var position: String?
        var positionName: String?
        var headshotURL: URL?
        var unit: Unit? = nil
        /// Why a player sits where he does: "Coach's decision", a scratch,
        /// or nothing.
        var note: String? = nil

        /// The 36pt disc's image — `RosterPlayer.thumbnailURL`'s reason.
        var thumbnailURL: URL? { headshotURL?.headshotThumbnail ?? headshotURL }
    }

    struct Side: Sendable {
        let team: Team
        var coach: RosterCoach? = nil
        var starters: [Person] = []
        var lineupKind: LineupKind = .none
        /// The rest: the roster before kickoff, the bench during, and
        /// everyone else who played after.
        var others: [Person] = []
        /// Declared inactive, did not play, or scratched.
        var inactive: [Person] = []
        var injuries: [GameInjury] = []

        var isEmpty: Bool {
            coach == nil && starters.isEmpty && others.isEmpty
                && inactive.isEmpty && injuries.isEmpty
        }
    }

    let phase: Phase
    let away: Side
    let home: Side

    var isEmpty: Bool { away.isEmpty && home.isEmpty }
}

/// One entry of the core API's game-day roster, mapped — see
/// `CompetitorRosterDTO` for what each league fills in.
nonisolated struct LineupEntry: Sendable, Hashable {
    let athleteId: String
    let shortName: String?
    let jersey: String?
    let position: ESPNPositions.Position?
    let isStarter: Bool
    let didNotPlay: Bool
    let isScratched: Bool
    /// "Coach's decision", "Scratched" — the payload's reason, cased for
    /// a row.
    let note: String?
    /// Whether the entry links a stat line, which in college football is
    /// the only record of who played.
    let recordedStat: Bool
}

/// One rung of a depth chart: an athlete's rank at a position.
nonisolated struct DepthSlot: Sendable, Hashable {
    /// "PG", "LW" — the chart's key, uppercased.
    let position: String
    let positionName: String?
    let rank: Int
    let athleteId: String
}

/// One name on the game-day injury list.
nonisolated struct GameInjury: Identifiable, Hashable, Sendable {
    let id: String
    let name: String
    let jersey: String?
    let position: String?
    let headshotURL: URL?
    /// "Questionable", "Out", "Injured Reserve", "Day-To-Day".
    let status: String
    /// "Neck", "Hamstring", "Illness" — nil where ESPN said nothing.
    let detail: String?
    /// ESPN's bare `yyyy-MM-dd`, kept as sent.
    let returnDate: String?

    var thumbnailURL: URL? { headshotURL?.headshotThumbnail ?? headshotURL }

    /// "Oct 25" out of `returnDate`, or nil when it doesn't parse.
    func returnDateText(calendar: Calendar = .current) -> String? {
        guard let returnDate else { return nil }
        let parts = returnDate.split(separator: "-").compactMap { Int($0) }
        guard parts.count == 3 else { return nil }
        var components = DateComponents()
        components.year = parts[0]
        components.month = parts[1]
        components.day = parts[2]
        guard let date = calendar.date(from: components) else { return nil }
        return date.formatted(.dateTime.month(.abbreviated).day())
    }
}

nonisolated struct TeamInjuries: Hashable, Sendable {
    let teamId: String
    let injuries: [GameInjury]
}

// MARK: - Assembly

extension GameRoster {
    /// Everything one side's lists can be built from. Every source is
    /// optional; the assembly uses what arrived.
    struct SideInput: Sendable {
        let team: Team
        /// The team's own current roster — names, photos, positions and
        /// the head coach. Skipped for past seasons, whose rosters ESPN
        /// can't serve.
        var roster: TeamRoster? = nil
        /// The core API's game-day roster, when the league publishes one.
        var lineup: [LineupEntry] = []
        /// The NBA's and NHL's depth chart, pre-game only.
        var depthChart: [DepthSlot] = []
        /// The summary's box score for this side.
        var boxScore: BoxScore? = nil
        var injuries: [GameInjury] = []
        /// Hockey's skaters in play right now.
        var onIce: [String] = []
    }

    static func make(phase: Phase, league: League, away: SideInput, home: SideInput) -> GameRoster {
        GameRoster(phase: phase,
                   away: Side.make(away, phase: phase, league: league),
                   home: Side.make(home, phase: phase, league: league))
    }
}

extension GameRoster.Side {
    /// Roster groups whose players aren't candidates to play: ESPN's own
    /// names for them, as `ESPNMapper.groupName` renders them.
    private static let nonPlayingGroups: Set<String> = [
        "Injured reserve", "Suspended", "Practice squad",
    ]

    static func make(_ input: GameRoster.SideInput, phase: GameRoster.Phase,
                     league: League) -> GameRoster.Side {
        typealias Person = GameRoster.Person

        // 1. A directory of everyone any source named, keyed by athlete id.
        // The team roster is the richest (full name, photo, height); the box
        // score fills in anyone it missed — a practice-squad elevation, or
        // everyone, on a past-season game with no roster to ask.
        var directory: [String: Person] = [:]
        var rosterOrder: [String] = []
        for group in input.roster?.groups ?? [] {
            let plays = !Self.nonPlayingGroups.contains(group.name)
            for player in group.players {
                directory[player.id] = Person(
                    id: player.id, name: player.name,
                    shortName: Self.shortName(player.name),
                    jersey: player.jersey, position: player.position,
                    positionName: player.positionName,
                    headshotURL: player.headshotURL,
                    unit: Formation.unit(for: player.position, league: league))
                if plays { rosterOrder.append(player.id) }
            }
        }
        var boxPlayers: [BoxScore.Player] = []
        var seenBox = Set<String>()
        for category in input.boxScore?.categories ?? [] {
            for player in category.players {
                guard let id = player.athleteId, !seenBox.contains(id) else { continue }
                seenBox.insert(id)
                boxPlayers.append(player)
                if directory[id] == nil {
                    directory[id] = Person(
                        id: id, name: player.name, shortName: Self.shortName(player.name),
                        jersey: player.jersey, position: player.position,
                        positionName: player.positionName, headshotURL: player.headshotURL,
                        unit: Formation.unit(for: player.position, league: league))
                }
            }
        }

        /// The person a game-day entry names. The directory's facts win
        /// where it has them — the team roster's "OLB" over the core API's
        /// generic "LB" — and the entry's own fill the gaps.
        func person(_ entry: LineupEntry) -> Person {
            let short = entry.shortName.flatMap { $0.isEmpty ? nil : $0 }
            var person = directory[entry.athleteId] ?? Person(
                id: entry.athleteId,
                name: short ?? entry.jersey.map { "No. \($0)" } ?? "Unknown",
                shortName: short ?? entry.jersey.map { "#\($0)" } ?? "—",
                jersey: nil, position: nil, positionName: nil, headshotURL: nil)
            if let short { person.shortName = short }
            if person.jersey == nil { person.jersey = entry.jersey }
            if person.position == nil, let position = entry.position {
                person.position = position.abbreviation
                person.positionName = position.name
            }
            person.unit = Formation.unit(for: person.position, league: league)
            person.note = entry.note
            return person
        }

        func boxPerson(_ player: BoxScore.Player) -> Person? {
            guard let id = player.athleteId, var person = directory[id] else { return nil }
            if player.didNotPlay { person.note = player.didNotPlayReason }
            return person
        }

        var side = GameRoster.Side(team: input.team, coach: input.roster?.coach,
                                   injuries: input.injuries)
        let injured = Set(input.injuries.map(\.id))

        if !input.lineup.isEmpty {
            // The game-day roster is the record. Which of the non-starters
            // "played" depends on whether the league says who didn't: the
            // NFL, NBA and NHL flag inactives, so everyone else dressed;
            // college football flags nobody, so the stat line is the only
            // evidence a player got on the field.
            let declaresInactives = input.lineup.contains { $0.didNotPlay || $0.isScratched }
            var starters: [Person] = [], out: [Person] = [], rest: [Person] = []
            for entry in input.lineup {
                if entry.isStarter {
                    starters.append(person(entry))
                } else if entry.didNotPlay || entry.isScratched {
                    out.append(person(entry))
                } else if phase == .upcoming || declaresInactives || entry.recordedStat {
                    rest.append(person(entry))
                }
            }
            side.starters = starters
            side.inactive = Self.sortedByJersey(out)
            side.others = Self.sortedByJersey(rest.filter { !injured.contains($0.id) })
            side.lineupKind = starters.isEmpty ? .none : (phase == .upcoming ? .projected : .declared)
        } else if phase != .upcoming, !boxPlayers.isEmpty {
            // No game-day roster, but a box score: its own flags are the
            // lineup (basketball), or it is simply the list of who played.
            let starters = boxPlayers.filter { $0.isStarter == true }.compactMap(boxPerson)
            side.starters = starters
            side.inactive = Self.sortedByJersey(boxPlayers.filter(\.didNotPlay).compactMap(boxPerson))
            side.others = Self.sortedByJersey(
                boxPlayers.filter { !$0.didNotPlay && $0.isStarter != true }
                    .compactMap(boxPerson)
                    .filter { !injured.contains($0.id) })
            side.lineupKind = starters.isEmpty ? .none : .declared
        } else {
            // Before kickoff with nothing game-specific yet: the team's
            // roster, with the depth chart's first unit on top where the
            // league has one. The chart's slot is the position shown — "PG"
            // says more about where a player stands than the roster's "G".
            var starters: [Person] = []
            var placed = Set<String>()
            for slot in input.depthChart where slot.rank == 1 && !placed.contains(slot.athleteId) {
                guard var person = directory[slot.athleteId] else { continue }
                placed.insert(slot.athleteId)
                person.position = slot.position
                person.positionName = slot.positionName ?? person.positionName
                person.unit = Formation.unit(for: slot.position, league: league)
                starters.append(person)
            }
            side.starters = starters
            side.others = rosterOrder
                .filter { !placed.contains($0) && !injured.contains($0) }
                .compactMap { directory[$0] }
            side.lineupKind = starters.isEmpty ? .none : .projected
        }

        // Hockey, live: the skaters and goalie on the ice are the lineup
        // for as long as they're out there, whatever the depth chart said.
        if phase == .live {
            let onIce = input.onIce.compactMap { directory[$0] }
            if !onIce.isEmpty {
                let ids = Set(onIce.map(\.id))
                side.others = Self.sortedByJersey((side.starters + side.others).filter { !ids.contains($0.id) })
                side.starters = onIce
                side.lineupKind = .onIce
            }
        }

        // A name in one list is in no other.
        let starterIds = Set(side.starters.map(\.id))
        side.others.removeAll { starterIds.contains($0.id) }
        let inactiveIds = Set(side.inactive.map(\.id))
        side.others.removeAll { inactiveIds.contains($0.id) }
        return side
    }

    /// "Mahomes" out of "Patrick Mahomes"; the last word that isn't a
    /// suffix, so a formation disc never reads "III".
    static func shortName(_ name: String) -> String {
        let suffixes: Set<String> = ["Jr.", "Sr.", "II", "III", "IV", "V"]
        let words = name.split(separator: " ").map(String.init).filter { !suffixes.contains($0) }
        return words.last ?? name
    }

    /// Jersey order, numberless last, otherwise stable — `TeamRoster`'s
    /// rule for the same reason: the number is how a bench is scanned.
    static func sortedByJersey(_ people: [GameRoster.Person]) -> [GameRoster.Person] {
        people.enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.jersey.flatMap(Int.init)
                let right = rhs.element.jersey.flatMap(Int.init)
                if left != right {
                    guard let left else { return false }
                    guard let right else { return true }
                    return left < right
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
