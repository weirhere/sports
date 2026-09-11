import Foundation

/// One team's current roster: the head coach and the players, in whatever
/// groups the provider ships them.
///
/// **Current only.** ESPN's roster endpoint has no season axis — `season=2019`,
/// `season=2024` and `season=2025` all return HTTP 200, echo the season back in
/// the response, and carry zero athletes (probed live 2026-09-10 on college
/// football, the NFL and the NBA). So there is no `year` here and the Roster tab
/// shows no season chip: a past season's roster isn't something we can be wrong
/// about, it's something we can't ask for.
nonisolated struct TeamRoster: Sendable {
    var coach: RosterCoach?
    var groups: [RosterGroup]

    static let empty = TeamRoster(coach: nil, groups: [])

    /// Nothing to show. A provider with no roster of its own answers with
    /// this, which is what hides the tab rather than failing the page.
    var isEmpty: Bool { coach == nil && groups.allSatisfy(\.players.isEmpty) }
}

/// A titled run of players — ESPN's own grouping, never ours.
///
/// The NFL and college football ship six lowercase codes (offense, defense,
/// specialTeam, injuredReserveOrOut, suspended, practiceSquad); the NHL ships
/// display-ready names ("Centers", "Goalies"); the NBA ships no grouping at
/// all, so its whole roster arrives as one group. Deriving basketball groups
/// from each athlete's position would be inventing a structure the payload
/// doesn't have — the same rule that keeps drives and downs off a basketball
/// game page.
nonisolated struct RosterGroup: Sendable, Identifiable, Hashable {
    /// Display name, already resolved from the provider's code.
    let name: String
    let players: [RosterPlayer]

    var id: String { name }
}

nonisolated struct RosterCoach: Sendable, Hashable {
    let name: String
}

/// One player. Everything but the id and the name is optional, because ESPN
/// omits plenty: no jersey on 5 of 76 NFL players, none on 10 of 18 NBA
/// preseason ones, and no `age` whatsoever on a college football roster
/// (0 of 100 — college keeps a class year instead).
nonisolated struct RosterPlayer: Sendable, Identifiable, Hashable {
    let id: String
    let name: String
    let jersey: String?
    /// Position abbreviation — "QB", "LW", "G".
    let position: String?
    /// The position spoken out loud, for VoiceOver ("Quarterback").
    let positionName: String?
    /// ESPN's own formatting, which already carries the units: `6' 2"`.
    let height: String?
    /// Likewise: `225 lbs`.
    let weight: String?
    let age: Int?
    /// College football's answer to age — "FR", "SO", "JR", "SR".
    let classAbbreviation: String?
    let headshotURL: URL?
    /// "Questionable", "Out". Only the NFL ships these, and only for the
    /// handful of players carrying one.
    let injuryStatus: String?

    /// What a 36pt row disc actually asks for. ESPN links the 600×436 press
    /// photo, and a 100-player college roster rendered off those is ~20 MB of
    /// images for one tab — see `URL.headshotThumbnail`. Falls back to the
    /// full image for any URL the resizer doesn't answer for.
    var thumbnailURL: URL? { headshotURL?.headshotThumbnail ?? headshotURL }

    /// The value under this league's metric column, or nil where the player
    /// is missing it.
    func metricValue(for league: League) -> String? {
        switch league.rosterMetric {
        case .age: age.map(String.init)
        case .classYear: classAbbreviation
        }
    }
}

/// The one right-aligned column a roster row carries, FotMob's "Age" slot.
///
/// Per league for the same reason `standingsColumns` is: the leagues ship
/// different facts. College football publishes no age at all and a class year
/// instead, so an AGE caption there would promise a number that never arrives.
nonisolated enum RosterMetric: Sendable {
    case age
    case classYear

    var caption: String {
        switch self {
        case .age: "AGE"
        case .classYear: "CLASS"
        }
    }

    /// What VoiceOver calls it inside the row's sentence.
    func spoken(_ value: String) -> String {
        switch self {
        case .age: "age \(value)"
        case .classYear: RosterMetric.classNames[value] ?? value
        }
    }

    /// Base width at `.subheadline`, scaled by the row's `@ScaledMetric` —
    /// `StandingsColumn.width`'s convention.
    var width: CGFloat { 34 }

    /// ESPN abbreviates the class; VoiceOver shouldn't have to spell it.
    private static let classNames = [
        "FR": "freshman", "SO": "sophomore", "JR": "junior", "SR": "senior",
    ]
}

nonisolated extension League {
    var rosterMetric: RosterMetric {
        switch self {
        case .collegeFootball: .classYear
        case .nfl, .nba, .nhl: .age
        }
    }
}
