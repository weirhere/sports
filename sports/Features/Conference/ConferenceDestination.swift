import Foundation

/// The value the navigation stacks push to reach a ConferencePage. Identity
/// only — the page fetches its own standings, like TeamPage fetches its
/// schedule. Only known conferences get one (no page for "Other").
struct ConferenceDestination: Hashable {
    let conferenceId: Int
    let name: String
}
