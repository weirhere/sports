import Foundation
import Testing
@testable import StatSide

/// `coaches.json`'s decode and lookup, and the copy bundled with the app.
struct CoachStaffTests {
    private let sample = Data("""
    {"version": 1, "updated": "2026-10-03",
     "leagues": {"college-football": {"194": {"source": "x", "staff": [
        {"name": "Arthur Smith", "role": "Offensive coordinator"},
        {"name": "Matt Patricia", "role": "Defensive coordinator"}]}},
       "nfl": {"194": {"staff": [{"name": "Not Ohio State", "role": "Offensive coordinator"}]}}}}
    """.utf8)

    @Test func looksUpByLeagueAndTeamId() throws {
        let file = try JSONDecoder().decode(CoachStaffFile.self, from: sample)
        let staff = file.staff(league: .collegeFootball, teamId: "194")
        #expect(staff.map(\.name) == ["Arthur Smith", "Matt Patricia"])
        // ESPN ids collide across leagues; the league keeps them apart.
        #expect(file.staff(league: .nfl, teamId: "194").map(\.name) == ["Not Ohio State"])
    }

    @Test func anUnknownTeamHasNoStaff() throws {
        let file = try JSONDecoder().decode(CoachStaffFile.self, from: sample)
        #expect(file.staff(league: .nba, teamId: "194").isEmpty)
        #expect(file.staff(league: .collegeFootball, teamId: "1").isEmpty)
    }

    @Test func aFileMissingFieldsStillDecodes() throws {
        let file = try JSONDecoder().decode(CoachStaffFile.self, from: Data("{}".utf8))
        #expect(file.staff(league: .nfl, teamId: "27").isEmpty)
    }

    /// The bundled copy is what a fresh, offline install shows.
    @Test func theBundledCopyDecodesAndHasTheNFL() throws {
        let url = try #require(Bundle.main.url(forResource: "coaches", withExtension: "json"))
        let file = try JSONDecoder().decode(CoachStaffFile.self, from: Data(contentsOf: url))
        #expect(file.updated != nil)
        #expect((file.leagues?["nfl"]?.count ?? 0) >= 30)
    }
}
