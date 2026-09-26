import Testing
@testable import StatSide

/// A visitor in a conference section wears its own conference; a member
/// wears nothing (2026-09-26).
@Suite struct GuestTagTests {
    @Test func anNFCVisitorIsTaggedInTheAFCsSection() {
        // Falcons (NFC South, 11) in the AFC's section.
        #expect(Conference.guestTag(for: .nfl(11), in: .nfl(8)) == "NFC")
        // Steelers (AFC North, 12) belong: no tag.
        #expect(Conference.guestTag(for: .nfl(12), in: .nfl(8)) == nil)
    }

    @Test func theWinterLeaguesTagWithTheirShortConferenceName() {
        #expect(Conference.guestTag(for: .nba(4), in: .nba(5)) == "West")
        #expect(Conference.guestTag(for: .nhl(32), in: .nhl(8)) == "East")
        #expect(Conference.guestTag(for: .nhl(33), in: .nhl(7)) == nil)
    }

    @Test func aCollegeVisitorWearsItsConference() {
        #expect(Conference.guestTag(for: .cfb(20), in: .cfb(8)) == "Big Sky")
        #expect(Conference.guestTag(for: .cfb(5), in: .cfb(8)) == "Big Ten")
        #expect(Conference.guestTag(for: .cfb(8), in: .cfb(8)) == nil)
    }

    @Test func sectionsThatClaimBothSidesTagNobody() {
        // The league, FBS and FCS aren't conferences a visitor could be
        // outside of in the sense the tag answers.
        #expect(Conference.guestTag(for: .nfl(11), in: .nfl(9)) == nil)
        #expect(Conference.guestTag(for: .cfb(20), in: Conference.divisionRoot(.fbs)) == nil)
    }

    @Test func aTeamWeCannotPlaceGetsNoTag() {
        #expect(Conference.guestTag(for: nil, in: .cfb(8)) == nil)
        #expect(Conference.guestTag(for: .cfb(424_242), in: .cfb(8)) == nil)
    }
}
