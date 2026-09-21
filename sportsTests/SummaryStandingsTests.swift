import Foundation
import Testing
@testable import StatSide

// E21, 2026-09-21: the game page fired a second request for standings
// tables that were already inside the summary it had just fetched. These
// cover what comes out of that block — and what deliberately doesn't.

private final class SummaryFixtureToken {}

private func summaryFixture(_ name: String) throws -> SummaryResponseDTO {
    let url = try #require(
        Bundle(for: SummaryFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try JSONDecoder().decode(SummaryResponseDTO.self,
                                    from: Data(contentsOf: url))
}

@Suite struct SummaryStandingsTests {
    // MARK: - College football, the league that carries them

    @Test func readsBothConferencesOutOfTheSummary() throws {
        let dto = try summaryFixture("summary-final-live")
        let summary = ESPNMapper.gameSummary(from: dto)
        #expect(summary.matchupStandings.count == 2)

        // Miami's ACC and Indiana's Big Ten, each whole: the card's place
        // number is only meaningful against the full conference.
        let acc = try #require(summary.matchupStandings.first { $0.name == "ACC" })
        let bigTen = try #require(summary.matchupStandings.first { $0.name == "Big Ten" })
        #expect(acc.entries.count == 17)
        #expect(bigTen.entries.count == 18)
    }

    @Test func namesEachGroupFromTheTeamStandingInIt() throws {
        // The payload's groups carry no id of their own. The id comes
        // from the competing team the group contains — which is what
        // makes the row tappable through to the conference page.
        let dto = try summaryFixture("summary-final-live")
        let summary = ESPNMapper.gameSummary(from: dto)
        let acc = try #require(summary.matchupStandings.first { $0.name == "ACC" })
        let bigTen = try #require(summary.matchupStandings.first { $0.name == "Big Ten" })
        #expect(acc.id == 1)
        #expect(bigTen.id == 5)
        #expect(acc.conference == ConferenceID.cfb(1))
        #expect(acc.entries.contains { $0.team.id == "2390" })    // Miami
        #expect(bigTen.entries.contains { $0.team.id == "84" })   // Indiana
    }

    @Test func competingTeamsKeepTheIdentityThePageWasPushedWith() throws {
        // The summary's standings entry is a display string and an id.
        // The two sides substitute their own decoded `Team`, so the card
        // renders the crest and location it always has; everyone else is
        // a thin stand-in holding a place number.
        let dto = try summaryFixture("summary-final-live")
        let summary = ESPNMapper.gameSummary(from: dto)
        let acc = try #require(summary.matchupStandings.first { $0.name == "ACC" })
        let miami = try #require(acc.entries.first { $0.team.id == "2390" })
        #expect(miami.team == summary.away?.team)
        #expect(miami.team.abbreviation == "MIA")
        #expect(miami.team.league == .collegeFootball)

        let duke = try #require(acc.entries.first { $0.team.id == "150" })
        #expect(duke.team.location == "Duke")
        #expect(duke.team.conferenceId == 1)
        // The default crest, never the dark variant that sits beside it.
        #expect(duke.team.logoURL?.absoluteString
            == "https://a.espncdn.com/i/teamlogos/ncaa/500/150.png")
    }

    @Test func readsTheCardsTwoColumnsOffEveryRow() throws {
        // OVR and CONF, which is the whole of `matchupStandingsColumns`
        // for college football. The fixture is a Week 1 capture, so both
        // are honestly 0-0 — the point is that they decoded at all.
        let dto = try summaryFixture("summary-final-live")
        let summary = ESPNMapper.gameSummary(from: dto)
        let acc = try #require(summary.matchupStandings.first { $0.name == "ACC" })
        #expect(acc.entries.allSatisfy { $0.overallRecord == "0-0" })
        #expect(acc.entries.allSatisfy { $0.conferenceRecord == "0-0" })
        for column in League.collegeFootball.matchupStandingsColumns {
            #expect(acc.entries.allSatisfy({ $0.value(for: column) != nil }),
                    "\(column.caption) is missing from a row")
        }
    }

    @MainActor
    @Test func aWeekOneTableStillHidesTheCard() throws {
        // `MatchupStandings.hasContent`'s preseason rule is unaffected by
        // where the tables came from: an all-0-0 conference is last
        // season's carried-over order, not information.
        let dto = try summaryFixture("summary-final-live")
        let summary = ESPNMapper.gameSummary(from: dto)
        let away = try #require(summary.away?.team)
        let home = try #require(summary.home?.team)
        #expect(!MatchupStandings.hasContent(away: away, home: home,
                                             standings: summary.matchupStandings))
    }

    @Test func entriesKeepEspnsOrder() throws {
        // ESPN sends the table in standings order and the app never
        // re-sorts one — the order encodes tiebreakers we can't derive.
        // Week 1's is alphabetical because everyone is 0-0.
        let dto = try summaryFixture("summary-final-live")
        let summary = ESPNMapper.gameSummary(from: dto)
        let acc = try #require(summary.matchupStandings.first { $0.name == "ACC" })
        #expect(acc.entries.first?.team.location == "Boston College")
        #expect(acc.entries.last?.team.location == "Wake Forest")
    }

    @Test func summaryHeaderTeamsKnowTheirConference() throws {
        // The header's team object carries `groups`, not `conferenceId` —
        // the same number under another name, and unread until now. It is
        // what resolves each group above.
        let dto = try summaryFixture("summary-final-live")
        let summary = ESPNMapper.gameSummary(from: dto)
        #expect(summary.away?.team.conferenceId == 1)   // Miami, ACC
        #expect(summary.home?.team.conferenceId == 5)   // Indiana, Big Ten
    }

    // MARK: - The leagues that keep the fetch

    @Test func winterLeaguesShipADivisionAndAreLeftAlone() throws {
        // Boston's Atlantic and Vegas's Pacific are divisions, not
        // conferences, and both are short of the card's column set — the
        // NBA sends no `total` summary, the NHL no `gamesplayed`. A
        // division under a caption the card would have to invent is worse
        // than the request it saves, so these keep `conferenceStandings()`.
        for (name, league) in [("nba-summary", League.nba), ("nhl-summary", .nhl)] {
            let dto = try summaryFixture(name)
            let summary = ESPNMapper.gameSummary(from: dto, league: league)
            #expect(summary.matchupStandings.isEmpty,
                    "\(league.rawValue) should keep its fetch")
            #expect(!league.summaryCarriesMatchupStandings)
        }
        #expect(!League.nfl.summaryCarriesMatchupStandings)
        #expect(League.collegeFootball.summaryCarriesMatchupStandings)
    }

    // MARK: - Degradation

    @Test func aMissingBlockCostsTheRequestBackAndNeverTheCard() {
        // Nothing to read means an empty array, which is what the screen
        // reads as "fall back to the tables" — never a half-built one.
        #expect(ESPNMapper.matchupStandings(from: nil, league: .collegeFootball,
                                            teams: []).isEmpty)
        #expect(ESPNMapper.matchupStandings(
            from: SummaryStandingsDTO(groups: []),
            league: .collegeFootball, teams: []).isEmpty)
    }

    @Test func aGroupTheTeamsArentInStillNamesItself() throws {
        // If neither side turns up in a group, there is no id to take —
        // the table keeps ESPN's own short header and simply isn't
        // tappable, rather than vanishing.
        let dto = try Self.standings("""
        {"groups": [{
          "header": "2026 Sun Belt Conference Standings",
          "divisionHeader": "Sun Belt Conference",
          "shortDivisionHeader": "Sun Belt",
          "standings": {"entries": [
            {"id": "2026", "team": "Texas State",
             "stats": [{"type": "total", "summary": "3-1"}]}
          ]}
        }]}
        """)
        let tables = ESPNMapper.matchupStandings(from: dto, league: .collegeFootball,
                                                 teams: [])
        let table = try #require(tables.first)
        #expect(table.name == "Sun Belt")
        #expect(table.id == nil)
        #expect(table.conference == nil)
        #expect(table.entries.map(\.overallRecord) == ["3-1"])
    }

    @Test func aRowWithNoIdIsDroppedAndTheRestSurvive() throws {
        // The rule the whole decoder runs on: a bad element drops the
        // row, never the table.
        let dto = try Self.standings("""
        {"groups": [{"standings": {"entries": [
          {"team": "Nobody"},
          {"id": "61", "team": "Georgia", "stats": [{"type": "vsconf", "summary": "2-0"}]}
        ]}}]}
        """)
        let table = try #require(ESPNMapper.matchupStandings(
            from: dto, league: .collegeFootball, teams: []).first)
        #expect(table.entries.map(\.team.id) == ["61"])
        #expect(table.entries.first?.conferenceRecord == "2-0")
        // Nothing named it, so it falls back rather than inventing one.
        #expect(table.name == "Conference")
    }

    private static func standings(_ json: String) throws -> SummaryStandingsDTO {
        try JSONDecoder().decode(SummaryStandingsDTO.self,
                                 from: Data(json.utf8))
    }
}

// The half of the change that reaches past the game page: `TeamDTO` now
// reads `groups.id` where ESPN sends no `conferenceId`. Two payloads ship
// a team that way, and both had been decoding to a team that didn't know
// what conference it was in.
@Suite struct TeamGroupsConferenceTests {
    @Test func aRankedTeamKnowsItsConference() throws {
        let url = try #require(
            Bundle(for: SummaryFixtureToken.self)
                .url(forResource: "rankings-live", withExtension: "json"))
        let dto = try JSONDecoder().decode(RankingsResponseDTO.self,
                                           from: Data(contentsOf: url))
        let polls = ESPNMapper.polls(from: dto)
        let ranked = polls.flatMap(\.ranks)
        #expect(!ranked.isEmpty)
        // Not "most of them": every ranked team in the payload carries
        // `groups`, across all five polls down to Division III, so a nil
        // here means the fallback missed. Whether the app's registry
        // *names* that conference is a separate question — a Division II
        // group id is real and unknown to us at the same time.
        #expect(ranked.allSatisfy { $0.team.conferenceId != nil })

        let ap = try #require(polls.first { $0.type == "ap" })
        #expect(ap.ranks.first?.team.conferenceId == 5)      // Indiana, Big Ten
        #expect(ap.ranks.dropFirst().first?.team.conferenceId == 1)  // Miami, ACC
    }
}
