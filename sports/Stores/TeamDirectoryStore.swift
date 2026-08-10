import Foundation
import Observation

/// The FBS universe — every conference and its member teams, fetched once
/// per launch from the standings API (the one source that knows membership)
/// and shared by Teams browse, onboarding, and app-wide search.
@Observable
final class TeamDirectoryStore {
    private let client: any ScoresProviding

    private(set) var conferences: [ConferenceTeams] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    init(client: any ScoresProviding = DataProvider.makeClient()) {
        self.client = client
    }

    var allTeams: [Team] {
        conferences.flatMap(\.teams)
    }

    func load() async {
        guard conferences.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        do {
            conferences = try await client.fbsConferences()
            lastError = nil
        } catch {
            lastError = "Couldn't load teams."
        }
    }
}
