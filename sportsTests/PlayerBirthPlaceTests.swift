import Foundation
import Testing
@testable import StatSide

private final class BirthPlaceFixtureToken {}

private func athlete(_ name: String) throws -> ProfileAthleteDTO {
    let url = try #require(
        Bundle(for: BirthPlaceFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try #require(try JSONDecoder().decode(AthleteProfileResponseDTO.self,
                                                 from: Data(contentsOf: url)).athlete)
}

private func bornRow(_ identity: PlayerIdentity) -> String? {
    identity.profileRows.first { $0.label == PlayerIdentity.birthPlaceLabel }?.value
}

/// The Born row (COR-150, 2026-11-07). ESPN's athlete payload has carried
/// `displayBirthPlace` all along; the app just never read it. Labelled
/// "Born", the coach page's word, because it's a birthplace.
@Suite struct PlayerBirthPlace {

    @Test func theAthletePayloadFillsBornForBothCapturedLeagues() throws {
        let lebron = AthleteProfileClient.filled(
            PlayerIdentity(athleteId: "1966", name: "LeBron James", league: .nba, teamName: nil),
            from: try athlete("nba-athlete-profile"))
        #expect(lebron.birthPlace == "Akron, OH")
        #expect(bornRow(lebron) == "Akron, OH")

        let maye = AthleteProfileClient.filled(
            PlayerIdentity(athleteId: "4431452", name: "Drake Maye", league: .nfl, teamName: nil),
            from: try athlete("nfl-athlete-profile"))
        #expect(bornRow(maye) == "Huntersville, NC")
    }

    @Test func noBirthPlaceMeansNoRow() {
        let identity = PlayerIdentity(athleteId: "1", name: "A Player",
                                      league: .nhl, teamName: nil)
        #expect(bornRow(identity) == nil)
        var blank = identity
        blank.birthPlace = ""
        #expect(bornRow(blank) == nil)
    }

    /// Door first, like every other field.
    @Test func theDoorsBirthPlaceIsNotOverwritten() throws {
        var door = PlayerIdentity(athleteId: "1966", name: "LeBron James",
                                  league: .nba, teamName: nil)
        door.birthPlace = "Door, OH"
        let filled = AthleteProfileClient.filled(door, from: try athlete("nba-athlete-profile"))
        #expect(filled.birthPlace == "Door, OH")
    }

    /// Right after the league's own row: Age for a pro, Class for college
    /// football, where the row shows too.
    @Test func theRowSitsAfterAgeOrClass() {
        var pro = PlayerIdentity(athleteId: "1", name: "A Pro", league: .nfl, teamName: nil)
        pro.height = "6' 4\""
        pro.age = 24
        pro.birthPlace = "Huntersville, NC"
        pro.positionName = "Quarterback"
        pro.college = .init(id: "153", name: "North Carolina")
        pro.jersey = "10"
        #expect(pro.profileRows.map(\.label)
                == ["Height", "Age", "Born", "Position", "College", "Jersey"])

        var college = PlayerIdentity(athleteId: "2", name: "A Player",
                                     league: .collegeFootball, teamName: nil)
        college.classAbbreviation = "JR"
        college.birthPlace = "Athens, GA"
        college.positionName = "Quarterback"
        #expect(college.profileRows.map(\.label) == ["Class", "Born", "Position"])
    }
}
