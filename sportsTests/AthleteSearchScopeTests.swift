import Foundation
import Testing
@testable import StatSide

private func athlete(_ id: String, _ name: String, _ league: League,
                     team: String?) -> PlayerIdentity {
    PlayerIdentity(athleteId: id, name: name, league: league,
                   teamName: team, teamLogoURL: nil)
}

// "mcdav", live on 2026-11-06, in ESPN's order (the NASCAR-less part of it).
private let connor = athlete("3895074", "Connor McDavid", .nhl, team: "Edmonton Oilers")
private let noah = athlete("5106261", "Noah McDavid", .mensCollegeBasketball,
                           team: "Arkansas State Red Wolves")
private let clem = athlete("5150541", "Clem McDavid", .collegeFootball, team: "Harvard Crimson")
private let tim = athlete("5240187", "Tim McDavid", .mensCollegeBasketball,
                          team: "Chadron State Eagles")
private let jamari = athlete("4281043", "Jamari McDavid", .womensCollegeBasketball,
                             team: "Wofford Terriers")
private let jamariAgain = athlete("4902079", "Jamari Mcdavid", .womensCollegeBasketball,
                                  team: "Wofford Terriers")

private let directory: [League: Set<String>] = [
    .collegeFootball: ["Harvard Crimson", "Tarleton State Texans"],
    .mensCollegeBasketball: ["Arkansas State Red Wolves"],
    .womensCollegeBasketball: ["Wofford Terriers"],
]

struct AthleteSearchScopeTests {
    @Test func divisionTwoBasketballSchoolIsDropped() {
        let kept = AthleteSearchStore.inScope([noah, tim], collegeTeams: directory)
        #expect(kept.map(\.athleteId) == [noah.athleteId])
    }

    @Test func footballFilterStillHolds() {
        let marsHill = athlete("1", "Ryan McDavid", .collegeFootball, team: "Mars Hill Lions")
        let kept = AthleteSearchStore.inScope([clem, marsHill], collegeTeams: directory)
        #expect(kept.map(\.athleteId) == [clem.athleteId])
    }

    @Test func proLeaguesAreNeverFiltered() {
        let kept = AthleteSearchStore.inScope([connor], collegeTeams: [:])
        #expect(kept.count == 1)
    }

    @Test func collegePlayerWithNoTeamIsDropped() {
        let noTeam = athlete("2", "Someone", .mensCollegeBasketball, team: nil)
        #expect(AthleteSearchStore.inScope([noTeam], collegeTeams: directory).isEmpty)
    }

    /// A league whose standings request failed has no teams to judge by,
    /// so its players stay rather than vanish.
    @Test func unloadedCollegeLeagueLetsPlayersThrough() {
        let kept = AthleteSearchStore.inScope([tim], collegeTeams: [.collegeFootball: ["Harvard Crimson"]])
        #expect(kept.map(\.athleteId) == [tim.athleteId])
    }

    @Test func samePersonUnderTwoIdsKeepsTheFirst() {
        let kept = AthleteSearchStore.inScope([jamari, jamariAgain], collegeTeams: directory)
        #expect(kept.map(\.athleteId) == [jamari.athleteId])
    }

    @Test func sameNameInDifferentLeaguesBothStay() {
        let nflSmith = athlete("10", "Jalen Smith", .nfl, team: "A")
        let nbaSmith = athlete("11", "Jalen Smith", .nba, team: "B")
        #expect(AthleteSearchStore.inScope([nflSmith, nbaSmith], collegeTeams: [:]).count == 2)
    }

    @Test func orderIsKept() {
        let kept = AthleteSearchStore.inScope([connor, noah, clem, tim, jamari, jamariAgain],
                                              collegeTeams: directory)
        #expect(kept.map(\.name) == ["Connor McDavid", "Noah McDavid", "Clem McDavid", "Jamari McDavid"])
    }
}
