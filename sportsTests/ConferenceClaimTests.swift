import Foundation
import Testing
@testable import StatSide

private func team(_ id: String, conference: Int?) -> Team {
    Team(id: id, location: "Team \(id)", name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil,
         conferenceId: conference)
}

/// The rule that decides whether a team page may show its conference. It
/// has been wrong twice — once stripping every Sun Belt page, once for a
/// reason (FCS/FBS id collisions) that E8 proved never existed — so it now
/// lives outside the view with the cases that broke it written down.
@Suite struct ConferenceClaimTests {
    /// SEC and Big Sky, both rostered; plus one team ESPN lists under a
    /// conference whose id nothing else in the directory shares.
    private static let directory = [
        team("georgia", conference: 8),
        team("tennessee", conference: 8),
        team("montana", conference: 20),
        team("tennessee-state", conference: 179),
    ]

    @Test func aKnownTeamsClaimStands() {
        #expect(ConferenceClaim.resolve(claimed: 8, teamId: "georgia",
                                        directory: Self.directory) == 8)
    }

    /// The E8 win: an FCS team is no longer an unknown team, so it keeps
    /// its own conference instead of degrading to none. Tennessee State
    /// really is in ESPN's Ohio Valley roster (probed 2026-09-03).
    @Test func aKnownFCSTeamKeepsItsConference() {
        #expect(ConferenceClaim.resolve(claimed: 179, teamId: "tennessee-state",
                                        directory: Self.directory) == 179)
    }

    /// The Sun Belt regression's shape, whose live instance is now SWAC:
    /// zero standings entries means no roster, and no roster can't
    /// disprove anything. Stripping this claim is what broke every Sun
    /// Belt page on 2026-08-29.
    @Test func anUnknownTeamKeepsAClaimNoRosterCanDisprove() {
        #expect(ConferenceClaim.resolve(claimed: 31, teamId: "alcorn-state",
                                        directory: Self.directory) == 31)
    }

    /// The defense that survives: a team in neither division claiming a
    /// conference the directory has a roster for. That roster excludes it,
    /// which is actual disproof.
    @Test func anUnknownTeamLosesADisprovableClaim() {
        #expect(ConferenceClaim.resolve(claimed: 8, teamId: "some-d2-school",
                                        directory: Self.directory) == nil)
        #expect(ConferenceClaim.resolve(claimed: 20, teamId: "some-d2-school",
                                        directory: Self.directory) == nil)
    }

    /// Before the directory loads there is nothing to check against, and a
    /// page that blanked its conference for the first second would flicker.
    @Test func anEmptyDirectoryNeverVetoes() {
        #expect(ConferenceClaim.resolve(claimed: 8, teamId: "anyone",
                                        directory: []) == 8)
        #expect(ConferenceClaim.resolve(claimed: 31, teamId: "anyone",
                                        directory: []) == 31)
    }

    @Test func noClaimResolvesToNothing() {
        #expect(ConferenceClaim.resolve(claimed: nil, teamId: "georgia",
                                        directory: Self.directory) == nil)
        #expect(ConferenceClaim.resolve(claimed: nil, teamId: "anyone",
                                        directory: []) == nil)
    }

    /// The premise the old comment claimed to defend against, asserted as
    /// false so nobody reinstates the reasoning: no FCS id is also an FBS
    /// id, so a "collision" between the two tables cannot happen.
    @Test func theDivisionsIdsCannotCollide() {
        let fbs = Set(Conference.orderedIds(in: .fbs))
        let fcs = Set(Conference.orderedIds(in: .fcs))
        #expect(fbs.isDisjoint(with: fcs))
    }
}
