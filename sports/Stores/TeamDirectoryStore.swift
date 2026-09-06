import Foundation
import Observation

/// Every conference and its member teams, across every league, fetched once
/// per launch from the standings API (the one source that knows membership)
/// and shared by Teams browse, onboarding, and app-wide search.
///
/// College football's directory is division-complete even though the
/// *slate* is opt-in (E8 scope (b)): browsing to an FCS team's page and
/// searching for one are what scope (a) was, and (b) contains (a). It costs
/// one extra request per launch, never polled.
///
/// The NFL adds a third. Its conferences are the AFC and the NFC, and its
/// standings response carries all 32 teams in one call.
@Observable
final class TeamDirectoryStore {
    private let makeClient: @Sendable (League) -> any ScoresProviding

    private(set) var conferences: [ConferenceTeams] = []
    private(set) var isLoading = false
    private(set) var lastError: String?

    init(makeClient: @escaping @Sendable (League) -> any ScoresProviding = {
        DataProvider.makeClient(league: $0)
    }) {
        self.makeClient = makeClient
    }

    /// Convenience for tests and previews that only care about one backend.
    convenience init(client: any ScoresProviding) {
        self.init(makeClient: { _ in client })
    }

    var allTeams: [Team] {
        conferences.flatMap(\.teams)
    }

    /// Resolve a routing intent to a real team.
    ///
    /// The league is what makes this unambiguous: `allTeams` spans both
    /// leagues and college football is published first, so matching on the
    /// bare id alone handed back UAB for every NFL team whose id a college
    /// program also holds (Andy, 2026-09-06 — searching "Browns" opened
    /// UAB). Every in-app intent carries its league.
    ///
    /// Without one — only a legacy bare `statside://team/{id}` link — a
    /// team the user follows wins over a stranger, since a link they were
    /// sent is far likelier to be about a team of theirs; failing that the
    /// directory's own order decides, which is the old behaviour and the
    /// best a bare id can do.
    func team(matching ref: TeamRef, followedKeys: Set<String> = []) -> Team? {
        Self.team(matching: ref, in: allTeams, followedKeys: followedKeys)
    }

    /// The rule itself, over any list of teams — pure, so it can be tested
    /// without standing up a directory or a stub client.
    nonisolated static func team(matching ref: TeamRef, in teams: [Team],
                                 followedKeys: Set<String> = []) -> Team? {
        let candidates = teams.filter { $0.id == ref.id }
        if let league = ref.league {
            return candidates.first { $0.league == league }
        }
        return candidates.first { followedKeys.contains($0.followKey) } ?? candidates.first
    }

    /// One league's conferences, in the order `load` fetched them.
    func conferences(in league: League) -> [ConferenceTeams] {
        conferences.filter { $0.league == league }
    }

    func teams(in league: League) -> [Team] {
        conferences(in: league).flatMap(\.teams)
    }

    func load() async {
        guard conferences.isEmpty, !isLoading else { return }
        isLoading = true
        defer { isLoading = false }
        // All three at once. Only the college-football FBS half is
        // load-bearing: a directory without it isn't a directory, so its
        // failure is the error. Losing the FCS half costs the FCS rows;
        // losing the NFL half costs the NFL ones.
        let cfb = makeClient(.collegeFootball)
        async let fcs = try? await cfb.conferences(in: .fcs)
        async let nfl = try? await makeClient(.nfl).conferences(in: .fbs)
        do {
            // Published the moment it lands, rather than after the slowest
            // of three: browse and search are usable as soon as the FBS
            // half arrives, and adding a league must never make the
            // college-football half slower to appear.
            conferences = try await cfb.conferences(in: .fbs)
            lastError = nil
        } catch {
            lastError = "Couldn't load teams."
            return
        }
        conferences += (await fcs ?? []) + (await nfl ?? [])
    }
}
