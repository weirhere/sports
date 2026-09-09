import Foundation
import Testing
@testable import StatSide

/// The two leagues that name a season by the year it ends, and the
/// registry that tells their scoreboards which division a team plays in.
@Suite struct SeasonYearTranslationTests {

    /// Football names a season by the year it opens; the NBA and NHL name
    /// it by the year it ends. Our axis is always the opening year, and
    /// the translation lives at the query string.
    @Test func espnNamesTheWinterSeasonsByTheYearTheyEnd() {
        #expect(League.nba.espnSeason(for: 2026) == 2027)
        #expect(League.nhl.espnSeason(for: 2026) == 2027)
        #expect(League.collegeFootball.espnSeason(for: 2026) == 2026)
        #expect(League.nfl.espnSeason(for: 2026) == 2026)
    }

    @Test func theTranslationRoundTrips() {
        for league in League.allCases {
            for year in 2014...2030 {
                #expect(league.seasonYear(fromESPN: league.espnSeason(for: year)) == year)
            }
        }
    }

    /// The two-digit pad is what keeps the decade boundary honest.
    @Test func aWinterSeasonIsLabelledAcrossBothYears() {
        #expect(League.nba.seasonLabel(2026) == "2026-27")
        #expect(League.nhl.seasonLabel(2026) == "2026-27")
        #expect(League.nba.seasonLabel(2009) == "2009-10")
        #expect(League.nhl.seasonLabel(1999) == "1999-00")
        #expect(League.collegeFootball.seasonLabel(2026) == "2026")
        #expect(League.nfl.seasonLabel(2026) == "2026")
    }
}

@Suite struct WinterRegistryTests {

    /// Every league that hardcodes a hierarchy must hold together: a team
    /// points at a real division, a division at a real conference, and the
    /// league's own id belongs to none of them. This is the test that
    /// catches a typo in a hand-copied 32-row map.
    @Test func everyRegistryIsInternallyConsistent() {
        for league in [League.nfl, .nba, .nhl] {
            let wide = Conference.leagueWideId(in: league)
            #expect(wide != nil, "\(league) should stand as one table")
            let conferences = Conference.topLevelIds(in: league)
            #expect(conferences.count == 2)
            for conference in conferences {
                #expect(Conference.tier(for: conference, in: league) == .conference)
                #expect(Conference.parent(of: conference, in: league) == nil)
                let divisions = Conference.children(of: conference, in: league)
                #expect(!divisions.isEmpty, "\(league) \(conference) should nest divisions")
                for division in divisions {
                    #expect(Conference.tier(for: division, in: league) == .division)
                    #expect(Conference.parent(of: division, in: league) == conference)
                    #expect(division != wide)
                }
            }
            #expect(Conference.tier(for: wide, in: league) == .league)
        }
    }

    /// The scoreboard payload carries no group id for any of these
    /// leagues, so a team that isn't in the table has no conference at
    /// all — which is what would put every game in "Other".
    @Test func everyTeamPointsAtADivisionThatPointsAtAConference() {
        let counts: [League: Int] = [.nfl: 32, .nba: 30, .nhl: 32]
        for (league, expected) in counts {
            let teamIds = Self.teamIds(in: league)
            #expect(teamIds.count == expected, "\(league) should carry \(expected) teams")
            for id in teamIds {
                guard let division = Conference.division(forTeamId: id, in: league) else {
                    Issue.record("\(league) team \(id) has no division")
                    continue
                }
                #expect(Conference.parent(of: division, in: league) != nil)
            }
        }
    }

    /// Ids collide across leagues by design — the NHL's league group is 9
    /// and so is the NFL's; the NBA's Pacific is 4 and so is the AFC East
    /// and the Big 12. `ConferenceID` is what keeps them apart.
    @Test func collidingIdsStayApartAcrossLeagues() {
        #expect(Conference.name(for: .nhl(9)) == "NHL")
        #expect(Conference.name(for: .nfl(9)) == "NFL")
        #expect(Conference.name(for: .nba(4)) == "Pacific (Western)")
        #expect(Conference.name(for: .nfl(4)) == "AFC East")
        #expect(Conference.name(for: .cfb(4)) == "Big 12")
        #expect(ConferenceID.nhl(9) != ConferenceID.nfl(9))
        #expect(ConferenceID.nba(7).token == "nba-7")
        #expect(ConferenceID(token: "nhl-7") == .nhl(7))
    }

    /// Following a conference has to reach a game, and the scoreboard only
    /// ever gives us the team — so the walk-up from team to division to
    /// conference to league is the whole mechanism.
    @Test func aTeamsChainReachesItsConferenceAndItsLeague() {
        // Toronto (21) plays in the Atlantic (32), in the East (7), in the NHL (9).
        let division = Conference.division(forTeamId: "21", in: .nhl)
        #expect(division == 32)
        #expect(Conference.chain(for: .nhl(32)) == [.nhl(32), .nhl(7), .nhl(9)])
        // The Lakers (13) play in the Pacific (4), in the West (6), in the NBA (7).
        #expect(Conference.division(forTeamId: "13", in: .nba) == 4)
        #expect(Conference.chain(for: .nba(4)) == [.nba(4), .nba(6), .nba(7)])
    }

    /// A division wears its conference's mark, which is how a row says
    /// which half of the league it belongs to — the AFC's shield on AFC
    /// East, the Eastern Conference's on the Atlantic.
    @Test func divisionsWearTheirConferencesMark() {
        #expect(Conference.logoURL(for: .nba(5))?.absoluteString.hasSuffix("/nba/500/east.png") == true)
        #expect(Conference.logoURL(for: .nba(6))?.absoluteString.hasSuffix("/nba/500/west.png") == true)
        // Atlantic (1) sits under the East, Pacific (4) under the West.
        #expect(Conference.logoURL(for: .nba(1)) == Conference.logoURL(for: .nba(5)))
        #expect(Conference.logoURL(for: .nba(4)) == Conference.logoURL(for: .nba(6)))
        #expect(Conference.logoURL(for: .nfl(8))?.absoluteString.hasSuffix("/afc.png") == true)
        #expect(Conference.logoURL(for: .nfl(4)) == Conference.logoURL(for: .nfl(8)))
    }

    /// The NHL publishes no conference marks at all, so its rows wear the
    /// league's shield rather than the football glyph. A league that
    /// *does* publish them and is missing one still shows nothing.
    @Test func aLeagueWithNoConferenceMarksWearsItsOwnShield() {
        #expect(Conference.logoURL(for: .nhl(7)) == League.nhl.logoURL)
        #expect(Conference.logoURL(for: .nhl(8)) == League.nhl.logoURL)
        // A division inherits its conference's, which is the league's here.
        #expect(Conference.logoURL(for: .nhl(32)) == League.nhl.logoURL)
        #expect(Conference.logoURL(for: .nba(999)) == nil)
        // FCS's United Athletic is one missing mark in a league that
        // publishes the rest — still nothing, never a stand-in.
        #expect(Conference.logoURL(for: .cfb(177)) == nil)
    }

    /// The shapes these leagues do *not* have, asserted so nothing quietly
    /// grows one: no poll, no FBS/FCS divisions, no whole-season slate,
    /// and no week to group a Games tab by.
    @Test func theWinterLeaguesHaveNoFootballShapes() {
        for league in [League.nba, .nhl] {
            #expect(!league.hasPoll)
            #expect(!league.hasWeeks)
            #expect(!league.hasCollegeDivisions)
            #expect(!league.canTableAWholeSeason)
            #expect(!league.slateSplitsByConference)
            #expect(Conference.division(for: 5, in: league) == nil)
            #expect(!Conference.titleGameIsTopTwo(id: 5, year: 2026, in: league))
        }
    }

    /// A division row says which conference it is in one way or the
    /// other: the NBA's wear the Eastern or Western mark, and the NHL's —
    /// whose conferences ESPN gives no mark at all — carry the name as a
    /// caption instead. The NFL needs neither: "AFC East" says it.
    /// A division's name says which conference it is in, because half of
    /// them are named for a compass point that doesn't: the NBA's Atlantic
    /// and the NHL's sit in different conferences of different sports.
    @Test func aDivisionsNamePlacesItInItsConference() {
        // Rendered with ESPN's short form, but tested against the full
        // one — "Southeast" contains "east", and testing the short form
        // would drop the qualifier from every compass division.
        #expect(Conference.name(for: .nba(1)) == "Atlantic (Eastern)")
        #expect(Conference.name(for: .nba(2)) == "Central (Eastern)")
        #expect(Conference.name(for: .nba(9)) == "Southeast (Eastern)")
        #expect(Conference.name(for: .nba(11)) == "Northwest (Western)")
        #expect(Conference.name(for: .nba(4)) == "Pacific (Western)")
        #expect(Conference.name(for: .nba(10)) == "Southwest (Western)")
        #expect(Conference.name(for: .nhl(32)) == "Atlantic (Eastern)")
        #expect(Conference.name(for: .nhl(30)) == "Pacific (Western)")

        // The conferences themselves are not qualified, and neither is a
        // league.
        #expect(Conference.name(for: .nhl(7)) == "Eastern")
        #expect(Conference.name(for: .nba(7)) == "NBA")

        // The NFL's own names already carry it, so nothing is added; and
        // college football has no divisions to qualify.
        #expect(Conference.name(for: .nfl(4)) == "AFC East")
        #expect(Conference.name(for: .nfl(3)) == "NFC West")
        #expect(Conference.name(for: .cfb(8)) == "SEC")
    }

    /// FBS and FCS are groups now: each heads its own list on the tables
    /// hub and each has a page, the way a league leads its conferences.
    @Test func collegeFootballsDivisionsAreGroupsOfTheirOwn() {
        for division in [Conference.Division.fbs, .fcs] {
            let id = Conference.divisionRoot(division)
            #expect(Conference.isDivisionRoot(id.id, in: .collegeFootball))
            #expect(Conference.isKnown(id.id, in: .collegeFootball))
            // The rung a league sits at — it leads a list of conferences.
            #expect(Conference.tier(for: id.id, in: .collegeFootball) == .league)
            // And it belongs to its own division, which is what sends the
            // page's standings request to the right group.
            #expect(Conference.division(for: id.id, in: .collegeFootball) == division)
            // FBS and FCS are the sport, sliced — they wear its mark.
            #expect(Conference.logoURL(for: id) == League.collegeFootball.logoURL)
        }
        #expect(Conference.name(for: .cfb(80)) == "FBS")
        #expect(Conference.name(for: .cfb(81)) == "FCS")

        // A root is not a conference in either list, so it can never be
        // mistaken for one when the lists are built.
        #expect(!Conference.orderedIds(in: .fbs).contains(80))
        #expect(!Conference.orderedIds(in: .fcs).contains(81))

        // Nothing above them: college football keeps no table of its own,
        // which is why its pages offer no standings scope at all.
        #expect(Conference.leagueWideId(in: .collegeFootball) == nil)
        #expect(StandingsScope.scopes(for: .cfb(80)).isEmpty)
        #expect(StandingsScope.default(for: .cfb(80)) == .conference)
    }

    @Test func everyLeagueSpeaksItsOwnSport() {
        #expect(League.nba.sportSegment == "basketball")
        #expect(League.nhl.sportSegment == "hockey")
        #expect(League.collegeFootball.sportSegment == "football")
        #expect(League.nfl.sportSegment == "football")
        #expect(League.nba.periodFormat.regulationCount == 4)
        #expect(League.nhl.periodFormat.regulationCount == 3)
        #expect(League.nhl.periodFormat.shortName == "P")
        // Basketball scores ~98 times a game; a list of every bucket is
        // the box score with worse formatting.
        #expect(League.nba.scoringCardTitle == nil)
        #expect(League.nhl.scoringCardTitle == "Goals")
    }

    private static func teamIds(in league: League) -> [String] {
        switch league {
        case .nfl:
            (1...34).map(String.init).filter { $0 != "31" && $0 != "32" }
        case .nba:
            (1...30).map(String.init)
        case .nhl:
            (1...30).map(String.init).filter { $0 != "24" } + ["37", "124292", "129764"]
        case .collegeFootball:
            []
        }
    }
}
