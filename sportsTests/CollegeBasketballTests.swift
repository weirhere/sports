import Foundation
import Testing
@testable import StatSide

private final class CollegeBasketballFixtureToken {}

private func fixture(_ name: String) throws -> Data {
    let url = try #require(
        Bundle(for: CollegeBasketballFixtureToken.self).url(forResource: name, withExtension: "json"),
        "missing fixture \(name).json"
    )
    return try Data(contentsOf: url)
}

private let bothLeagues: [League] = [.mensCollegeBasketball, .womensCollegeBasketball]

/// Men's and women's college basketball (2026-11-02). Fixtures captured
/// live that day, the second night of the season: `mcbb-*` and `wcbb-*`.
@MainActor
@Suite struct CollegeBasketballLeagueTests {
    /// The raw values are persistence tokens — follow keys, filter tokens,
    /// widget snapshots — and must never change once shipped.
    /// A women's conference page wears "(W)" when the men's league has a
    /// conference by the same name — the SEC, and the Summit League under
    /// its other id — and nothing outside NCAAW is ever marked.
    @Test func womensConferencesSharingAMensNameAreMarked() {
        #expect(Conference.sharesMensName(.wcbb(23)))
        #expect(Conference.sharesMensName(.wcbb(47)))
        #expect(!Conference.sharesMensName(ConferenceID(.mensCollegeBasketball, 23)))
        #expect(!Conference.sharesMensName(.cfb(8)))
        #expect(!Conference.sharesMensName(.wcbb(9999)))
    }

    @Test func rawValuesAreTheStoredTokens() {
        #expect(League.mensCollegeBasketball.rawValue == "mcbb")
        #expect(League.womensCollegeBasketball.rawValue == "wcbb")
        #expect(League(rawValue: "mcbb") == .mensCollegeBasketball)
        #expect(League(rawValue: "wcbb") == .womensCollegeBasketball)
    }

    @Test func pathsAreESPNsSlugs() {
        #expect(League.mensCollegeBasketball.sportSegment == "basketball")
        #expect(League.mensCollegeBasketball.pathSegment == "mens-college-basketball")
        #expect(League.womensCollegeBasketball.pathSegment == "womens-college-basketball")
    }

    @Test func namesAreESPNsAndTheBroadcasts() {
        #expect(League.mensCollegeBasketball.shortName == "NCAAM")
        #expect(League.womensCollegeBasketball.shortName == "NCAAW")
        #expect(League.mensCollegeBasketball.spokenName == "Men's College Basketball")
        #expect(League.womensCollegeBasketball.spokenName == "Women's College Basketball")
    }

    /// Alphabetical by the printed name, so the two land between NCAAF and
    /// the NFL.
    @Test func displayOrderStaysAlphabetical() {
        let order = League.displayOrder.map(\.shortName)
        #expect(order.firstIndex(of: "NCAAM") == order.firstIndex(of: "NCAAF").map { $0 + 1 })
        #expect(order.firstIndex(of: "NCAAW") == order.firstIndex(of: "NCAAM").map { $0 + 1 })
        #expect(order == order.sorted())
    }

    @Test func theSportAndCollegeAxes() {
        for league in bothLeagues {
            #expect(league.isCollege)
            #expect(league.isBasketball)
            #expect(!league.isFootball)
            #expect(league.hasPoll)
            #expect(!league.hasPlayoffRanking)
            #expect(!league.hasCollegeDivisions)
            #expect(!league.hasWeeks)
            #expect(!league.playsOnASurface)
            #expect(league.divisionGroupId == 50)
            #expect(league.rosterMetric == .classYear)
            #expect(league.scoringCardTitle == nil)
            #expect(league.startNoun == "Tip-off")
        }
        #expect(League.collegeFootball.isCollege)
        #expect(League.collegeFootball.divisionGroupId == 80)
        #expect(!League.nba.isCollege)
        #expect(League.nba.divisionGroupId == nil)
    }

    /// ESPN stamps 2026-27 as 2027, like the NBA; our axis stays the
    /// opening year.
    @Test func seasonsAreNamedForTheYearTheyEnd() {
        for league in bothLeagues {
            #expect(league.espnSeason(for: 2026) == 2027)
            #expect(league.seasonYear(fromESPN: 2027) == 2026)
            #expect(league.seasonLabel(2026) == "2026-27")
        }
    }

    /// The Final Four is the first weekend of April; May is the next
    /// season's offseason.
    @Test func theSeasonRollsOverAfterApril() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        func date(_ year: Int, _ month: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: 15))!
        }
        for league in bothLeagues {
            #expect(SeasonYear.year(for: league, now: date(2026, 11), calendar: calendar) == 2026)
            #expect(SeasonYear.year(for: league, now: date(2027, 3), calendar: calendar) == 2026)
            #expect(SeasonYear.year(for: league, now: date(2027, 4), calendar: calendar) == 2026)
            #expect(SeasonYear.year(for: league, now: date(2027, 5), calendar: calendar) == 2027)
        }
    }

    /// Men play two halves, women four quarters. The status line numbers
    /// periods with ordinals, so a half reads "2nd" and the men's third
    /// period is the first overtime.
    @Test func menPlayHalvesAndWomenQuarters() {
        #expect(League.mensCollegeBasketball.periodFormat.regulationCount == 2)
        #expect(League.mensCollegeBasketball.periodFormat.longName == "HALF")
        #expect(League.womensCollegeBasketball.periodFormat.regulationCount == 4)
        #expect(GameStatus.periodLabel(2, in: .mensCollegeBasketball) == "2nd")
        #expect(GameStatus.periodLabel(3, in: .mensCollegeBasketball) == "OT")
        #expect(GameStatus.periodLabel(4, in: .mensCollegeBasketball) == "2OT")
        #expect(GameStatus.periodLabel(4, in: .womensCollegeBasketball) == "4th")
        #expect(GameStatus.periodLabel(5, in: .womensCollegeBasketball) == "OT")
        #expect(League.mensCollegeBasketball.latePeriod == 2)
        #expect(League.womensCollegeBasketball.latePeriod == 4)
    }

    @Test func scoringAlertsAreNoiseInEveryBasketballLeague() {
        for league in bothLeagues + [.nba] {
            #expect(!TeamAlert.scoring.applies(to: league))
        }
        #expect(TeamAlert.scoring.applies(to: .collegeFootball))
    }

    /// An NBA player's College row opens the school's men's basketball
    /// page; football's pros keep opening football.
    @Test func aProsCollegeOpensTheLeagueItFeedsFrom() {
        #expect(League.nba.collegeFeeder == .mensCollegeBasketball)
        #expect(League.nfl.collegeFeeder == .collegeFootball)
        #expect(League.mensCollegeBasketball.collegeFeeder == nil)
        #expect(League.mensCollegeBasketball.proAlumniLeagues == [.nba])
        // The WNBA's own, now that the app has it (2026-11-03).
        #expect(League.womensCollegeBasketball.proAlumniLeagues == [.wnba])
        #expect(League.collegeFootball.proAlumniLeagues == [.nfl, .nba, .nhl])
    }
}

@MainActor
@Suite struct CollegeBasketballConferenceTests {
    /// Conference ids are their own space: 8 is the Big 12 here, the SEC
    /// in football and the AFC in the NFL.
    @Test func idsNameDifferentConferencesPerLeague() {
        #expect(Conference.name(for: 8, in: .mensCollegeBasketball) == "Big 12")
        #expect(Conference.name(for: 8, in: .collegeFootball) == "SEC")
        #expect(Conference.name(for: 4, in: .womensCollegeBasketball) == "Big East")
        #expect(Conference.name(for: 13, in: .mensCollegeBasketball) == "MAAC")
    }

    /// The one id the two tables disagree on (probed 2026-11-02).
    @Test func theSummitLeagueIsFortyNineForMenAndFortySevenForWomen() {
        #expect(Conference.name(for: 49, in: .mensCollegeBasketball) == "Summit League")
        #expect(Conference.name(for: 47, in: .womensCollegeBasketball) == "Summit League")
        #expect(!Conference.isKnown(47, in: .mensCollegeBasketball))
        #expect(!Conference.isKnown(49, in: .womensCollegeBasketball))
    }

    @Test func theHighMajorsLeadTheList() {
        let ordered = Conference.topLevelIds(in: .mensCollegeBasketball)
        #expect(ordered.count == 32)
        #expect(Set(ordered.prefix(5)) == [2, 4, 7, 8, 23])
        #expect(Conference.tier(for: 4, in: .mensCollegeBasketball) == .power4)
        #expect(Conference.tier(for: 29, in: .mensCollegeBasketball) == .group5)
    }

    /// No Division I root: nothing sits above a basketball conference.
    @Test func aConferenceHasNoRootAboveIt() {
        #expect(Conference.root(above: .mcbb(7)) == nil)
        #expect(Conference.chain(for: .mcbb(7)) == [.mcbb(7)])
    }

    @Test func marksLiveInTheNCAAConferenceBucket() {
        #expect(Conference.logoURL(for: 4, in: .mensCollegeBasketball)?.absoluteString
            == "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/big_east.png")
        // The UAC publishes no mark, as in football.
        #expect(Conference.logoURL(for: 30, in: .womensCollegeBasketball) == nil)
    }

    @Test func conferenceTokensRoundTrip() {
        for id in [ConferenceID.mcbb(4), .wcbb(47)] {
            #expect(ConferenceID(token: id.token) == id)
        }
        #expect(ConferenceID.mcbb(4) != ConferenceID.cfb(4))
    }

    /// The collapsed-by-default rule reads the league back out of a
    /// section id.
    @Test func collegeBasketballConferenceSectionsAreRecognised() {
        #expect(UIStateStore.isCollegeBasketballConference(GameSection.conferencePrefix + ConferenceID.mcbb(2).token))
        #expect(UIStateStore.isCollegeBasketballConference(GameSection.otherPrefix + "wcbb"))
        #expect(!UIStateStore.isCollegeBasketballConference(GameSection.conferencePrefix + ConferenceID.cfb(8).token))
        #expect(!UIStateStore.isCollegeBasketballConference(GameSection.pollPrefix + "mcbb"))
    }

    /// A followed conference hoisted under Following starts open; the rest
    /// of college basketball's conferences still start closed (WEIR-93).
    @Test func followedCollegeBasketballConferenceStartsOpen() throws {
        let defaults = try #require(UserDefaults(suiteName: "followed-mcbb-\(UUID().uuidString)"))
        let store = UIStateStore(defaults: defaults)
        let id = GameSection.conferencePrefix + ConferenceID.mcbb(2).token
        var followed = GameSection(id: id, title: "ACC", games: [])
        followed.isFollowed = true
        let unfollowed = GameSection(id: id, title: "ACC", games: [])

        #expect(store.isExpanded(followed))
        #expect(!store.isExpanded(unfollowed))

        // Its own toggle and the pinch both route by the followed state.
        store.toggle(followed)
        #expect(!store.isExpanded(followed))
        store.expandAll([followed])
        #expect(store.isExpanded(followed))
        store.collapseAll([followed])
        #expect(!UIStateStore(defaults: defaults).isExpanded(followed))
        #expect(!store.isExpanded(unfollowed))
    }
}

@MainActor
@Suite struct CollegeBasketballDecodingTests {
    @Test func scoreboardsDecodeWithInlineConferencesAndRanks() throws {
        for (name, league) in [("mcbb-scoreboard", League.mensCollegeBasketball),
                               ("wcbb-scoreboard", .womensCollegeBasketball)] {
            let dto = try JSONDecoder().decode(ScoreboardDTO.self, from: fixture(name))
            let board = ESPNMapper.scoreboard(from: dto, league: league)
            #expect(board.games.count == 10, "\(name)")
            #expect(board.games.allSatisfy { $0.home.team.league == league })
            // The scoreboard ships each D-I team's conference inline.
            let carriesConference = board.games.contains { $0.home.team.conference != nil }
            #expect(carriesConference)
            // And ranks, for the Top 25 section.
            let carriesRanks = board.games.contains(where: \.involvesRankedTeam)
            #expect(carriesRanks)
        }
    }

    @Test func summariesDecodeThroughTheBasketballShape() throws {
        for (name, league, periods) in [("mcbb-summary", League.mensCollegeBasketball, 2),
                                        ("wcbb-summary", .womensCollegeBasketball, 4)] {
            let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture(name))
            let summary = ESPNMapper.gameSummary(from: dto, league: league)
            #expect(summary.status.isFinal, "\(name)")
            #expect(summary.drives.isEmpty)
            #expect(!summary.plays.isEmpty)
            #expect(!summary.boxScore.isEmpty)
            #expect(!summary.leaders.isEmpty)
            #expect(!summary.teamStats.isEmpty)
            #expect(summary.periodFormat?.regulationPeriods == periods)
            #expect(summary.home?.linescores.count == periods)
            // Every shot carries a court coordinate, so the shot map has
            // something to draw.
            #expect(summary.plays.contains { $0.isShootingPlay && $0.coordinate != nil })
            #expect(ShotMap.surface(for: league) == .court)
        }
    }

    /// Both conferences, each entry with `total` and `vsconf` — which is
    /// why the matchup card needs no second request.
    @Test func summariesCarryBothConferencesStandings() throws {
        for (name, league) in [("mcbb-summary", League.mensCollegeBasketball),
                               ("wcbb-summary", .womensCollegeBasketball)] {
            let dto = try JSONDecoder().decode(SummaryResponseDTO.self, from: fixture(name))
            let summary = ESPNMapper.gameSummary(from: dto, league: league)
            #expect(league.summaryCarriesMatchupStandings)
            // ACC and Big East, the two teams' own conferences.
            #expect(Set(summary.matchupStandings.compactMap(\.id)) == [2, 4], "\(name)")
            let teamIds = Set([summary.home?.team.id, summary.away?.team.id].compactMap(\.self))
            let rows = summary.matchupStandings.flatMap(\.entries).filter { teamIds.contains($0.team.id) }
            #expect(rows.count == 2)
            #expect(rows.allSatisfy { $0.conferenceRecord != nil && $0.overallRecord != nil })
        }
    }

    @Test func standingsMapOntoTheConferenceTable() throws {
        let inSeason = Calendar.current.date(from: DateComponents(year: 2026, month: 12, day: 15)) ?? .now
        for (name, league) in [("mcbb-standings", League.mensCollegeBasketball),
                               ("wcbb-standings", .womensCollegeBasketball)] {
            let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture(name))
            let tables = ESPNMapper.conferenceStandings(from: dto, league: league, now: inSeason)
            // The fixtures are trimmed to the ACC alone.
            #expect(tables.compactMap(\.id) == [2], "\(name)")
            #expect(tables.map(\.name) == ["ACC"])
            #expect(tables.allSatisfy { !$0.entries.isEmpty })
        }
    }

    @Test func pollsAreTheAPAndCoaches() throws {
        for name in ["mcbb-rankings", "wcbb-rankings"] {
            let dto = try JSONDecoder().decode(RankingsResponseDTO.self, from: fixture(name))
            let polls = PollScreen.displayed(ESPNMapper.polls(from: dto))
            #expect(polls.map(\.type) == ["ap", "usa"], "\(name)")
            #expect(polls.allSatisfy { $0.ranks.count == 25 })
        }
    }
}

@MainActor
@Suite struct CollegeBasketballPostseasonTests {
    /// Headlines captured live against March 2026.
    @Test func theNCAATournamentsRoundsAreNamed() {
        let cases: [(String?, String?)] = [
            ("NCAA Men's Basketball Championship - Midwest Region - First Four", "First Four"),
            ("NCAA Men's Basketball Championship - East Region - 1st Round", "First Round"),
            ("NCAA Men's Basketball Championship - West Region - 2nd Round", "Second Round"),
            ("NCAA Men's Basketball Championship - South Region - Sweet 16", "Sweet 16"),
            ("NCAA Men's Basketball Championship - West Region - Elite 8", "Elite Eight"),
            ("NCAA Men's Basketball Championship - Final Four", "Final Four"),
            ("NCAA Men's Basketball Championship - National Championship", "National Championship"),
            ("NCAA Women's Basketball Championship - Regional 4 in Sacramento - First Four", "First Four"),
            ("NCAA Women's Basketball Championship - Regional 3 in Fort Worth - Sweet 16", "Sweet 16"),
            // The other postseason events aren't the bracket.
            ("NIT - 1st Round", nil),
            ("Women's NIT - Championship", nil),
            ("WBIT - Quarterfinal", nil),
            ("College Basketball Crown - Semifinals", nil),
            (nil, nil),
            ("", nil),
        ]
        for (headline, round) in cases {
            #expect(Postseason.basketballName(headline: headline) == round, "\(headline ?? "nil")")
        }
    }

    @Test func onlyTheNCAAFinalIsTheNationalChampionship() {
        let title = TrophyKind.from(
            headline: "NCAA Men's Basketball Championship - National Championship",
            league: .mensCollegeBasketball)
        #expect(title?.singular == "National Championship")
        #expect(title?.tier == .league)
        #expect(TrophyKind.from(headline: "NIT - Championship", league: .mensCollegeBasketball) == nil)
        #expect(TrophyKind.from(headline: "College Basketball Crown Championship Game",
                                league: .mensCollegeBasketball) == nil)
        #expect(TrophyKind.from(headline: "NCAA Men's Basketball Championship - Final Four",
                                league: .mensCollegeBasketball) == nil)
    }

    @Test func aConferenceTournamentFinalIsItsTrophy() {
        let cases: [(String, String?)] = [
            ("SEC Tournament - Final", "SEC Tournament"),
            ("Atlantic 10 Championship - Final", "Atlantic 10 Championship"),
            ("America East Playoffs - Final", "America East Playoffs"),
            ("Ivy League Tournament pres. by TIAA - Final", "Ivy League Tournament"),
            ("T. Rowe Price ACC Tournament - Final", "T. Rowe Price ACC Tournament"),
            ("Big Ten Tournament - Semifinal", nil),
            ("Women's NIT - Final", nil),
        ]
        for (headline, name) in cases {
            let kind = TrophyKind.from(headline: headline, league: .womensCollegeBasketball)
            #expect(kind?.singular == name, "\(headline)")
            if name != nil { #expect(kind?.tier == .conference) }
        }
    }
}
