import Foundation

/// How the game page's Starters section draws its lineups: on the painted
/// field, or as the two-column list cards the rest of the Roster tab is
/// made of (Andy, 2026-10-18 — "some users might not like this
/// visualization and just want to see a card with a list of all the
/// players"). One preference for every league, persisted in
/// `UIStateStore.startersLayout`; the control that sets it lives on the
/// section itself, where you are looking when you decide.
enum StartersLayout: String, CaseIterable, Identifiable {
    case field, list

    var id: Self { self }

    var label: String {
        switch self {
        case .field: "Field"
        case .list: "List"
        }
    }
}
