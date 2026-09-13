import Foundation
import Testing
@testable import StatSide

private final class FixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: FixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private func fixtureVenue(_ name: String, league: League) throws -> TeamVenue? {
    let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture(name))
    return ESPNMapper.teamSchedule(from: dto, league: league).homeVenue
}

private func date(venue: String?, city: String? = nil, isHome: Bool,
                  isNeutral: Bool = false, attendance: Int? = nil) -> TeamVenue.Fixture {
    TeamVenue.Fixture(venue: venue, city: city, isHome: isHome,
                      isNeutral: isNeutral, attendance: attendance)
}

/// A schedule event trimmed to what the venue rule reads, decoded through
/// the real DTOs so the JSON keys are the ones ESPN actually sends.
private func scheduleEvent(seasonType: Int, venue: String, isHome: Bool,
                           attendance: Int) throws -> ScheduleEventDTO {
    let json = """
    {
      "id": "1",
      "seasonType": { "type": \(seasonType) },
      "competitions": [{
        "neutralSite": false,
        "attendance": \(attendance),
        "venue": { "fullName": "\(venue)", "address": { "city": "Seattle", "state": "WA" } },
        "competitors": [{ "homeAway": "\(isHome ? "home" : "away")", "team": { "id": "26" } }]
      }]
    }
    """
    return try JSONDecoder().decode(ScheduleEventDTO.self, from: Data(json.utf8))
}

@Suite struct TeamVenueRuleTests {
    @Test func takesTheGroundTheTeamKeepsHosting() {
        let venue = TeamVenue.home(from: [
            date(venue: "Sanford Stadium", city: "Athens, GA", isHome: true),
            date(venue: "Sanford Stadium", isHome: true),
            date(venue: "Neyland Stadium", isHome: false),
        ])
        #expect(venue?.name == "Sanford Stadium")
        #expect(venue?.city == "Athens, GA")
        #expect(venue?.homeGames == 2)
    }

    @Test func neutralSitesAreNeverHome() {
        // Georgia's season opens at the Mercedes-Benz Stadium as the
        // nominal host. A neutral site is nobody's home ground, so even a
        // majority of them can't take the name.
        let venue = TeamVenue.home(from: [
            date(venue: "Mercedes-Benz Stadium", isHome: true, isNeutral: true),
            date(venue: "Mercedes-Benz Stadium", isHome: true, isNeutral: true),
            date(venue: "Sanford Stadium", isHome: true),
        ])
        #expect(venue?.name == "Sanford Stadium")
        #expect(venue?.homeGames == 1)
    }

    @Test func aOneOffRelocationDoesntRenameHome() {
        // The modal rule's whole point: a hurricane week or a re-turfing
        // moves one date, not the season's home.
        let venue = TeamVenue.home(from: [
            date(venue: "Somewhere Else", isHome: true),
            date(venue: "Sanford Stadium", isHome: true),
            date(venue: "Sanford Stadium", isHome: true),
        ])
        #expect(venue?.name == "Sanford Stadium")
        #expect(venue?.homeGames == 2)
    }

    @Test func tiesBreakTowardTheEarlierDate() {
        // Dictionary order is not an answer; the first date played is.
        let venue = TeamVenue.home(from: [
            date(venue: "Zed Field", isHome: true),
            date(venue: "Alpha Field", isHome: true),
        ])
        #expect(venue?.name == "Zed Field")
    }

    @Test func averagesOnlyThePublishedGates() {
        let venue = TeamVenue.home(from: [
            date(venue: "Ground", isHome: true, attendance: 100),
            date(venue: "Ground", isHome: true, attendance: 201),
            date(venue: "Ground", isHome: true, attendance: nil),
            // A zero gate is ESPN not knowing, not an empty stadium.
            date(venue: "Ground", isHome: true, attendance: 0),
            // An away gate is somebody else's crowd.
            date(venue: "Elsewhere", isHome: false, attendance: 90_000),
        ])
        #expect(venue?.homeGames == 4)
        #expect(venue?.countedGames == 2)
        #expect(venue?.averageAttendance == 151)   // 301 / 2, rounded
    }

    @Test func aSeasonWithNoHomeDateHasNoVenue() {
        #expect(TeamVenue.home(from: []) == nil)
        #expect(TeamVenue.home(from: [date(venue: "Elsewhere", isHome: false)]) == nil)
        // A home date ESPN didn't place can't name a ground.
        #expect(TeamVenue.home(from: [date(venue: nil, isHome: true)]) == nil)
    }

    @Test func aScheduledButUnplayedSeasonStillNamesTheGround() {
        let venue = TeamVenue.home(from: [
            date(venue: "Lumen Field", city: "Seattle, WA", isHome: true),
        ])
        #expect(venue?.name == "Lumen Field")
        #expect(venue?.averageAttendance == nil)
        #expect(venue?.countedGames == 0)
    }

    @Test func cityLineJoinsWhateverShipped() {
        #expect(TeamVenue.cityLine(city: "Athens", state: "GA") == "Athens, GA")
        #expect(TeamVenue.cityLine(city: "Toronto", state: nil) == "Toronto")
        #expect(TeamVenue.cityLine(city: nil, state: nil) == nil)
        #expect(TeamVenue.cityLine(city: "  ", state: nil) == nil)
    }
}

/// All four leagues ship a venue on every competition of a team schedule,
/// which is what makes the card free. If one ever stops, these fail.
@Suite struct TeamVenuePreseasonTests {
    /// Preseason dates are exhibitions: counting them would inflate "home
    /// games" past what anyone means by it. A home *playoff* date is a real
    /// game at the real ground and stays in.
    @Test func exhibitionsDontCountAsHomeDates() throws {
        let events = try [
            scheduleEvent(seasonType: 1, venue: "Lumen Field", isHome: true, attendance: 40_000),
            scheduleEvent(seasonType: 2, venue: "Lumen Field", isHome: true, attendance: 68_000),
            scheduleEvent(seasonType: 3, venue: "Lumen Field", isHome: true, attendance: 69_000),
        ]
        let venue = try #require(ESPNMapper.homeVenue(in: events, teamId: "26"))
        #expect(venue.homeGames == 2)
        #expect(venue.averageAttendance == 68_500)
    }
}

@Suite struct TeamVenueDecodingTests {
    @Test func collegeFootballReadsSanfordStadium() throws {
        let venue = try #require(fixtureVenue("team-schedule-live", league: .collegeFootball))
        #expect(venue.name == "Sanford Stadium")
        #expect(venue.city == "Athens, GA")
        // Seven home dates; the two Mercedes-Benz games are neutral and
        // the four road trips are somebody else's.
        #expect(venue.homeGames == 7)
        #expect(venue.averageAttendance == 93_033)
    }

    @Test func theNFLReadsLumenField() throws {
        let venue = try #require(fixtureVenue("nfl-team-schedule", league: .nfl))
        #expect(venue.name == "Lumen Field")
        #expect(venue.city == "Seattle, WA")
        #expect(venue.homeGames == 2)
        #expect(venue.averageAttendance == 68_676)   // (68,752 + 68,599) / 2
    }

    @Test func theNBAReadsCryptoDotComArena() throws {
        let venue = try #require(fixtureVenue("nba-team-schedule", league: .nba))
        #expect(venue.name == "crypto.com Arena")
        #expect(venue.city == "Los Angeles, CA")
        #expect(venue.homeGames == 41)
        #expect(venue.averageAttendance == 18_855)
    }

    @Test func theNHLReadsScotiabankArena() throws {
        let venue = try #require(fixtureVenue("nhl-team-schedule", league: .nhl))
        #expect(venue.name == "Scotiabank Arena")
        #expect(venue.city == "Toronto, ON")
        #expect(venue.homeGames == 41)
        #expect(venue.averageAttendance == 18_667)
    }
}
