import Foundation
import Testing
@testable import StatSide

@Suite struct LeagueTests {
    @Test func pathSegmentsAreESPNsSportSlugs() {
        #expect(League.collegeFootball.pathSegment == "college-football")
        #expect(League.nfl.pathSegment == "nfl")
    }

    /// The raw value is the persistence token — it is written into follow
    /// keys, filter tokens and deep links, so changing it silently drops
    /// everyone's follows.
    @Test func rawValuesAreTheStoredTokens() {
        #expect(League.collegeFootball.rawValue == "cfb")
        #expect(League.nfl.rawValue == "nfl")
        #expect(League(rawValue: "cfb") == .collegeFootball)
        #expect(League(rawValue: "nfl") == .nfl)
    }

    /// College football's slate is Saturday, so Sunday catches up. The NFL
    /// week runs Thursday → Monday, so Monday night is still this week and
    /// Tuesday is the dead day.
    @Test func catchUpWeekdaysMatchEachLeaguesSlate() {
        #expect(League.collegeFootball.completedWeekWeekdays == [1])
        #expect(League.nfl.completedWeekWeekdays == [2, 3])
    }

    /// College football ends in January; the NFL runs through the February
    /// Super Bowl.
    @Test func seasonRolloverFollowsEachLeaguesLastMonth() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func date(_ year: Int, _ month: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: 15))!
        }
        // January belongs to the 2026 season for both.
        #expect(SeasonYear.year(for: .collegeFootball, now: date(2027, 1), calendar: calendar) == 2026)
        #expect(SeasonYear.year(for: .nfl, now: date(2027, 1), calendar: calendar) == 2026)
        // February splits them: bowls are over, the Super Bowl is not.
        #expect(SeasonYear.year(for: .collegeFootball, now: date(2027, 2), calendar: calendar) == 2027)
        #expect(SeasonYear.year(for: .nfl, now: date(2027, 2), calendar: calendar) == 2026)
        // March is the new season for both.
        #expect(SeasonYear.year(for: .nfl, now: date(2027, 3), calendar: calendar) == 2027)
    }

    @Test func cfbSeasonKeepsItsPreLeagueBehavior() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        let january = calendar.date(from: DateComponents(year: 2027, month: 1, day: 15))!
        #expect(CFBSeason.year(for: january, calendar: calendar) == 2026)
    }
}

@Suite struct ConferenceIDTests {
    /// The collision this whole type exists for: ESPN group id 8 is the SEC
    /// in college football and the American Football Conference in the NFL.
    @Test func theSameGroupIdNamesDifferentConferencesPerLeague() {
        #expect(Conference.name(for: 8, in: .collegeFootball) == "SEC")
        #expect(Conference.name(for: 8, in: .nfl) == "AFC")
        #expect(Conference.name(for: 1, in: .collegeFootball) == "ACC")
        #expect(Conference.name(for: 1, in: .nfl) == "NFC East")
        #expect(ConferenceID.cfb(8) != ConferenceID.nfl(8))
    }

    @Test func tokensRoundTrip() {
        for id in [ConferenceID.cfb(8), .nfl(7), .cfb(151)] {
            #expect(ConferenceID(token: id.token) == id)
        }
        #expect(ConferenceID.cfb(8).token == "cfb-8")
        #expect(ConferenceID.nfl(7).token == "nfl-7")
    }

    /// Tokens written before the league axis existed are bare ids and must
    /// still read back — as college football, which is all there was.
    @Test func aBareTokenReadsAsCollegeFootball() {
        #expect(ConferenceID(token: "8") == .cfb(8))
        #expect(ConferenceID(token: "nonsense") == nil)
    }

    @Test func nflDivisionsHangUnderTheirConference() {
        #expect(Conference.topLevelIds(in: .nfl) == [8, 7])
        #expect(Conference.children(of: 8, in: .nfl).map { Conference.name(for: $0, in: .nfl) }
                == ["AFC East", "AFC North", "AFC South", "AFC West"])
        #expect(Conference.parent(of: 3, in: .nfl) == 7)   // NFC West → NFC
        // College football nests nothing.
        #expect(Conference.children(of: 8, in: .collegeFootball).isEmpty)
        #expect(Conference.parent(of: 8, in: .collegeFootball) == nil)
    }

    /// `.other` stays the unknown-id bucket in both leagues — callers use
    /// it to hide affordances.
    @Test func unknownIdsStayOtherInBothLeagues() {
        #expect(Conference.tier(for: 999, in: .collegeFootball) == .other)
        #expect(Conference.tier(for: 999, in: .nfl) == .other)
        #expect(Conference.tier(for: 8, in: .nfl) == .nflConference)
        #expect(Conference.tier(for: 3, in: .nfl) == .nflDivision)
        #expect(!Conference.isKnown(999, in: .nfl))
        #expect(Conference.isKnown(3, in: .nfl))
    }

    /// The NFL's postseason is a bracket, so the standings cut line must
    /// never claim top-two about it.
    @Test func theTitleGameCutLineIsCollegeFootballOnly() {
        #expect(Conference.titleGameIsTopTwo(id: 8, year: 2026, in: .collegeFootball))
        #expect(!Conference.titleGameIsTopTwo(id: 8, year: 2026, in: .nfl))
    }

    /// Conference marks live in different CDN buckets — `nfl_conf` 404s.
    @Test func conferenceMarksComeFromEachLeaguesBucket() {
        #expect(Conference.logoURL(for: .cfb(8))?.absoluteString
                == "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/sec.png")
        #expect(Conference.logoURL(for: .nfl(8))?.absoluteString
                == "https://a.espncdn.com/i/teamlogos/nfl/500/afc.png")
        // Divisions have no mark of their own.
        #expect(Conference.logoURL(for: .nfl(3)) == nil)
    }
}

@Suite struct DarkLogoVariantLeagueTests {
    /// Both leagues publish a 500-dark twin (NFL verified live 2026-09-05).
    @Test func bothLeaguesDeriveTheirDarkMark() {
        let cfb = URL(string: "https://a.espncdn.com/i/teamlogos/ncaa/500/130.png")!
        #expect(cfb.darkTeamLogoVariant?.absoluteString
                == "https://a.espncdn.com/i/teamlogos/ncaa/500-dark/130.png")
        let nfl = URL(string: "https://a.espncdn.com/i/teamlogos/nfl/500/sea.png")!
        #expect(nfl.darkTeamLogoVariant?.absoluteString
                == "https://a.espncdn.com/i/teamlogos/nfl/500-dark/sea.png")
    }

    /// Conference marks and off-CDN URLs still have no verified twin.
    @Test func nonTeamMarksStillDeriveNothing() {
        #expect(URL(string: "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/sec.png")!
                .darkTeamLogoVariant == nil)
        #expect(URL(string: "https://example.com/i/teamlogos/nfl/500/sea.png")!
                .darkTeamLogoVariant == nil)
    }
}
