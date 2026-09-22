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

    /// The number and the position are Profile rows, and the hero is a name
    /// over a team badge (2026-09-21) — so they are asserted where they are
    /// read now, rather than as a line the page no longer prints.
    @Test func theNumberAndPositionAreProfileRows() {
        let rows = identity(player()).profileRows
        #expect(rows.first { $0.label == "Jersey" }?.value == "11")
        #expect(rows.first { $0.label == "Position" }?.value == "Quarterback")
    }

    /// The badge pushes a `Team`, so the roster door has to carry one all
    /// the way through — a name alone draws a badge that goes nowhere, which
    /// is why `PlayerPage` tests for the team and not for the name.
    @Test func theRosterDoorCarriesThePushableTeam() {
        // Not named `identity`: that is the helper's own name, and a local
        // binding initialized from a call to itself is a compile error.
        let beck = identity(player())
        #expect(beck.team?.id == "61")
        #expect(beck.team?.league == .collegeFootball)
        // The two team fields agree, because one init sets both.
        #expect(beck.teamName == "Georgia")
        // A door that knows neither still constructs, and draws no badge.
        let teamless = PlayerIdentity(athleteId: "1", name: "Nobody",
                                      league: .collegeFootball,
                                      teamName: nil, teamLogoURL: nil)
        #expect(teamless.team == nil)
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
    /// abbreviations — `RosterRow`'s rule. It says what the hero draws and
    /// no more (2026-09-21): the number and the position left the hero for
    /// the Profile card, and their spoken form went with them rather than
    /// staying behind to announce rows that are already labelled.
    @Test func spokenSummaryIsASentence() {
        #expect(identity(player()).spokenSummary == "Carson Beck, Georgia")
        let teamless = PlayerIdentity(athleteId: "1", name: "Nobody",
                                      league: .collegeFootball,
                                      teamName: nil, teamLogoURL: nil)
        #expect(teamless.spokenSummary == "Nobody")
    }
}
