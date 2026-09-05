import Foundation
import Observation

/// Every conference and its member teams — both divisions — fetched once
/// per launch from the standings API (the one source that knows membership)
/// and shared by Teams browse, onboarding, and app-wide search.
///
/// The directory is division-complete even though the *slate* is opt-in
/// (E8 scope (b)): browsing to an FCS team's page and searching for one
/// are what scope (a) was, and (b) contains (a). It costs one extra
/// request per launch, never polled.
@Observable
final class TeamDirectoryStore {
    private let client: any ScoresProviding

    private(set) var conferences: [ConferenceTeams] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    // College football only for now — the NFL directory joins browse and
    // search in M4, where the two leagues need their own headings anyway.
    init(client: any ScoresProviding = DataProvider.makeClient(league: .collegeFootball)) {
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
            // Both divisions at once, FBS first. An FCS failure costs the
            // FCS half of browse; an FBS failure is the error, because a
            // directory without the FBS teams isn't a directory.
            async let fcs = try? await client.conferences(in: .fcs)
            let fbs = try await client.conferences(in: .fbs)
            conferences = fbs + (await fcs ?? [])
            lastError = nil
        } catch {
            lastError = "Couldn't load teams."
        }
    }
}
