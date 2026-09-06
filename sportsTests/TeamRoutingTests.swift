import Foundation
import Testing
@testable import StatSide

/// Search and deep-link routing across the two leagues' colliding id spaces.
///
/// The bug this suite exists for (Andy, 2026-09-06): searching "Browns" and
/// tapping the result opened UAB's page. ESPN gives both teams id 5, the
/// intent carried only the id, and the directory publishes college football
/// first — so the first match always won and it was never the NFL's.
private func team(_ id: String, _ location: String, league: League) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: nil,
         displayName: location, shortDisplayName: location,
         logoURL: nil, conferenceId: nil, league: league)
}

/// The real collision, from ESPN's own team lists: 5 is UAB and the Browns.
private let uab = team("5", "UAB", league: .collegeFootball)
private let browns = team("5", "Cleveland", league: .nfl)
/// The other one the codebase already knew about: 26 is UCLA and Seattle.
private let ucla = team("26", "UCLA", league: .collegeFootball)
private let seahawks = team("26", "Seattle", league: .nfl)

/// The directory's own publication order: college football first, which is
/// what made the bare-id match always answer with a college team.
private let directory = [uab, ucla, browns, seahawks]

private func resolve(_ ref: TeamRef, in teams: [Team] = directory,
                     followedKeys: Set<String> = []) -> Team? {
    TeamDirectoryStore.team(matching: ref, in: teams, followedKeys: followedKeys)
}

@Suite struct TeamRoutingTests {
    /// The reported bug, both directions.
    @Test func leagueDecidesWhichTeamAnIdMeans() {
        #expect(resolve(TeamRef(browns))?.location == "Cleveland")
        #expect(resolve(TeamRef(uab))?.location == "UAB")
        #expect(resolve(TeamRef(seahawks))?.location == "Seattle")
        #expect(resolve(TeamRef(ucla))?.location == "UCLA")
    }

    /// Every in-app intent is built from a whole team, so it always carries
    /// the league — this is the constructor search uses.
    @Test func aTeamRefKeepsItsTeamsLeague() {
        #expect(TeamRef(browns).league == .nfl)
        #expect(TeamRef(uab).league == .collegeFootball)
    }

    /// A bare `statside://team/5` can't be disambiguated, so a followed team
    /// wins: a link you were sent is likelier to be about a team of yours.
    @Test func aBareIdPrefersAFollowedTeam() {
        let bare = TeamRef(id: "5")
        #expect(resolve(bare, followedKeys: [browns.followKey])?.location == "Cleveland")
        #expect(resolve(bare, followedKeys: [uab.followKey])?.location == "UAB")
        // Following neither falls back to the directory's own order.
        #expect(resolve(bare)?.location == "UAB")
    }

    @Test func anIdNobodyCarriesResolvesToNothing() {
        #expect(resolve(TeamRef(id: "9999", league: .nfl)) == nil)
    }

    /// An id one league has and the other doesn't still needs its league
    /// honored — never a silent fall-through to the other league's team.
    @Test func aQualifiedRefNeverFallsThroughToTheOtherLeague() {
        #expect(resolve(TeamRef(id: "5", league: .nfl))?.league == .nfl)
        #expect(resolve(TeamRef(id: "5", league: .nfl), in: [uab]) == nil)
    }

    // MARK: - Deep links

    @Test func aLeagueQualifiedLinkParses() {
        #expect(DeepLink(url: URL(string: "statside://team/nfl/5")!) == .team("5", .nfl))
        #expect(DeepLink(url: URL(string: "statside://team/cfb/5")!) == .team("5", .collegeFootball))
    }

    /// The legacy form still parses — it just carries no league.
    @Test func aBareLinkStillParses() {
        #expect(DeepLink(url: URL(string: "statside://team/5")!) == .team("5", nil))
    }

    /// An unknown first segment is a team id, not a league — so a team
    /// whose id ever looked like a word can't be swallowed by the parser.
    @Test func anUnknownSegmentIsTreatedAsTheId() {
        #expect(DeepLink(url: URL(string: "statside://team/mls/5")!) == .team("mls", nil))
    }

    @MainActor
    @Test func theRouterCarriesTheLinksLeagueThrough() {
        let router = Router()
        router.open(.team("5", .nfl))
        #expect(router.pendingTeam == TeamRef(id: "5", league: .nfl))
    }
}
