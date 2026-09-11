import Foundation
import Testing
@testable import StatSide

private final class RosterFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: RosterFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private func roster(_ name: String) throws -> TeamRoster {
    ESPNMapper.roster(from: try JSONDecoder().decode(RosterResponseDTO.self,
                                                    from: fixture(name)))
}

private func roster(json: String) throws -> TeamRoster {
    ESPNMapper.roster(from: try JSONDecoder().decode(RosterResponseDTO.self,
                                                    from: Data(json.utf8)))
}

/// Fixtures trimmed from live captures, 2026-09-10 — `/teams/{id}/roster` for
/// Ole Miss, Kansas City, the Lakers and Montreal.
@Suite struct RosterShapes {
    /// ESPN groups football rosters into six squads and ships the empty ones
    /// anyway (Ole Miss has nobody on IR, suspended or the practice squad).
    /// A header over nothing is chrome, so those produce no card.
    @Test func aGroupedPayloadKeepsESPNsOrderAndDropsEmptyGroups() throws {
        let roster = try roster("cfb-roster")
        #expect(roster.groups.map(\.name) == ["Offense", "Defense", "Special teams"])
    }

    /// The finding this whole decoder is shaped around: basketball's
    /// `athletes` is a flat array of players, where every other league's is an
    /// array of groups. A decoder written for the grouped form returns nothing
    /// here — and an empty roster is exactly how the tab hides itself, so the
    /// bug would be silent.
    @Test func theFlatBasketballPayloadBecomesOneGroup() throws {
        let roster = try roster("nba-roster")
        #expect(roster.groups.count == 1)
        let group = try #require(roster.groups.first)
        #expect(group.name == "Roster")
        #expect(group.players.count == 4)
    }

    /// Hockey's group names arrive display-ready, so the mapper's fallback —
    /// pass an unmapped label through capitalized — is what renders them.
    @Test func hockeysOwnGroupNamesPassThrough() throws {
        let roster = try roster("nhl-roster")
        #expect(roster.groups.map(\.name)
            == ["Centers", "Left Wings", "Right Wings", "Defense", "Goalies"])
    }

    /// Football's arrive as lowercase codes and need naming.
    @Test func footballsCodesBecomeDisplayNames() throws {
        let roster = try roster("nfl-roster")
        #expect(roster.groups.map(\.name)
            == ["Offense", "Defense", "Special teams", "Injured reserve", "Practice squad"])
    }

    /// A code we've never seen is a card we've never seen, not a card that
    /// goes missing — ESPN adding a seventh squad must not silently drop
    /// whoever is in it.
    @Test func anUnknownGroupCodeIsKeptRatherThanDropped() throws {
        let roster = try roster(json: """
        {"athletes": [{"position": "taxiSquad",
                       "items": [{"id": "1", "displayName": "Jo Adams"}]}]}
        """)
        #expect(roster.groups.map(\.name) == ["TaxiSquad"])
    }

    /// `LossyArray`'s promise, at both levels: a junk entry in the array and a
    /// junk player inside a group each cost exactly themselves.
    @Test func aMalformedEntryDoesNotTakeTheRosterWithIt() throws {
        let roster = try roster(json: """
        {"athletes": ["nonsense",
                      {"position": "offense",
                       "items": [17, {"id": "1", "displayName": "Jo Adams"}]}]}
        """)
        let group = try #require(roster.groups.first)
        #expect(roster.groups.count == 1)
        #expect(group.players.map(\.name) == ["Jo Adams"])
    }

    /// A row with no name says nothing and a row with no id can't hold its
    /// place in a list. Everything else about a player is allowed to be
    /// missing.
    @Test func aPlayerWithNoIdOrNoNameIsDropped() throws {
        let roster = try roster(json: """
        {"athletes": [{"position": "offense",
                       "items": [{"displayName": "No Id"},
                                 {"id": "2"},
                                 {"id": "3", "displayName": "Jo Adams"}]}]}
        """)
        #expect(roster.groups.first?.players.map(\.name) == ["Jo Adams"])
    }

    /// ESPN ships no jersey for 10 of the 18 Lakers in preseason. The row goes
    /// blank in that column; the player still appears.
    @Test func aPlayerWithNoJerseyStillMaps() throws {
        let group = try #require(try roster("nba-roster").groups.first)
        let numberless = group.players.filter { $0.jersey == nil }
        #expect(!numberless.isEmpty)
        #expect(numberless.allSatisfy { !$0.name.isEmpty })
    }

    @Test func theCoachIsTheOneESPNListsFirst() throws {
        #expect(try roster("cfb-roster").coach?.name == "Lane Kiffin")
        #expect(try roster("nba-roster").coach?.name == "JJ Redick")
    }

    /// Only the NFL ships these, and only for the handful carrying one.
    @Test func anInjuryDesignationIsCarried() throws {
        let roster = try roster("nfl-roster")
        let injured = roster.groups.flatMap(\.players).compactMap(\.injuryStatus)
        #expect(!injured.isEmpty)
    }

    @Test func aProviderWithNoRosterEndpointAnswersEmpty() {
        #expect(TeamRoster.empty.isEmpty)
        #expect(TeamRoster(coach: nil, groups: [RosterGroup(name: "Roster", players: [])]).isEmpty)
    }
}

/// The one right-aligned column a roster row carries. Per league, because
/// college football publishes no age at all — an AGE caption there would
/// promise a number that never arrives.
@Suite struct RosterMetricRule {
    @Test func collegeFootballKeepsAClassAndTheProLeaguesKeepAnAge() {
        #expect(League.collegeFootball.rosterMetric == .classYear)
        for league in [League.nfl, .nba, .nhl] {
            #expect(league.rosterMetric == .age)
        }
    }

    /// Ole Miss's payload carries a class on every player and an age on none.
    @Test func aCollegePlayerRendersTheirClass() throws {
        let player = try #require(try roster("cfb-roster").groups.first?.players.first)
        #expect(player.age == nil)
        #expect(player.metricValue(for: .collegeFootball) == "FR")
    }

    /// Kansas City's carries the other one.
    @Test func aProPlayerRendersTheirAge() throws {
        let player = try #require(try roster("nfl-roster").groups.first?.players.first)
        #expect(player.classAbbreviation == nil)
        #expect(player.metricValue(for: .nfl) == player.age.map(String.init))
        #expect(player.metricValue(for: .nfl) != nil)
    }

    /// VoiceOver reads the row as a sentence, so the abbreviation is spelled
    /// out — "JR" is read as letters.
    @Test func theClassIsSpokenInFull() {
        #expect(RosterMetric.classYear.spoken("JR") == "junior")
        #expect(RosterMetric.age.spoken("30") == "age 30")
        // An abbreviation we don't know is still said, not swallowed.
        #expect(RosterMetric.classYear.spoken("GR") == "GR")
    }
}

/// ESPN links the 600×436 press photo on every roster row. A college football
/// roster is 100 of them — ~20 MB of images to fill a screenful of 36pt discs
/// — so the row asks the CDN's resizer for a thumbnail instead.
@Suite struct RosterHeadshots {
    @Test func aHeadshotIsRequestedAtRowSize() throws {
        let player = try #require(try roster("cfb-roster").groups.first?.players.first)
        let thumbnail = try #require(player.thumbnailURL)
        #expect(thumbnail.absoluteString.contains("combiner/i?img=/i/headshots/"))
        #expect(thumbnail.absoluteString.hasSuffix("&w=150&h=110"))
    }

    /// The derivation is scoped to ESPN's headshot bucket — a team mark that
    /// wandered in here must come back untouched.
    @Test func onlyHeadshotsAreResized() throws {
        let logo = try #require(URL(string: "https://a.espncdn.com/i/teamlogos/ncaa/500/145.png"))
        #expect(logo.headshotThumbnail == nil)
        let elsewhere = try #require(URL(string: "https://example.com/i/headshots/a.png"))
        #expect(elsewhere.headshotThumbnail == nil)
    }

    /// A player with no photo keeps a nil URL rather than a combiner link to
    /// nothing — the row draws its quiet disc.
    @Test func aPlayerWithNoPhotoDerivesNoThumbnail() throws {
        let roster = try roster(json: """
        {"athletes": [{"position": "offense",
                       "items": [{"id": "1", "displayName": "Jo Adams"}]}]}
        """)
        let player = try #require(roster.groups.first?.players.first)
        #expect(player.headshotURL == nil)
        #expect(player.thumbnailURL == nil)
    }
}
