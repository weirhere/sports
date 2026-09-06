import Foundation
import Testing
@testable import StatSide

/// The follow set is read by three processes — the app's stores, the widget
/// extension and the Siri intent — and each had grown its own `dropFirst`.
/// These pin the one parser they now share.
@Suite struct FollowKeyTests {
    @Test func roundTripsThroughItsStoredSpelling() {
        let key = FollowKey(league: .nfl, teamId: "26")
        #expect(key.rawValue == "nfl:26")
        #expect(FollowKey("nfl:26") == key)
        #expect(FollowKey("cfb:130") == FollowKey(league: .collegeFootball, teamId: "130"))
    }

    /// The collision the whole axis exists for: 26 is UCLA and the Seahawks,
    /// and the two keys must not be equal.
    @Test func theSameIdInTwoLeaguesIsTwoKeys() {
        #expect(FollowKey("cfb:26") != FollowKey("nfl:26"))
        #expect(FollowKey("cfb:26")?.teamId == FollowKey("nfl:26")?.teamId)
    }

    /// A bare id predates the league axis and reads as college football —
    /// the same fallback the namespacing migration used, kept so a key that
    /// somehow escaped it still resolves rather than being dropped.
    @Test func aBareIdReadsAsCollegeFootball() {
        #expect(FollowKey("130") == FollowKey(league: .collegeFootball, teamId: "130"))
    }

    @Test func nonsenseDoesNotParse() {
        #expect(FollowKey("") == nil)
        #expect(FollowKey("mls:5") == nil)
        #expect(FollowKey("nfl:") == nil)
        #expect(FollowKey(":26") == nil)
    }

    /// A team id can itself contain a colon in principle; only the first
    /// separator is the league boundary.
    @Test func onlyTheFirstSeparatorSplits() {
        #expect(FollowKey("nfl:a:b")?.teamId == "a:b")
    }

    @Test func teamIdsSliceByLeague() {
        let keys: Set<String> = ["cfb:130", "cfb:61", "nfl:26"]
        #expect(keys.followedTeamIds(in: .collegeFootball) == ["130", "61"])
        #expect(keys.followedTeamIds(in: .nfl) == ["26"])
    }

    /// The politeness property: fan-out asks this first, so a follow set
    /// touching one league never makes the other league's request.
    @Test func onlyTheLeaguesActuallyFollowedAreTouched() {
        #expect(Set<String>(["cfb:130"]).followedLeagues == [.collegeFootball])
        #expect(Set<String>(["nfl:26"]).followedLeagues == [.nfl])
        #expect(Set<String>(["cfb:130", "nfl:26"]).followedLeagues
                == [.collegeFootball, .nfl])
        #expect(Set<String>().followedLeagues.isEmpty)
        // Unparseable keys contribute nothing rather than a phantom league.
        #expect(Set<String>(["mls:5"]).followedLeagues.isEmpty)
    }

    /// Order is `League.allCases`, not set iteration — a fan-out that
    /// varies run to run makes request logs unreadable.
    @Test func leagueOrderIsStable() {
        for _ in 0..<20 {
            #expect(Set<String>(["nfl:26", "cfb:130"]).followedLeagues
                    == [.collegeFootball, .nfl])
        }
    }
}
