import Foundation
import Testing
@testable import StatSide

/// The core API's ranking shape, which the site API's `/rankings` doesn't
/// share: the record is nested, and a rank names its team by `$ref` alone.
/// Trimmed from a live 2019 final-AP response (2026-09-05).
private let coreRankingJSON = Data("""
{
  "id": "1",
  "name": "AP Top 25",
  "shortName": "AP Poll",
  "type": "ap",
  "headline": "2019 NCAA Football Rankings - AP Poll Week 16",
  "shortHeadline": "2019 AP Poll: Final Rankings",
  "ranks": [
    {
      "current": 1, "previous": 1, "points": 1535.0, "firstPlaceVotes": 47,
      "record": { "summary": "13-0" },
      "team": { "$ref": "http://sports.core.api.espn.com/v2/sports/football/leagues/college-football/seasons/2019/teams/99?lang=en&region=us" }
    },
    {
      "current": 2, "previous": 3, "points": 1470.0,
      "record": { "summary": "13-1" },
      "team": { "$ref": "http://sports.core.api.espn.com/v2/sports/football/leagues/college-football/seasons/2019/teams/2294?lang=en" }
    },
    {
      "current": 3,
      "team": { "$ref": "http://sports.core.api.espn.com/v2/sports/football/leagues/college-football/seasons/2019/teams/57?lang=en" }
    }
  ]
}
""".utf8)

/// The `/teams` directory the ref ids resolve against, in ESPN's envelope.
private let teamsJSON = Data("""
{
  "sports": [{ "leagues": [{ "teams": [
    { "team": { "id": "99", "location": "LSU", "name": "Tigers", "abbreviation": "LSU",
                "logos": [{ "href": "https://a.espncdn.com/i/teamlogos/ncaa/500/99.png" }] } },
    { "team": { "id": "2294", "location": "Clemson", "name": "Tigers", "abbreviation": "CLEM" } }
  ] }] }]
}
""".utf8)

@Suite struct HistoricalRankingsTests {
    private func directory() throws -> [String: Team] {
        let dto = try JSONDecoder().decode(TeamsResponseDTO.self, from: teamsJSON)
        return ESPNMapper.teamsById(from: dto)
    }

    @Test func decodesACoreSeasonPoll() throws {
        let dto = try JSONDecoder().decode(CoreRankingDTO.self, from: coreRankingJSON)
        let poll = ESPNMapper.poll(from: dto, teams: try directory())

        #expect(poll.type == "ap")
        // The short headline names the season, which is what the hero says.
        #expect(poll.headline == "2019 AP Poll: Final Rankings")

        let top = try #require(poll.ranks.first)
        #expect(top.team.location == "LSU")
        #expect(top.record == "13-0")
        #expect(top.firstPlaceVotes == 47)
        #expect(top.movement == 0)

        #expect(poll.ranks[1].team.location == "Clemson")
        #expect(poll.ranks[1].movement == 1)
    }

    /// A rank whose team the directory can't name is dropped rather than
    /// rendered as a dash — the rank numbers already explain the gap.
    @Test func dropsUnresolvableTeams() throws {
        let dto = try JSONDecoder().decode(CoreRankingDTO.self, from: coreRankingJSON)
        let poll = ESPNMapper.poll(from: dto, teams: try directory())

        #expect(poll.ranks.count == 2)
        #expect(poll.ranks.allSatisfy { $0.team.id != "57" })
    }

    @Test func readsTheTeamIdOutOfARef() {
        let ref = CoreRefDTO(ref: "http://sports.core.api.espn.com/v2/sports/football/leagues/college-football/seasons/2019/teams/2294?lang=en&region=us")
        #expect(ref.teamId == "2294")
        #expect(CoreRefDTO(ref: nil).teamId == nil)
        #expect(CoreRefDTO(ref: "https://example.com/nothing").teamId == nil)
    }
}
