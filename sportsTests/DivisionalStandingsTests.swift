import Foundation
import Testing
@testable import StatSide

/// ESPN nests a divisional conference's teams one level deeper — the
/// conference carries no entries of its own and hangs its divisions in
/// `children`. Nothing read that until now, which cost the app two real
/// bugs and one whole conference.
@Suite struct DivisionalStandingsTests {
    private func response(_ json: String) throws -> StandingsResponseDTO {
        try JSONDecoder().decode(StandingsResponseDTO.self, from: Data(json.utf8))
    }

    private func entry(_ id: String, _ location: String,
                       conf: String, overall: String) -> String {
        """
        {"team": {"id": "\(id)", "location": "\(location)"},
         "stats": [{"type": "vsconf", "summary": "\(conf)"},
                   {"type": "total", "summary": "\(overall)"}]}
        """
    }

    /// A conference that ships zero entries and two division children —
    /// the Sun Belt's shape to this day, and the 2019 AAC's.
    private var divisionalJSON: String {
        """
        {"children": [
          {"id": "37", "name": "Sun Belt Conference", "shortName": "Sun Belt",
           "standings": {"entries": []},
           "children": [
             {"id": "167", "name": "Sun Belt - East",
              "standings": {"entries": [
                \(entry("2026", "Marshall", conf: "1-0", overall: "2-1")),
                \(entry("2032", "App State", conf: "0-1", overall: "1-2"))]}},
             {"id": "168", "name": "Sun Belt - West",
              "standings": {"entries": [
                \(entry("2229", "Louisiana", conf: "1-0", overall: "3-0"))]}}]}]}
        """
    }

    /// The browse roster folds the divisions back together: membership has
    /// no order to lose, and one 14-team Sun Belt is what a user looks for.
    ///
    /// This is the bug that hid the whole conference from browse, search
    /// and onboarding (BACKLOG E7) — `guard !teams.isEmpty` dropped it,
    /// because all its teams were one level down.
    @Test func browseFoldsDivisionsIntoTheirConference() throws {
        let conferences = ESPNMapper.conferences(from: try response(divisionalJSON))

        #expect(conferences.count == 1)
        let sunBelt = try #require(conferences.first)
        #expect(sunBelt.id == 37)
        #expect(sunBelt.name == "Sun Belt")
        #expect(sunBelt.teams.count == 3)
        #expect(sunBelt.teams.allSatisfy { $0.conferenceId == 37 })
    }

    /// Standings take the opposite view: each division keeps its own table,
    /// because its order encodes tiebreakers and a merged ranking would be
    /// invented out of records.
    @Test func standingsKeepEachDivisionsTable() throws {
        let standings = ESPNMapper.conferenceStandings(from: try response(divisionalJSON))

        #expect(standings.map(\.id) == [167, 168])
        #expect(standings.allSatisfy { $0.parentId == 37 })
        #expect(standings.first?.entries.count == 2)
    }

    /// A page asking for the conference finds its divisions.
    @Test func aConferenceClaimsItsDivisions() throws {
        let standings = ESPNMapper.conferenceStandings(from: try response(divisionalJSON))
        let sunBelt = ConferenceID.cfb(37)

        #expect(standings.allSatisfy { $0.belongs(to: sunBelt) })
        #expect(!standings.contains { $0.belongs(to: .cfb(8)) })
        // A different league's id 37 is not this conference.
        #expect(!standings.contains { $0.belongs(to: .nfl(37)) })
    }

    /// …and can render one table instead of "Standings TBA", which is what
    /// a divisional season used to show.
    @Test func divisionsMergeIntoOneTableForTheConferencePage() throws {
        let standings = ESPNMapper.conferenceStandings(from: try response(divisionalJSON))
        let merged = try #require(standings.merged(as: 37, name: "Sun Belt",
                                                   league: .collegeFootball))

        #expect(merged.entries.count == 3)
        #expect(merged.entries.map(\.team.location) == ["Marshall", "App State", "Louisiana"])
        #expect(merged.id == 37)
    }

    /// A conference that ships its own entries is untouched — the common
    /// case must not change shape.
    @Test func aFlatConferenceIsUnchanged() throws {
        let flat = """
        {"children": [
          {"id": "8", "name": "Southeastern Conference", "shortName": "SEC",
           "standings": {"entries": [\(entry("61", "Georgia", conf: "5-0", overall: "7-0"))]}}]}
        """
        let standings = ESPNMapper.conferenceStandings(from: try response(flat))
        #expect(standings.map(\.id) == [8])
        #expect(standings.first?.parentId == nil)
        #expect(standings.first?.name == "SEC")
    }

    /// The tables hub names conferences rather than tabling them, so it
    /// folds the divisions back into one row — the fold ConferencePage
    /// does on demand, applied to the list.
    @Test func theHubFoldsDivisionsIntoOneConferenceRow() throws {
        let standings = ESPNMapper.conferenceStandings(from: try response(divisionalJSON))
        let folded = standings.foldingDivisions()

        #expect(folded.map(\.id) == [37])
        #expect(folded.first?.name == "Sun Belt")
        #expect(folded.first?.entries.count == 3)
    }

    /// And the folded row claims no leader: its first entry leads one
    /// division, and the merge invents no order across them.
    @Test func aFoldedRowHasNoLeader() throws {
        let standings = ESPNMapper.conferenceStandings(from: try response(divisionalJSON))
        let folded = try #require(standings.foldingDivisions().first)

        #expect(folded.spansDivisions)
        #expect(folded.leader == nil)
        // The division tables themselves still lead with their own top team.
        #expect(standings.first?.leader?.team.location == "Marshall")
    }

    /// A conference that ships its own table is not a division and passes
    /// through the fold untouched — leader teaser and all.
    @Test func theFoldLeavesFlatConferencesAlone() throws {
        let flat = """
        {"children": [
          {"id": "8", "name": "Southeastern Conference", "shortName": "SEC",
           "standings": {"entries": [\(entry("61", "Georgia", conf: "5-0", overall: "7-0"))]}}]}
        """
        let folded = ESPNMapper.conferenceStandings(from: try response(flat)).foldingDivisions()

        #expect(folded.map(\.id) == [8])
        #expect(folded.first?.spansDivisions == false)
        #expect(folded.first?.leader?.team.location == "Georgia")
    }

    /// The fold restores the tier order the mapper sorts by: an unknown
    /// division id sorts last, but the Sun Belt is a Group of Five
    /// conference and belongs above Independents.
    @Test func theFoldRestoresTierOrder() throws {
        let mixed = """
        {"children": [
          {"id": "18", "name": "FBS Independents", "shortName": "Independents",
           "standings": {"entries": [\(entry("87", "Notre Dame", conf: "0-0", overall: "3-0"))]}},
          {"id": "37", "name": "Sun Belt Conference", "shortName": "Sun Belt",
           "standings": {"entries": []},
           "children": [
             {"id": "167", "name": "Sun Belt - East",
              "standings": {"entries": [\(entry("2026", "Marshall", conf: "1-0", overall: "2-1"))]}}]}]}
        """
        let standings = ESPNMapper.conferenceStandings(from: try response(mixed))

        #expect(standings.map(\.id) == [18, 167])
        #expect(standings.foldingDivisions().map(\.id) == [37, 18])
    }

    /// The tables hub hands the fold both college-football divisions at
    /// once (Andy, 2026-09-06: FCS lives inside College Football's
    /// accordion, not beside it), and the tier rule is what keeps them
    /// apart — FBS conferences first, the 14 FCS ones below, no header
    /// saying so. The two arrive on separate requests; only the list is
    /// merged.
    @Test func theFoldSortsFCSBelowFBSInOneList() throws {
        let fbs = """
        {"children": [
          {"id": "37", "name": "Sun Belt Conference", "shortName": "Sun Belt",
           "standings": {"entries": [\(entry("2026", "Marshall", conf: "1-0", overall: "2-1"))]}},
          {"id": "8", "name": "Southeastern Conference", "shortName": "SEC",
           "standings": {"entries": [\(entry("61", "Georgia", conf: "5-0", overall: "7-0"))]}}]}
        """
        let fcs = """
        {"children": [
          {"id": "20", "name": "Big Sky Conference", "shortName": "Big Sky",
           "standings": {"entries": [\(entry("13", "Montana", conf: "2-0", overall: "4-0"))]}}]}
        """
        // FCS first, since the two fetches race and either can land first —
        // the fold, not the arrival order, is what sorts them.
        let union = ESPNMapper.conferenceStandings(from: try response(fcs))
            + ESPNMapper.conferenceStandings(from: try response(fbs))
        #expect(union.map(\.id) == [20, 8, 37])

        // Power 4, then Group of 5, then FCS — the `.fcs` rung sits below
        // `.independent`, so the divisions never interleave.
        #expect(union.foldingDivisions().map(\.id) == [8, 37, 20])
    }

    /// An empty conference with no children still yields an empty table, so
    /// the page can say "Standings TBA" rather than erroring.
    @Test func anEmptyConferenceStillYieldsATable() throws {
        let empty = """
        {"children": [
          {"id": "8", "name": "Southeastern Conference", "shortName": "SEC",
           "standings": {"entries": []}}]}
        """
        let standings = ESPNMapper.conferenceStandings(from: try response(empty))
        #expect(standings.count == 1)
        #expect(standings.first?.entries.isEmpty == true)
    }
}

@Suite struct StandingsRecordLabelTests {
    /// The in-group column is the conference record in both leagues.
    ///
    /// It was captioned "DIV" for the NFL until 2026-09-05, on the belief
    /// that ESPN shipped only a division record there. It ships both, and
    /// the mapper reads `vsconf`.
    @Test func theInGroupColumnNamesWhatItHolds() {
        for league in [League.collegeFootball, .nfl] {
            let inGroup = league.standingsColumns.first { $0.field == .inGroupRecord }
            #expect(inGroup?.caption == "CONF")
            #expect(inGroup?.spoken == "in conference")
        }
        // The NHL ships no conference record at all, so it keeps no
        // column that would sit permanently empty.
        #expect(!League.nhl.standingsColumns.contains { $0.field == .inGroupRecord })
    }

    /// The NFL's `vsconf` reaches the same column college football's does,
    /// and the division record beside it — spelled `divisionrecord`, which
    /// is not what the retired fallback asked for — stays out of it.
    @Test func theNFLConferenceRecordFillsTheInGroupColumn() throws {
        let json = """
        {"children": [
          {"id": "8", "name": "American Football Conference",
           "standings": {"entries": [
             {"team": {"id": "2", "location": "Buffalo"},
              "stats": [{"type": "vsconf", "summary": "2-0"},
                        {"type": "divisionrecord", "summary": "0-0"},
                        {"type": "winpercent", "value": 1.0},
                        {"type": "total", "summary": "3-0"}]}]}}]}
        """
        let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: Data(json.utf8))
        let standings = ESPNMapper.conferenceStandings(from: dto, league: .nfl)
        let buffalo = try #require(standings.first?.entries.first)

        #expect(buffalo.conferenceRecord == "2-0")
        #expect(buffalo.overallRecord == "3-0")
        #expect(buffalo.winPercent == 1.0)
        #expect(standings.first?.name == "AFC")
    }
}
