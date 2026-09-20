import Foundation
import Testing
@testable import StatSide

private final class PlayerFixtureToken {}

private func rosterFixture(_ name: String) throws -> TeamRoster {
    let url = try #require(
        Bundle(for: PlayerFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    let dto = try JSONDecoder().decode(RosterResponseDTO.self, from: Data(contentsOf: url))
    return ESPNMapper.roster(from: dto)
}

private func team(_ id: String, _ location: String,
                  short: String? = nil, league: League = .collegeFootball) -> Team {
    var value = Team(id: id, location: location, name: nil, abbreviation: nil,
                     displayName: nil, shortDisplayName: short,
                     logoURL: nil, conferenceId: nil)
    value.league = league
    return value
}

/// The first player of the first group, which is enough: these assert the
/// mapping from a roster row to a page, not the roster decode (that is
/// `TeamRosterTests`).
private func firstPlayer(_ roster: TeamRoster) throws -> RosterPlayer {
    try #require(roster.groups.first(where: { !$0.players.isEmpty })?.players.first)
}

/// A roster row becomes a page (2026-09-20). The facts travel with it — the
/// page makes no second request, because there is no endpoint to make it to.
@Suite struct PlayerIdentityFromRoster {

    /// College football publishes no age whatsoever and a class year instead,
    /// so Profile's third row is CLASS there — `RosterMetric`'s rule, applied
    /// to a card instead of a column.
    @Test func collegeFootballCarriesClassAndNeverAge() throws {
        let roster = try rosterFixture("cfb-roster")
        let player = try firstPlayer(roster)
        let identity = PlayerIdentity(player: player,
                                      team: team("145", "Ole Miss", short: "Ole Miss"),
                                      league: .collegeFootball)
        let labels = identity.profileRows.map(\.label)
        #expect(labels.contains("Class"))
        #expect(!labels.contains("Age"))
    }

    /// The pro leagues ship an age and no class, so the same row inverts.
    @Test func proLeaguesCarryAgeAndNeverClass() throws {
        for (fixture, league) in [("nfl-roster", League.nfl),
                                  ("nba-roster", League.nba),
                                  ("nhl-roster", League.nhl)] {
            let roster = try rosterFixture(fixture)
            let player = try firstPlayer(roster)
            let identity = PlayerIdentity(player: player,
                                          team: team("1", "Somewhere", league: league),
                                          league: league)
            let labels = identity.profileRows.map(\.label)
            #expect(!labels.contains("Class"), "\(fixture) should not carry a class")
            // Age only where ESPN actually sent one — a missing age drops the
            // row rather than printing a dash.
            if player.age != nil {
                #expect(labels.contains("Age"), "\(fixture) should carry an age")
            }
        }
    }

    /// The athlete id is ESPN's own, unchanged — it is the join to a box
    /// score row, so anything done to it here breaks the other doors later.
    @Test func keepsESPNsAthleteIdVerbatim() throws {
        let roster = try rosterFixture("cfb-roster")
        let player = try firstPlayer(roster)
        let identity = PlayerIdentity(player: player,
                                      team: team("145", "Ole Miss"),
                                      league: .collegeFootball)
        #expect(identity.athleteId == player.id)
    }

    /// The page wants the full press photo; the row wanted a thumbnail. The
    /// identity carries the full one, and `thumbnailURL` stays the row's
    /// business.
    @Test func carriesTheFullHeadshotNotTheRowThumbnail() throws {
        let roster = try rosterFixture("nfl-roster")
        let player = try #require(roster.groups
            .flatMap(\.players)
            .first { $0.headshotURL != nil })
        let identity = PlayerIdentity(player: player, team: team("12", "Kansas City",
                                                                 league: .nfl),
                                      league: .nfl)
        #expect(identity.headshotURL == player.headshotURL)
        #expect(identity.headshotURL != player.thumbnailURL)
    }
}

/// Everything below builds its player by hand: these are rules about missing
/// fields and about identity, and a fixture can only carry one shape of each.
@Suite struct PlayerIdentityRules {

    private func player(id: String = "4430841",
                        name: String = "Carson Beck",
                        jersey: String? = "11",
                        position: String? = "QB",
                        positionName: String? = "Quarterback",
                        height: String? = "6' 4\"",
                        weight: String? = "220 lbs",
                        age: Int? = nil,
                        classAbbreviation: String? = "JR",
                        injuryStatus: String? = nil) -> RosterPlayer {
        RosterPlayer(id: id, name: name, jersey: jersey, position: position,
                     positionName: positionName, height: height, weight: weight,
                     age: age, classAbbreviation: classAbbreviation,
                     headshotURL: nil, injuryStatus: injuryStatus)
    }

    private func identity(_ p: RosterPlayer,
                          league: League = .collegeFootball,
                          short: String? = "Georgia") -> PlayerIdentity {
        PlayerIdentity(player: p, team: team("61", "Georgia", short: short, league: league),
                       league: league)
    }

    /// Two leagues reuse athlete ids the way they reuse team ids, and this
    /// value is a navigation identity — a destination whose identity doesn't
    /// change is reused with its state intact (2026-09-10).
    @Test func identityIsNamespacedByLeague() {
        let cfb = identity(player(), league: .collegeFootball)
        let nfl = identity(player(), league: .nfl)
        #expect(cfb.athleteId == nfl.athleteId)
        #expect(cfb.id != nfl.id)
        #expect(cfb.id == "cfb-4430841")
    }

    @Test func metaLineReadsTeamNumberPosition() {
        #expect(identity(player()).metaLine == "Georgia · #11 · QB")
    }

    /// Each part drops out on its own, so a player ESPN knows almost nothing
    /// about is just a name rather than a line of orphaned separators.
    @Test func metaLineDropsWhatIsMissing() {
        #expect(identity(player(jersey: nil)).metaLine == "Georgia · QB")
        #expect(identity(player(jersey: nil, position: nil)).metaLine == "Georgia")
        // A team always has a location, so the roster door can never produce
        // a nil team name. The empty line is only reachable from a door that
        // does not know the team — which is what a box score row will be.
        let teamless = PlayerIdentity(athleteId: "1", name: "Nobody",
                                      league: .collegeFootball,
                                      teamName: nil, teamLogoURL: nil)
        #expect(teamless.metaLine == "")
        // An empty string is ESPN's other way of not knowing.
        #expect(identity(player(jersey: "")).metaLine == "Georgia · QB")
    }

    /// The design's order: the physical facts, then the league's own metric,
    /// then what they play and wear.
    @Test func profileRowsFollowTheDesignsOrder() {
        #expect(identity(player()).profileRows.map(\.label)
                == ["Height", "Weight", "Class", "Position", "Jersey"])
    }

    @Test func profileRowsSkipWhatESPNDidNotSend() {
        let sparse = player(jersey: nil, position: nil, positionName: nil,
                            height: nil, weight: nil, classAbbreviation: nil)
        #expect(identity(sparse).profileRows.isEmpty)
    }

    /// Only the NFL ships an injury designation, and only for the handful
    /// carrying one — it earns a row when it is there and nothing when not.
    @Test func injuryStatusBecomesItsOwnRow() {
        let hurt = player(age: 27, classAbbreviation: nil, injuryStatus: "Questionable")
        let rows = identity(hurt, league: .nfl).profileRows
        #expect(rows.last?.label == "Status")
        #expect(rows.last?.value == "Questionable")
    }

    /// The four known abbreviations get their long form; anything else passes
    /// through untouched, because capitalizing an unmapped "GR" spells "Gr".
    @Test func classYearSpellsOutOnlyWhatItKnows() {
        func classValue(_ abbreviation: String) -> String? {
            identity(player(classAbbreviation: abbreviation))
                .profileRows.first { $0.label == "Class" }?.value
        }
        #expect(classValue("FR") == "Freshman")
        #expect(classValue("SR") == "Senior")
        #expect(classValue("GR") == "GR")
    }

    /// VoiceOver gets a sentence, not a name followed by unlabelled
    /// abbreviations — `RosterRow`'s rule, and the position is spoken in full
    /// because "QB" is read as letters.
    @Test func spokenSummaryIsASentence() {
        #expect(identity(player()).spokenSummary
                == "Carson Beck, Georgia, number 11, Quarterback")
        #expect(identity(player(jersey: nil, positionName: nil)).spokenSummary
                == "Carson Beck, Georgia, QB")
    }
}
