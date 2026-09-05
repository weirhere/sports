import Foundation
import Testing
@testable import StatSide

/// E8's registry item (scope (b), Andy 2026-09-01). The load-bearing half
/// is not that FCS works — it's that nothing FBS moved: the app's default
/// slate stays FBS-shaped, so ordering, tiering, and the standings cut
/// line all have to come out of this change unchanged.
@Suite struct FCSRegistryTests {
    /// Read live from `standings?group=81` on 2026-09-01: 14 conferences,
    /// 116 teams.
    private static let fcsIds = [20, 48, 32, 22, 24, 21, 25, 179, 27, 28, 29, 30, 31, 177]

    @Test func everyFCSConferenceHasARealName() {
        for id in Self.fcsIds {
            #expect(Conference.name(for: id, in: .collegeFootball) != "Other", "id \(id) fell through to Other")
        }
        #expect(Conference.name(for: 179, in: .collegeFootball) == "Ohio Valley")
        // Not "Independents" — id 18 already owns that, and a browse list
        // showing both would read as a duplicate.
        #expect(Conference.name(for: 32, in: .collegeFootball) == "FCS Independents")
        #expect(Conference.name(for: 18, in: .collegeFootball) == "Independents")
    }

    @Test func unknownIdsStillDegradeToOther() {
        #expect(Conference.name(for: 999, in: .collegeFootball) == "Other")
        #expect(Conference.name(for: nil, in: .collegeFootball) == "Other")
        #expect(Conference.tier(for: 999, in: .collegeFootball) == .other)
        #expect(Conference.division(for: 999, in: .collegeFootball) == nil)
    }

    @Test func divisionsAreDisjointAndComplete() {
        for id in Self.fcsIds { #expect(Conference.division(for: id, in: .collegeFootball) == .fcs, "id \(id)") }
        for id in Conference.orderedIds { #expect(Conference.division(for: id, in: .collegeFootball) == .fbs, "id \(id)") }
        #expect(Conference.Division.fbs.groupId == 80)
        #expect(Conference.Division.fcs.groupId == 81)
        #expect(Conference.fbsGroupId == 80)
    }

    /// United Athletic ships no `ncaa_conf` mark under any plausible slug
    /// (probed 2026-09-01). A nil beats a URL that 404s.
    @Test func missingLogoIsNilNeverABrokenURL() {
        #expect(Conference.logoURL(for: 177, in: .collegeFootball) == nil)
        #expect(Conference.logoURL(for: 20, in: .collegeFootball)?.absoluteString
            == "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/big_sky.png")
        #expect(Conference.logoURL(for: 179, in: .collegeFootball)?.absoluteString.hasSuffix("/ovc.png") == true)
    }

    @Test func everyOtherFCSConferenceHasALogo() {
        for id in Self.fcsIds where id != 177 {
            #expect(Conference.logoURL(for: id, in: .collegeFootball) != nil, "id \(id) lost its mark")
        }
    }

    // MARK: - Nothing FBS moved

    @Test func fbsOrderingIsUnchanged() {
        #expect(Conference.orderedIds == [1, 4, 5, 8, 151, 12, 15, 17, 9, 37, 18])
        #expect(Conference.orderedIds(in: .fbs) == Conference.orderedIds)
    }

    @Test func fbsTiersAreUnchanged() {
        #expect(Conference.tier(for: 8, in: .collegeFootball) == .power4)
        #expect(Conference.tier(for: 17, in: .collegeFootball) == .group5)
        #expect(Conference.tier(for: 18, in: .collegeFootball) == .independent)
    }

    @Test func fcsConferencesTierBelowIndependentsButAboveUnknown() {
        #expect(Conference.tier(for: 20, in: .collegeFootball) == .fcs)
        #expect(Conference.Tier.independent < Conference.Tier.fcs)
        #expect(Conference.Tier.fcs < Conference.Tier.other)
    }

    @Test func fcsOrderIsAlphabetical() {
        let names = Conference.orderedIds(in: .fcs).map { Conference.name(for: $0, in: .collegeFootball) }
        #expect(names == names.sorted())
        #expect(names.count == 14)
    }

    /// The trap the merged name table sets: `titleGameIsTopTwo` guarded on
    /// "do we know this id", which FCS ids now satisfy. FCS settles its
    /// title in a 24-team playoff and holds no championship games, so the
    /// cut line must never claim top-two about one.
    @Test func theStandingsCutLineStaysFBSOnly() {
        for id in Self.fcsIds {
            #expect(!Conference.titleGameIsTopTwo(id: id, year: 2026, in: .collegeFootball), "id \(id)")
        }
        #expect(Conference.titleGameIsTopTwo(id: 8, year: 2026, in: .collegeFootball))
        #expect(Conference.titleGameIsTopTwo(id: 37, year: 2026, in: .collegeFootball))
        #expect(!Conference.titleGameIsTopTwo(id: 37, year: 2025, in: .collegeFootball))
        #expect(!Conference.titleGameIsTopTwo(id: 18, year: 2026, in: .collegeFootball))
    }

    /// CFBD asks every endpoint for `classification=fbs`, so no FCS name
    /// can reach the map — and none was added to it.
    @Test func cfbdParityStaysFBSOnly() {
        #expect(Conference.id(forCFBDName: "Big Sky") == nil)
        #expect(Conference.id(forCFBDName: "SEC") == 8)
    }
}
