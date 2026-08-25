import Foundation

/// The value the navigation stacks push to reach a ConferencePage. Identity
/// only — the page fetches its own standings, like TeamPage fetches its
/// schedule. Only known conferences get one (no page for "Other").
struct ConferenceDestination: Hashable {
    let conferenceId: Int
    let name: String
    /// A team to anchor in the standings — set by entry points with a team
    /// in hand (TeamPage's hero conference line). Defaulted so every other
    /// push stays anchor-free.
    var highlightTeamId: String? = nil
}
