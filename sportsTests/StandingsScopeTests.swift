import Foundation
import Testing
@testable import StatSide

/// The NFL standings page tables the same 32 teams three ways — whole
/// league, conference, division (Andy, 2026-09-06). Which scopes a page
/// offers is read off the league's own hierarchy, and only the divisional
/// one costs a request.
@Suite struct StandingsScopeTests {

    // MARK: - Which scopes a page offers

    @Test func theLeaguePageOffersEveryScope() {
        #expect(StandingsScope.scopes(for: .nfl(9)) == [.league, .conference, .division])
        #expect(StandingsScope.default(for: .nfl(9)) == .league)
    }

    /// A conference page offers its own level and the one under it — there
    /// is no "league" view of a page that isn't the league.
    @Test func aConferencePageOffersItselfAndItsDivisions() {
        #expect(StandingsScope.scopes(for: .nfl(8)) == [.conference, .division])
        #expect(StandingsScope.scopes(for: .nfl(7)) == [.conference, .division])
        #expect(StandingsScope.default(for: .nfl(8)) == .conference)
    }

    /// Nothing nests under a division, and nothing nests under a college
    /// conference at all — both hide the control. A division page still
    /// opens on the divisional tables, since the shipped response stops
    /// one level above it and would leave the page with nothing to draw.
    @Test func pagesWithNothingBeneathThemOfferNoScopes() {
        #expect(StandingsScope.scopes(for: .nfl(4)).isEmpty)
        #expect(StandingsScope.default(for: .nfl(4)) == .division)
        #expect(StandingsScope.scopes(for: .cfb(8)).isEmpty)
        #expect(StandingsScope.default(for: .cfb(8)) == .conference)
        // An id no registry knows offers nothing either.
        #expect(StandingsScope.scopes(for: .nfl(999)).isEmpty)
    }

    // MARK: - What a team page offers

    /// A team page scopes *outward*: every group the team is in, widest
    /// first, each still a table with the team's own row in it (Andy,
    /// 2026-09-07).
    @Test func aTeamPageOffersEveryLevelItBelongsTo() {
        // Cleveland's own group is AFC North.
        #expect(StandingsScope.scopes(forTeamIn: .nfl(12))
            == [.league, .conference, .division])
        // It opens where the tab has always opened: the conference table.
        #expect(StandingsScope.default(forTeamIn: .nfl(12)) == .conference)
    }

    /// College football nests nothing under a league, so a team there has
    /// exactly one table and no choice to offer.
    @Test func aCollegeTeamPageOffersNoScopes() {
        #expect(StandingsScope.scopes(forTeamIn: .cfb(8)).isEmpty)
        #expect(StandingsScope.scopes(forTeamIn: .nfl(999)).isEmpty)
    }

    /// The chip's ink says "you are looking at fewer teams than this page
    /// opened with" — so scoping out to the league sits as quiet as the
    /// default, and only the division wears the fill.
    @Test func onlyANarrowerScopeReadsAsNarrowed() {
        let base = StandingsScope.default(forTeamIn: .nfl(12))
        #expect(StandingsScope.division.isNarrower(than: base))
        #expect(!StandingsScope.league.isNarrower(than: base))
        #expect(!base.isNarrower(than: base))
        // The conference page's own rule is unchanged: its default is the
        // widest view it has, so everything under it is narrowed.
        #expect(StandingsScope.division.isNarrower(than: .conference))
        #expect(StandingsScope.conference.isNarrower(than: .league))
    }

    // MARK: - Reading a level=3 response

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

    /// ESPN's `level=3` shape: the conferences keep their own 16-team
    /// tables *and* hang their divisions underneath. Both depths carry
    /// entries, which is exactly the case `standingsGroups` collapses.
    private var levelThreeJSON: String {
        """
        {"children": [
          {"id": "8", "name": "American Football Conference",
           "standings": {"entries": [
             \(entry("2", "Buffalo", conf: "2-0", overall: "3-0")),
             \(entry("4", "Cincinnati", conf: "1-1", overall: "1-2"))]},
           "children": [
             {"id": "4", "name": "AFC East",
              "standings": {"entries": [\(entry("2", "Buffalo", conf: "2-0", overall: "3-0"))]}},
             {"id": "12", "name": "AFC North",
              "standings": {"entries": [\(entry("4", "Cincinnati", conf: "1-1", overall: "1-2"))]}}]},
          {"id": "7", "name": "National Football Conference",
           "standings": {"entries": [
             \(entry("21", "Philadelphia", conf: "1-0", overall: "2-1"))]},
           "children": [
             {"id": "1", "name": "NFC East",
              "standings": {"entries": [\(entry("21", "Philadelphia", conf: "1-0", overall: "2-1"))]}}]}]}
        """
    }

    @Test func divisionStandingsKeepOnlyTheDivisions() throws {
        let tables = ESPNMapper.divisionStandings(from: try response(levelThreeJSON), league: .nfl)

        #expect(tables.map(\.name) == ["AFC East", "AFC North", "NFC East"])
        #expect(tables.map(\.id) == [4, 12, 1])
        // Each knows the conference it hangs under, which is what lets a
        // conference page show its own four and no one else's.
        #expect(tables.map(\.parentId) == [8, 8, 7])
        #expect(tables.allSatisfy { $0.league == .nfl })
    }

    @Test func aDivisionTableCarriesItsTeamsRecords() throws {
        let tables = ESPNMapper.divisionStandings(from: try response(levelThreeJSON), league: .nfl)
        let east = try #require(tables.first { $0.id == 4 })

        #expect(east.entries.map(\.team.location) == ["Buffalo"])
        #expect(east.entries.first?.conferenceRecord == "2-0")
        #expect(east.entries.first?.overallRecord == "3-0")
    }

    /// A conference page asks its divisions by parent, which is the whole
    /// point of carrying one.
    @Test func aConferencesOwnDivisionsAreFilterableByParent() throws {
        let tables = ESPNMapper.divisionStandings(from: try response(levelThreeJSON), league: .nfl)

        #expect(tables.filter { $0.parentId == 8 }.map(\.name) == ["AFC East", "AFC North"])
    }

    /// The same payload read the shipped way still gives the conferences —
    /// the deeper request changes what we ask for, never how the rest of
    /// the app reads a standings response.
    @Test func theSameResponseStillReadsAsConferences() throws {
        let tables = ESPNMapper.conferenceStandings(from: try response(levelThreeJSON), league: .nfl)

        #expect(tables.map(\.name) == ["AFC", "NFC"])
        #expect(tables.allSatisfy { $0.parentId == nil })
        #expect(tables.first?.entries.count == 2)
    }

    /// A division id the registry has never seen still tables, under the
    /// conference the payload nests it in — a realignment shouldn't cost
    /// the page a division. Only a group with no parent at either source
    /// is dropped, because that one isn't a division at all.
    @Test func anUnknownDivisionKeepsThePayloadsParent() throws {
        let json = """
        {"children": [
          {"id": "8", "name": "American Football Conference",
           "children": [
             {"id": "4", "name": "AFC East",
              "standings": {"entries": [\(entry("2", "Buffalo", conf: "2-0", overall: "3-0"))]}},
             {"id": "404", "name": "AFC Mystery",
              "standings": {"entries": [\(entry("99", "Nowhere", conf: "0-0", overall: "0-0"))]}}]}]}
        """
        let tables = ESPNMapper.divisionStandings(from: try response(json), league: .nfl)

        // The unknown id keeps the payload's own parent rather than being
        // invented — it is a child of the AFC in the response.
        #expect(tables.map(\.id) == [4, 404])
        #expect(tables.map(\.parentId) == [8, 8])
    }
}
