import Foundation

/// How the game page's Starters section draws its lineups: on the painted
/// field, or as the two-column list cards the rest of the Roster tab is
/// made of (Andy, 2026-10-18 — "some users might not like this
/// visualization and just want to see a card with a list of all the
/// players"). One preference for every league, persisted in
/// `UIStateStore.startersLayout`; the control that sets it lives on the
/// section itself, where you are looking when you decide. The case is
/// `field` whatever the sport, the way the file is `FormationField`; the
/// chip says what the sport calls it (Andy, 2026-10-18 — "on basketball,
/// the field control should be court and hockey should be rink").
enum StartersLayout: String, CaseIterable, Identifiable {
    case field, list

    var id: Self { self }

    func label(for league: League) -> String {
        switch self {
        case .field: league.surfaceName
        case .list: "List"
        }
    }
}

extension League {
    /// What the sport calls the place its starters are drawn on.
    var surfaceName: String {
        switch self {
        case .collegeFootball, .nfl: "Field"
        case .nba: "Court"
        case .nhl: "Rink"
        }
    }
}
