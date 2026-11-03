import Foundation
import Testing
@testable import StatSide

private func file(_ json: String) throws -> ProAlumniFile {
    try JSONDecoder().decode(ProAlumniFile.self, from: Data(json.utf8))
}

private func team(_ id: String, league: League) -> Team {
    var value = Team(id: id, location: "Somewhere", name: nil, abbreviation: nil,
                     displayName: nil, shortDisplayName: nil,
                     logoURL: nil, conferenceId: nil)
    value.league = league
    return value
}

/// Rows in `scripts/build-pros.py`'s shape, taken from its 2026-11-02 run:
/// North Carolina (153) with an NFL quarterback and an NBA guard, then
/// hand-broken rows the decode must drop.
private let unc = """
{"updated":"2026-11-02","version":1,"colleges":{
"153":[
 {"athleteId":"4431452","headshot":"https://a.espncdn.com/i/headshots/nfl/players/full/4431452.png","jersey":"10","league":"nfl","name":"Drake Maye","position":"QB","positionName":"Quarterback","teamId":"17"},
 {"athleteId":"4395651","headshot":"https://a.espncdn.com/i/headshots/nba/players/full/4395651.png","jersey":"3","league":"nba","name":"Coby White","position":"G","positionName":"Guard","teamId":"30"},
 {"athleteId":"","league":"nfl","name":"No Id"},
 {"athleteId":"9","league":"xfl","name":"Wrong Sport"},
 {"athleteId":"10","league":"nfl"},
 7
]}}
"""

/// The Pros tab's data (2026-11-02).
@Suite struct ProAlumni {

    @Test func aSchoolsRowsDecodeAndMalformedOnesDrop() throws {
        let rows = try file(unc).alumni(collegeId: "153")
        #expect(rows.map(\.name) == ["Drake Maye", "Coby White"])
        let maye = try #require(rows.first)
        #expect(maye.league == .nfl)
        #expect(maye.teamId == "17")
        #expect(maye.headshotURL?.absoluteString
            == "https://a.espncdn.com/i/headshots/nfl/players/full/4431452.png")
    }

    @Test func aSchoolWithNoProsIsEmpty() throws {
        #expect(try file(unc).alumni(collegeId: "61").isEmpty)
    }

    /// A pro team's id would collide with a school's (the Patriots are 17,
    /// and so is a college), so only a college page asks.
    @Test func onlyACollegeFootballTeamHasAlumni() throws {
        let store = ProAlumniStore(file: try file(unc))
        #expect(store.alumni(of: team("153", league: .collegeFootball)).count == 2)
        #expect(store.alumni(of: team("153", league: .nfl)).isEmpty)
    }

    /// The row pushes a player page with what the file knew; the page's
    /// athlete fetch fills in the rest.
    @Test func anAlumnusOpensThePlayerPage() throws {
        let maye = try #require(try file(unc).alumni(collegeId: "153").first)
        let identity = maye.identity(team: team("17", league: .nfl))
        #expect(identity.id == "nfl-4431452")
        #expect(identity.positionName == "Quarterback")
        #expect(identity.team?.id == "17")
        #expect(identity.height == nil)
    }

    @Test func theNewerFileWinsAndADatedFileBeatsAnUndatedOne() throws {
        let old = try file(#"{"updated":"2026-10-27","colleges":{}}"#)
        let new = try file(#"{"updated":"2026-11-02","colleges":{}}"#)
        let undated = try file(#"{"colleges":{}}"#)
        #expect(ProAlumniStore.newer(old, new)?.updated == "2026-11-02")
        #expect(ProAlumniStore.newer(new, old)?.updated == "2026-11-02")
        #expect(ProAlumniStore.newer(undated, old)?.updated == "2026-10-27")
        #expect(ProAlumniStore.newer(nil, old)?.updated == "2026-10-27")
    }

    /// The bundled copy, the one a fresh install falls back on, decodes and
    /// knows UNC's quarterback.
    @Test func theBundledFileDecodes() throws {
        let url = try #require(Bundle.main.url(forResource: "pros", withExtension: "json"))
        let bundled = try JSONDecoder().decode(ProAlumniFile.self, from: Data(contentsOf: url))
        #expect(bundled.alumni(collegeId: "153").contains { $0.name == "Drake Maye" })
    }
}
