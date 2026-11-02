import Foundation
import Testing
@testable import StatSide

private final class CollegeFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: CollegeFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private func athlete(_ name: String) throws -> ProfileAthleteDTO {
    try #require(try JSONDecoder().decode(AthleteProfileResponseDTO.self,
                                          from: fixture(name)).athlete)
}

private func team(_ id: String, _ location: String, league: League) -> Team {
    var value = Team(id: id, location: location, name: nil, abbreviation: nil,
                     displayName: nil, shortDisplayName: nil,
                     logoURL: nil, conferenceId: nil)
    value.league = league
    return value
}

private func collegeRow(_ identity: PlayerIdentity) -> String? {
    identity.profileRows.first { $0.label == PlayerIdentity.collegeLabel }?.value
}

/// Where a pro played college (2026-11-02). Fixtures trimmed from live
/// captures that day: a Toronto roster with one college player and one
/// without per group, Drake Maye's athlete payload, and LeBron's, which has
/// no `college` key at all.
@Suite struct PlayerCollege {

    /// The roster door carries it for free — every NFL and NBA row has one,
    /// and an NHL roster has it on the players who went.
    @Test func aRosterRowCarriesItsCollegeAndAbsenceIsNil() throws {
        let dto = try JSONDecoder().decode(RosterResponseDTO.self,
                                           from: fixture("nhl-roster-college"))
        let players = ESPNMapper.roster(from: dto).groups.flatMap(\.players)
        let blueger = try #require(players.first { $0.name == "Teddy Blueger" })
        #expect(blueger.college == PlayerIdentity.College(id: "2364", name: "Minnesota State"))
        let groulx = try #require(players.first { $0.name == "Bo Groulx" })
        #expect(groulx.college == nil)
    }

    /// The full name wins over the short one, and the id survives, since it
    /// is what the row links by.
    @Test func theAthletePayloadFillsCollegeForADoorThatLackedIt() throws {
        let door = PlayerIdentity(athleteId: "4431452", name: "Drake Maye",
                                  league: .nfl, teamName: "New England Patriots")
        let filled = AthleteProfileClient.filled(door, from: try athlete("nfl-athlete-profile"))
        #expect(filled.college == PlayerIdentity.College(id: "153", name: "North Carolina"))
        #expect(collegeRow(filled) == "North Carolina")
    }

    @Test func noCollegeKeyMeansNoRow() throws {
        let door = PlayerIdentity(athleteId: "1966", name: "LeBron James",
                                  league: .nba, teamName: "Los Angeles Lakers")
        let filled = AthleteProfileClient.filled(door, from: try athlete("nba-athlete-profile"))
        #expect(filled.college == nil)
        #expect(collegeRow(filled) == nil)
    }

    /// Door first, like every other field: what the roster said stands.
    @Test func theDoorsCollegeIsNotOverwritten() throws {
        var door = PlayerIdentity(athleteId: "4431452", name: "Drake Maye",
                                  league: .nfl, teamName: nil)
        door.college = .init(id: "1", name: "Door U")
        let filled = AthleteProfileClient.filled(door, from: try athlete("nfl-athlete-profile"))
        #expect(filled.college?.name == "Door U")
    }

    /// A college player's school is the team badge over the card already.
    @Test func collegeFootballPlayersGetNoCollegeRow() {
        var identity = PlayerIdentity(athleteId: "1", name: "A Player",
                                      league: .collegeFootball, teamName: "Georgia")
        identity.college = .init(id: "61", name: "Georgia")
        #expect(collegeRow(identity) == nil)
    }

    /// Position, then College, then Jersey: who they are, where they came
    /// from, then the number.
    @Test func theRowSitsBetweenPositionAndJersey() {
        let player = RosterPlayer(id: "3024916", name: "Teddy Blueger", jersey: "53",
                                  position: "C", positionName: "Center",
                                  height: nil, weight: nil, age: 31,
                                  classAbbreviation: nil, headshotURL: nil,
                                  injuryStatus: nil,
                                  college: .init(id: "2364", name: "Minnesota State"))
        let identity = PlayerIdentity(player: player,
                                      team: team("21", "Toronto", league: .nhl),
                                      league: .nhl)
        #expect(identity.profileRows.map(\.label) == ["Age", "Position", "College", "Jersey"])
    }

    @Test func aBlankCollegeNameIsNoCollege() {
        let blank = CollegeRefDTO(id: nil, name: " ", shortName: "")
        #expect(PlayerIdentity.College(dto: blank) == nil)
        let shortOnly = CollegeRefDTO(id: nil, name: nil, shortName: "UMass")
        #expect(PlayerIdentity.College(dto: shortOnly)?.name == "UMass")
    }
}
