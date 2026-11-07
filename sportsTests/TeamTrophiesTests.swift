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

private func schedule(_ name: String, league: League) throws -> TeamSchedule {
    let dto = try JSONDecoder().decode(ScheduleResponseDTO.self, from: fixture(name))
    return ESPNMapper.teamSchedule(from: dto, league: league)
}

private func team(_ id: String, _ location: String) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: nil,
         displayName: nil, shortDisplayName: nil, logoURL: nil, conferenceId: 8)
}

private func titledGame(
    _ id: String, headline: String, day: Int,
    mineWon: Bool?, final: Bool = true, teamId: String = "61"
) -> Game {
    let mine = Competitor(
        team: team(teamId, "Mine"),
        score: mineWon == true ? 28 : 7, record: nil, rank: nil,
        isHome: true, winner: mineWon
    )
    let theirs = Competitor(
        team: team("333", "Theirs"),
        score: mineWon == true ? 7 : 28, record: nil, rank: nil,
        isHome: false, winner: mineWon.map { !$0 }
    )
    return Game(
        id: id,
        date: DateComponents(calendar: .current, year: 2025, month: 12, day: day).date,
        name: nil, shortName: nil, weekNumber: 15, seasonType: 2, headline: headline,
        status: final ? .final(detail: "Final") : .pre(detail: nil),
        home: mine, away: theirs, broadcast: nil
    )
}

private func season(_ games: [Game], year: Int = 2025) -> TeamSchedule {
    TeamSchedule(team: team("61", "Mine"), record: nil, standing: nil,
                 year: year, games: games)
}

private let national = TrophyKind(singular: "National Championship",
                                  plural: "National Championships", tier: .league)
private let sec = TrophyKind(singular: "SEC Championship",
                             plural: "SEC Championships", tier: .conference)

// MARK: - What a headline names

@Suite struct TrophyNaming {
    @Test("A league title is recognized in each league's own words")
    func leagueTitles() {
        let cfp = TrophyKind.from(headline: "College Football Playoff National Championship",
                                  league: .collegeFootball)
        #expect(cfp?.singular == "National Championship")
        #expect(cfp?.tier == .league)

        #expect(TrophyKind.from(headline: "Super Bowl LIX", league: .nfl)?.tier == .league)
        #expect(TrophyKind.from(headline: "NBA Finals", league: .nba)?.singular == "NBA Finals")
        #expect(TrophyKind.from(headline: "Stanley Cup Final",
                                league: .nhl)?.singular == "Stanley Cup")
    }

    @Test("A conference title keeps the headline's own name")
    func conferenceTitles() {
        let secKind = TrophyKind.from(headline: "SEC Championship", league: .collegeFootball)
        #expect(secKind?.singular == "SEC Championship")
        #expect(secKind?.plural == "SEC Championships")
        #expect(secKind?.tier == .conference)

        #expect(TrophyKind.from(headline: "AFC Championship", league: .nfl)?.tier == .conference)
        let east = TrophyKind.from(headline: "Eastern Conference Finals", league: .nba)
        #expect(east?.tier == .conference)
        // Already plural — appending an s would read "Conference Finalss".
        #expect(east?.plural == "Eastern Conference Finals")
    }

    /// The gate the whole feature rests on. Every string here is a real
    /// ESPN headline taken from the captured fixtures, on a game that wins
    /// nothing at all.
    @Test("A headline is not a trophy", arguments: [
        ("Aflac Kickoff", League.collegeFootball),
        ("Aer Lingus College Football Classic", League.collegeFootball),
        ("Liberty Mutual Music City Kickoff", League.collegeFootball),
        ("NFL Melbourne Game", League.nfl),
        ("NBA Cup - Group Play", League.nba),
        ("NBA Cup - Quarterfinals", League.nba),
    ])
    func brandedGamesWinNothing(headline: String, league: League) {
        #expect(TrophyKind.from(headline: headline, league: league) == nil)
    }

    @Test("Neither an empty headline nor a bare mention of the word")
    func nonTrophyEdges() {
        #expect(TrophyKind.from(headline: nil, league: .collegeFootball) == nil)
        #expect(TrophyKind.from(headline: "", league: .collegeFootball) == nil)
        #expect(TrophyKind.from(headline: "Championship Week", league: .collegeFootball) == nil)
        #expect(TrophyKind.from(headline: "Championship", league: .collegeFootball) == nil)
    }

    @Test("The NBA Cup counts only where it says it was decided")
    func nbaCupOnlyWhenDecided() {
        #expect(TrophyKind.from(headline: "NBA Cup - Championship",
                                league: .nba)?.tier == .league)
        #expect(TrophyKind.from(headline: "NBA Cup - Group Play", league: .nba) == nil)
    }

    /// "Quarterfinals" and "Semifinals" both end in "final", and the NHL
    /// spent decades calling its early rounds "Stanley Cup Quarterfinals"
    /// — so a substring test for the word hands a first-round exit the
    /// cup. Caught by running the rule over the real headlines before it
    /// ever compiled: "NBA Cup - Quarterfinals" was scoring a trophy.
    @Test("A qualified round decides nothing", arguments: [
        ("Stanley Cup Quarterfinals", League.nhl),
        ("Stanley Cup Semifinals", League.nhl),
        ("Eastern Conference Quarterfinals", League.nhl),
        ("Western Conference Semifinals", League.nba),
        ("NBA Cup - Semifinals", League.nba),
    ])
    func qualifiedRoundsDecideNothing(headline: String, league: League) {
        #expect(TrophyKind.from(headline: headline, league: league) == nil)
    }

    @Test("The deciding round is recognized either way a league spells it")
    func decidingRoundSpellings() {
        #expect(TrophyKind.from(headline: "Stanley Cup Final",
                                league: .nhl)?.singular == "Stanley Cup")
        #expect(TrophyKind.from(headline: "Stanley Cup Finals",
                                league: .nhl)?.singular == "Stanley Cup")
        #expect(TrophyKind.from(headline: "Eastern Conference Final",
                                league: .nhl)?.tier == .conference)
    }

    /// A team holds three AFC Championships, not three AFC Championship
    /// Games — so the fixture's word comes off the trophy's name.
    @Test("A title game is named after the trophy, not the fixture")
    func titleGameNamedAfterTheTrophy() {
        let afc = TrophyKind.from(headline: "AFC Championship Game", league: .nfl)
        #expect(afc?.singular == "AFC Championship")
        #expect(afc?.plural == "AFC Championships")
        #expect(afc?.tier == .conference)
    }

    @Test("A sponsored conference title still reads as one")
    func sponsoredConferenceTitle() {
        #expect(TrophyKind.from(headline: "Big Ten Championship",
                                league: .collegeFootball)?.tier == .conference)
    }

    /// The Rams' Trophies tab showed "NFC Championship 2021" and "NFC
    /// CHAMPIONSHIP 2018" as two rows each reading 1 (Andy, 2026-09-21).
    /// ESPN spells one trophy both ways across seasons.
    @Test("ESPN's shouting is not a second trophy")
    func shoutingIsNotASecondTrophy() {
        let shouted = TrophyKind.from(headline: "NFC CHAMPIONSHIP", league: .nfl)
        #expect(shouted?.singular == "NFC Championship")
        #expect(shouted?.plural == "NFC Championships")
        #expect(shouted == TrophyKind.from(headline: "NFC Championship", league: .nfl))
    }

    /// Only the common noun is re-cased. Guessing at the conference's own
    /// letters would have to tell "SEC" from "BIG TEN" on an all-caps
    /// string, and would get one of the two wrong whichever way it went —
    /// so identity carries that case instead of typography.
    @Test("A conference's own letters are left as ESPN sent them")
    func conferenceLettersAreNotGuessedAt() {
        let shouted = TrophyKind.from(headline: "BIG TEN CHAMPIONSHIP",
                                      league: .collegeFootball)
        #expect(shouted?.singular == "BIG TEN Championship")
        #expect(shouted == TrophyKind.from(headline: "Big Ten Championship",
                                           league: .collegeFootball))
    }

    /// Safe to fix outright on this path, unlike the one above: it only
    /// matches "<side> Conference Final(s)", which has no acronym in it.
    @Test("A conference final is de-shouted whole")
    func conferenceFinalDeshouted() {
        #expect(TrophyKind.from(headline: "EASTERN CONFERENCE FINALS",
                                league: .nba)?.singular == "Eastern Conference Finals")
        #expect(TrophyKind.from(headline: "Western Conference Final",
                                league: .nhl)?.singular == "Western Conference Final")
    }
}

// MARK: - The payload gap this closed

@Suite struct TrophyDecoding {
    /// The schedule path decoded no `notes` at all before this — the field
    /// is in every payload and was read on the scoreboard path only, which
    /// is what left a team's own title games unnameable on its own page.
    @Test("A team schedule now carries ESPN's printed game name")
    func scheduleCarriesHeadline() throws {
        let loaded = try schedule("team-schedule-live", league: .collegeFootball)
        let titled = loaded.games.filter { $0.headline != nil }
        #expect(titled.count == 1)
        #expect(titled.first?.headline == "SEC Championship")
    }
}

// MARK: - Deriving from a real season

@Suite struct TrophyDerivation {
    @Test("Georgia's captured season yields the SEC Championship it won")
    func realConferenceTitle() throws {
        let loaded = try schedule("team-schedule-live", league: .collegeFootball)
        let trophies = TrophyCase.derive(from: loaded, league: .collegeFootball)
        #expect(trophies.count == 1)
        let trophy = try #require(trophies.first)
        #expect(trophy.kind.singular == "SEC Championship")
        // The season is read off the payload, never off the calendar.
        #expect(trophy.year == loaded.year)
    }

    /// 82 regular-season games apiece, NBA Cup group play included.
    @Test("A regular season on its own yields nothing", arguments: [
        ("nba-team-schedule", League.nba),
        ("nhl-team-schedule", League.nhl),
    ])
    func regularSeasonsYieldNothing(name: String, league: League) throws {
        let loaded = try schedule(name, league: league)
        #expect(TrophyCase.derive(from: loaded, league: league).isEmpty)
    }
}

// MARK: - The rules

@Suite struct TrophyRules {
    @Test("A title game still to be played wins nothing")
    func scheduledTitleGameWinsNothing() {
        let games = [titledGame("1", headline: "SEC Championship", day: 6,
                                mineWon: nil, final: false)]
        #expect(TrophyCase.derive(from: season(games), league: .collegeFootball).isEmpty)
    }

    @Test("Losing the final wins nothing")
    func losingFinalWinsNothing() {
        let games = [titledGame("1", headline: "SEC Championship", day: 6, mineWon: false)]
        #expect(TrophyCase.derive(from: season(games), league: .collegeFootball).isEmpty)
    }

    /// The series rule, and the reason `derive` groups by kind before it
    /// looks at any result. Leading a series and losing it is the case a
    /// naive "won any game carrying this headline" test gets wrong.
    @Test("A series is decided by its last game, not by any win in it")
    func seriesDecidedByLastGame() {
        let led = [
            titledGame("1", headline: "NBA Finals", day: 1, mineWon: true),
            titledGame("2", headline: "NBA Finals", day: 3, mineWon: true),
            titledGame("3", headline: "NBA Finals", day: 5, mineWon: true),
            titledGame("4", headline: "NBA Finals", day: 7, mineWon: false),
            titledGame("5", headline: "NBA Finals", day: 9, mineWon: false),
            titledGame("6", headline: "NBA Finals", day: 11, mineWon: false),
            titledGame("7", headline: "NBA Finals", day: 13, mineWon: false),
        ]
        #expect(TrophyCase.derive(from: season(led), league: .nba).isEmpty)

        // Clinched in six: the last game played is the one that was won.
        let won = Array(led.prefix(5)) + [
            titledGame("6", headline: "NBA Finals", day: 11, mineWon: true),
        ]
        #expect(TrophyCase.derive(from: season(won), league: .nba).count == 1)
    }

    @Test("A game the team wasn't in never counts")
    func othersTitlesDontCount() {
        let games = [titledGame("1", headline: "SEC Championship", day: 6,
                                mineWon: true, teamId: "999")]
        #expect(TrophyCase.derive(from: season(games), league: .collegeFootball).isEmpty)
    }
}

// MARK: - Assembling the shelf

@Suite struct TrophyShelf {
    @Test("League titles lead, and the most-won trophy leads its tier")
    func shelfOrder() {
        let shelf = TrophyCase.assemble(
            derived: [Trophy(kind: sec, year: 2017), Trophy(kind: sec, year: 2022),
                      Trophy(kind: national, year: 2021)],
            registry: [], allTimeKinds: [], derivedFloor: 2014
        )
        #expect(shelf.groups.map(\.kind.singular)
            == ["National Championship", "SEC Championship"])
        // Singular at one, plural above it.
        #expect(shelf.groups.first?.title == "National Championship")
        #expect(shelf.groups.last?.title == "SEC Championships")
        #expect(shelf.groups.last?.years == [2022, 2017])
    }

    @Test("A title both sources know about is one row, not two")
    func overlapDedupes() {
        let shelf = TrophyCase.assemble(
            derived: [Trophy(kind: national, year: 2021)],
            registry: [Trophy(kind: national, year: 2021),
                       Trophy(kind: national, year: 1980)],
            allTimeKinds: ["national championship"], derivedFloor: 2014
        )
        #expect(shelf.groups.count == 1)
        #expect(shelf.groups.first?.years == [2021, 1980])
        #expect(shelf.groups.first?.count == 2)
    }

    /// The bug that reported all of this: the count read 1 and 1 where the
    /// shelf holds two of one thing, because the 2018 season shouts and the
    /// 2021 season does not.
    @Test("Two spellings of one trophy are one row")
    func spellingsMerge() throws {
        let shouted = try #require(TrophyKind.from(headline: "NFC CHAMPIONSHIP",
                                                   league: .nfl))
        let calm = try #require(TrophyKind.from(headline: "NFC Championship",
                                                league: .nfl))
        let shelf = TrophyCase.assemble(
            derived: [Trophy(kind: shouted, year: 2018), Trophy(kind: calm, year: 2021)],
            registry: [], allTimeKinds: [], derivedFloor: 2014
        )
        #expect(shelf.groups.count == 1)
        #expect(shelf.groups.first?.years == [2021, 2018])
        #expect(shelf.groups.first?.title == "NFC Championships")
    }

    /// Which letters survive a merge is a rule, not a race — the derived
    /// seasons arrive in no fixed order, so arrival order must not decide.
    @Test("The merged spelling is chosen by rule, not by arrival order")
    func mergedSpellingIsDeterministic() {
        let loud = TrophyKind(singular: "BIG TEN Championship",
                              plural: "BIG TEN Championships", tier: .conference)
        let calm = TrophyKind(singular: "Big Ten Championship",
                              plural: "Big Ten Championships", tier: .conference)
        for derived in [[Trophy(kind: loud, year: 2018), Trophy(kind: calm, year: 2021)],
                        [Trophy(kind: calm, year: 2021), Trophy(kind: loud, year: 2018)]] {
            let shelf = TrophyCase.assemble(derived: derived, registry: [],
                                            allTimeKinds: [], derivedFloor: 2014)
            #expect(shelf.groups.count == 1)
            #expect(shelf.groups.first?.kind.singular == "Big Ten Championship")
        }
    }

    /// The caption is the honesty gate on a count. A trophy the registry
    /// does not speak for is only as old as the derivation, however old
    /// its oldest known win happens to be.
    @Test("Coverage is what the registry claims, never what the rows imply")
    func coverageComesFromTheRegistry() {
        let derivedOnly = TrophyCase.assemble(
            derived: [Trophy(kind: national, year: 2021)],
            registry: [], allTimeKinds: [], derivedFloor: 2014
        )
        #expect(derivedOnly.groups.first?.coverage == .since(2014))
        #expect(derivedOnly.coverageFloor == 2014)

        let covered = TrophyCase.assemble(
            derived: [Trophy(kind: national, year: 2021)],
            registry: [Trophy(kind: national, year: 1980)],
            allTimeKinds: ["national championship"], derivedFloor: 2014
        )
        #expect(covered.groups.first?.coverage == .allTime)
        #expect(covered.coverageFloor == nil)
    }

    @Test("A conference title stays scoped even when the league title is all-time")
    func mixedCoverage() {
        let shelf = TrophyCase.assemble(
            derived: [Trophy(kind: national, year: 2021), Trophy(kind: sec, year: 2022)],
            registry: [Trophy(kind: national, year: 1980)],
            allTimeKinds: ["national championship"], derivedFloor: 2014
        )
        #expect(shelf.groups.first?.coverage == .allTime)
        #expect(shelf.groups.last?.coverage == .since(2014))
        #expect(shelf.coverageFloor == 2014)
    }

    @Test("An empty shelf is empty")
    func emptyShelf() {
        let shelf = TrophyCase.assemble(derived: [], registry: [],
                                        allTimeKinds: [], derivedFloor: 2014)
        #expect(shelf.isEmpty)
        #expect(shelf.coverageFloor == nil)
    }
}

// MARK: - The registry's gate

@Suite struct TrophyRegistryGate {
    /// A league without a list contributes nothing and claims nothing:
    /// nothing reads as all-time that the registry doesn't speak for.
    @Test("A league with no list contributes nothing and claims nothing")
    func unpopulatedLeaguesAreGated() {
        for league in League.allCases where ![.collegeFootball, .nfl, .nba].contains(league) {
            #expect(TrophyRegistry.trophies(teamId: "61", league: league).isEmpty)
            #expect(TrophyRegistry.coveredKinds(in: league).isEmpty)
            #expect(TrophyRegistry.sources(in: league).isEmpty)
        }
    }

    /// The other half of the gate: a list's rows are read only once it is
    /// marked verified.
    @Test("College football's list is the verified one, and it names its source")
    func collegeFootballIsCovered() {
        #expect(TrophyRegistry.collegeFootballNationalTitles.verified)
        #expect(TrophyRegistry.coveredKinds(in: .collegeFootball) == ["national championship"])
        #expect(TrophyRegistry.sources(in: .collegeFootball)
            == ["national championship": "AP poll 1936–97 · title game since 1998"])
    }

    /// A Larry O'Brien Trophy is won on the court, so the NBA's list names
    /// no selector and its caption carries none.
    @Test("The NBA's list is verified and names no source")
    func nbaIsCovered() {
        #expect(TrophyRegistry.nbaChampionships.verified)
        #expect(TrophyRegistry.coveredKinds(in: .nba) == ["nba finals"])
        #expect(TrophyRegistry.sources(in: .nba).isEmpty)
    }
}

// MARK: - College football's honour roll (COR-97)

/// Every program's ESPN id, by the `location` ESPN prints for it, read off
/// the captured FBS standings — so a test written in school names checks the
/// ids as well as the counts, and a mistyped id fails as a wrong total rather
/// than passing as someone else's title.
private func fbsIds() throws -> [String: String] {
    let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("standings-live"))
    let teams = ESPNMapper.conferences(from: dto).flatMap(\.teams)
    var ids: [String: String] = [:]
    for team in teams { ids[team.location] = team.id }
    return ids
}

/// The per-school totals, derived independently of the rows: the AP
/// National Championship Trophy's own by-team table, cut at 2013 and adjusted
/// for the only two seasons where the BCS game and the AP disagree — 2003 (AP
/// USC, BCS LSU) and 2004 (vacated). An omitted, duplicated or misattributed
/// season moves at least one of these.
private let cfbTotals: [(String, Int)] = [
    ("Alabama", 9), ("Notre Dame", 8), ("Oklahoma", 7), ("Miami", 5),
    ("Ohio State", 4), ("Minnesota", 4), ("Nebraska", 4),
    ("USC", 3), ("LSU", 3), ("Texas", 3), ("Florida", 3), ("Florida State", 3),
    ("Michigan", 2), ("Tennessee", 2), ("Auburn", 2), ("Army", 2),
    ("Penn State", 2), ("Pittsburgh", 2),
    ("Georgia", 1), ("Clemson", 1), ("BYU", 1), ("Colorado", 1),
    ("Maryland", 1), ("Michigan State", 1), ("Syracuse", 1),
    ("TCU", 1), ("Texas A&M", 1),
]

private var cfbTitles: [Int: String] { TrophyRegistry.collegeFootballNationalTitles.winners }

@Suite struct CollegeFootballTitles {
    /// The rule (COR-94): one winner a season, from 1936, the AP's pick
    /// through 1997 and the BCS game through 2013 — with 2004, USC's
    /// vacated title, left empty. Seventy-eight seasons less that one.
    @Test("Every season from 1936 to 2013 has one champion, except vacated 2004")
    func seasonSpan() {
        let expected = Set(1936...2013).subtracting([2004])
        #expect(Set(cfbTitles.keys) == expected)
        #expect(cfbTitles.count == 77)
    }

    /// The registry stops where the derivation starts, so the CFP era is
    /// only ever the wire's answer — never a hand-kept row that could
    /// disagree with it.
    @Test("No row reaches the derived era")
    func stopsAtTheSeasonFloor() {
        #expect(cfbTitles.keys.allSatisfy { $0 < League.collegeFootball.seasonFloor })
    }

    @Test("Every winner is a program the FBS standings know")
    func everyIdResolves() throws {
        let known = Set(try fbsIds().values)
        #expect(Set(cfbTitles.values).isSubset(of: known))
    }

    @Test("Each program's total matches the source", arguments: cfbTotals)
    func perProgramTotals(location: String, titles: Int) throws {
        let id = try #require(try fbsIds()[location], "no FBS program at \(location)")
        #expect(TrophyRegistry.trophies(teamId: id, league: .collegeFootball).count == titles)
    }

    /// The totals above, summed, are the whole list — so no row is filed
    /// under a program the table above doesn't name.
    @Test("The listed programs account for every row")
    func totalsAccountForEveryRow() {
        #expect(cfbTotals.map(\.1).reduce(0, +) == cfbTitles.count)
    }

    @Test("The famous split seasons resolve to the AP's pick")
    func splitSeasonsAreTheAPs() throws {
        let ids = try fbsIds()
        #expect(cfbTitles[1997] == ids["Michigan"])   // coaches: Nebraska
        #expect(cfbTitles[1970] == ids["Nebraska"])   // UPI: Texas
        #expect(cfbTitles[1990] == ids["Colorado"])   // UPI: Georgia Tech
        #expect(cfbTitles[2003] == ids["LSU"])        // BCS era: the game, not the AP's USC
    }

    /// Alabama end to end, as its page assembles it: nine registry titles
    /// and the two CFP games the wire derives (2015, 2017) on one row,
    /// all-time, saying what it counts by.
    @Test("A registry title and a derived one land on the same row")
    func alabamaShelf() throws {
        let alabama = try #require(try fbsIds()["Alabama"])
        let derived = [Trophy(kind: national, year: 2015), Trophy(kind: national, year: 2017),
                       Trophy(kind: sec, year: 2023)]
        let shelf = TrophyCase.assemble(
            derived: derived,
            registry: TrophyRegistry.trophies(teamId: alabama, league: .collegeFootball),
            allTimeKinds: TrophyRegistry.coveredKinds(in: .collegeFootball),
            derivedFloor: League.collegeFootball.seasonFloor,
            sources: TrophyRegistry.sources(in: .collegeFootball)
        )
        let titles = try #require(shelf.groups.first)
        #expect(titles.title == "National Championships")
        #expect(titles.count == 11)
        #expect(titles.years.first == 2017)
        #expect(titles.years.last == 1961)
        #expect(titles.coverage == .allTime)
        #expect(titles.source == "AP poll 1936–97 · title game since 1998")
        // The conference row stays scoped and carries no source.
        #expect(shelf.groups.last?.coverage == .since(2014))
        #expect(shelf.groups.last?.source == nil)
    }
}

// MARK: - The NFL's honour rolls (COR-98)

/// Every NFL team's ESPN id by its abbreviation, read off the captured
/// `nfl/teams` payload — the NFL twin of `fbsIds()`, so a mistyped id fails
/// as a wrong total rather than passing as another franchise's title.
private func nflIds() throws -> [String: String] {
    let dto = try JSONDecoder().decode(TeamsResponseDTO.self, from: fixture("nfl-teams"))
    var ids: [String: String] = [:]
    for team in ESPNMapper.teamsById(from: dto, league: .nfl).values {
        if let abbreviation = team.abbreviation { ids[abbreviation] = team.id }
    }
    return ids
}

/// Pre-Super-Bowl titles by today's franchise, counted from Wikipedia's
/// year-by-year list rather than from the rows. Ten franchises, forty
/// seasons: the other six of 1920–1965 went to teams with no successor.
private let nflChampionshipTotals: [(String, Int)] = [
    ("GB", 9), ("CHI", 8), ("NYG", 4), ("DET", 4), ("CLE", 4),
    ("PHI", 3), ("IND", 2), ("ARI", 2), ("LAR", 2), ("WSH", 2),
]

/// Super Bowls I–XLVIII by today's franchise, counted the same way.
private let superBowlTotals: [(String, Int)] = [
    ("PIT", 6), ("SF", 5), ("DAL", 5), ("GB", 4), ("NYG", 4),
    ("NE", 3), ("WSH", 3), ("LV", 3), ("DEN", 2), ("MIA", 2),
    ("BAL", 2), ("IND", 2), ("NYJ", 1), ("KC", 1), ("CHI", 1),
    ("TB", 1), ("NO", 1), ("SEA", 1), ("LAR", 1),
]

private let superBowl = TrophyKind(singular: "Super Bowl", plural: "Super Bowls", tier: .league)
private let afc = TrophyKind(singular: "AFC Championship",
                             plural: "AFC Championships", tier: .conference)

private func nflCount(_ list: TrophyRegistry.TitleList, _ abbreviation: String) throws -> Int {
    let id = try #require(try nflIds()[abbreviation], "no NFL team \(abbreviation)")
    return list.winners.values.filter { $0 == id }.count
}

private func nflShelf(_ abbreviation: String, derived: [Trophy] = []) throws -> TrophyCase {
    let id = try #require(try nflIds()[abbreviation])
    return TrophyCase.assemble(
        derived: derived,
        registry: TrophyRegistry.trophies(teamId: id, league: .nfl),
        allTimeKinds: TrophyRegistry.coveredKinds(in: .nfl),
        derivedFloor: League.nfl.seasonFloor,
        sources: TrophyRegistry.sources(in: .nfl)
    )
}

@Suite struct NFLTitles {
    private var championships: [Int: String] { TrophyRegistry.nflChampionships.winners }
    private var superBowls: [Int: String] { TrophyRegistry.superBowls.winners }

    /// COR-94: 1920–1965 only, so no season holds both an NFL Championship
    /// and a Super Bowl, and the six seasons whose champion has no
    /// successor are left empty.
    @Test("NFL Championships span 1920–65, less the six defunct champions")
    func championshipSpan() {
        let defunct: Set = [1920, 1922, 1923, 1924, 1926, 1928]
        #expect(Set(championships.keys) == Set(1920...1965).subtracting(defunct))
        #expect(championships.count == 40)
    }

    @Test("Super Bowls run 1966–2013, one a season, and stop at the floor")
    func superBowlSpan() {
        #expect(Set(superBowls.keys) == Set(1966...2013))
        #expect(superBowls.keys.allSatisfy { $0 < League.nfl.seasonFloor })
    }

    @Test("Every winner is a team ESPN knows")
    func everyIdResolves() throws {
        let known = Set(try nflIds().values)
        #expect(known.count == 32)
        #expect(Set(championships.values).union(superBowls.values).isSubset(of: known))
    }

    @Test("Each franchise's NFL Championships match the source", arguments: nflChampionshipTotals)
    func perFranchiseChampionships(abbreviation: String, titles: Int) throws {
        #expect(try nflCount(TrophyRegistry.nflChampionships, abbreviation) == titles)
    }

    @Test("Each franchise's Super Bowls match the source", arguments: superBowlTotals)
    func perFranchiseSuperBowls(abbreviation: String, titles: Int) throws {
        #expect(try nflCount(TrophyRegistry.superBowls, abbreviation) == titles)
    }

    @Test("The listed franchises account for every row")
    func totalsAccountForEveryRow() {
        #expect(nflChampionshipTotals.map(\.1).reduce(0, +) == championships.count)
        #expect(superBowlTotals.map(\.1).reduce(0, +) == superBowls.count)
    }

    /// The third call, case by case: a title follows the franchise through a
    /// move, and never follows a name to a team that only took it.
    @Test("Titles follow the franchise, not the city")
    func titlesFollowTheFranchise() throws {
        let ids = try nflIds()
        #expect(championships[1945] == ids["LAR"])   // Cleveland Rams
        #expect(championships[1958] == ids["IND"])   // Baltimore Colts
        #expect(championships[1925] == ids["ARI"])   // Chicago Cardinals
        #expect(superBowls[1970] == ids["IND"])      // Baltimore Colts
        #expect(superBowls[1999] == ids["LAR"])      // St. Louis Rams
        #expect(superBowls[1983] == ids["LV"])       // Los Angeles Raiders
        // The Browns' history stayed in Cleveland; the Ravens hold only theirs.
        #expect(try nflCount(TrophyRegistry.nflChampionships, "BAL") == 0)
    }

    @Test("Both lists are verified, covered, and carry no source")
    func nflIsCovered() {
        #expect(TrophyRegistry.superBowls.verified)
        #expect(TrophyRegistry.nflChampionships.verified)
        #expect(TrophyRegistry.coveredKinds(in: .nfl) == ["super bowl", "nfl championship"])
        #expect(TrophyRegistry.sources(in: .nfl).isEmpty)
    }

    /// The decision's own check: Packers 9 + 4 = 13, their own count, on two
    /// all-time rows — the most-won leads its tier.
    @Test("The Packers' shelf reads nine and four")
    func packersShelf() throws {
        let shelf = try nflShelf("GB")
        #expect(shelf.groups.map(\.title) == ["NFL Championships", "Super Bowls"])
        #expect(shelf.groups.map(\.count) == [9, 4])
        #expect(shelf.groups.allSatisfy { $0.coverage == .allTime })
        #expect(shelf.coverageFloor == nil)
    }

    @Test("The Steelers hold six Super Bowls and no NFL Championship")
    func steelersShelf() throws {
        let shelf = try nflShelf("PIT")
        #expect(shelf.groups.map(\.title) == ["Super Bowls"])
        #expect(shelf.groups.first?.count == 6)
    }

    /// The Patriots end to end: three registry Super Bowls and the three the
    /// wire derives (2014, 2016, 2018) on one all-time row; the AFC title
    /// stays scoped to the derivation.
    @Test("A registry Super Bowl and a derived one land on the same row")
    func patriotsShelf() throws {
        let derived = [Trophy(kind: superBowl, year: 2014), Trophy(kind: superBowl, year: 2016),
                       Trophy(kind: superBowl, year: 2018), Trophy(kind: afc, year: 2017)]
        let shelf = try nflShelf("NE", derived: derived)
        let titles = try #require(shelf.groups.first)
        #expect(titles.title == "Super Bowls")
        #expect(titles.years == [2018, 2016, 2014, 2004, 2003, 2001])
        #expect(titles.coverage == .allTime)
        #expect(shelf.groups.last?.coverage == .since(2014))
    }
}

// MARK: - The NBA's honour roll (COR-99)

/// Every NBA team's ESPN id, by the abbreviation ESPN prints for it, read off
/// the captured standings — so the totals below are written in franchises
/// and a mistyped id fails as a wrong count, not as someone else's title.
private func nbaIds() throws -> [String: String] {
    let dto = try JSONDecoder().decode(StandingsResponseDTO.self, from: fixture("nba-standings"))
    let teams = ESPNMapper.conferences(from: dto, league: .nba).flatMap(\.teams)
    var ids: [String: String] = [:]
    for team in teams { if let abbreviation = team.abbreviation { ids[abbreviation] = team.id } }
    return ids
}

private let nbaFinals = TrophyKind(singular: "NBA Finals", plural: "NBA Finals", tier: .league)

/// Each franchise's titles through 2013–14, from the NBA's own champions
/// table, with relocations carried (Minneapolis to the Lakers, Rochester to
/// the Kings, Syracuse to the 76ers, Philadelphia to the Warriors, St. Louis
/// to the Hawks, the Bullets to the Wizards, Seattle to the Thunder). A
/// dropped, doubled or misfiled season moves at least one of these.
private let nbaTotals: [(String, Int)] = [
    ("BOS", 17), ("LAL", 16), ("CHI", 6), ("SA", 5),
    ("GS", 3), ("PHI", 3), ("DET", 3), ("MIA", 3),
    ("NY", 2), ("HOU", 2),
    ("ATL", 1), ("SAC", 1), ("MIL", 1), ("POR", 1), ("WSH", 1), ("OKC", 1), ("DAL", 1),
]

private var nbaTitles: [Int: String] { TrophyRegistry.nbaChampionships.winners }

@Suite struct NBATitles {
    /// The BAA's first season through the last before the derivation's
    /// floor, less 1947–48: the original Baltimore Bullets have no successor.
    @Test("Every season from 1946–47 to 2013–14 has one champion, except 1947–48")
    func seasonSpan() {
        let expected = Set(1946..<League.nba.seasonFloor).subtracting([1947])
        #expect(Set(nbaTitles.keys) == expected)
        #expect(nbaTitles.count == 67)
    }

    @Test("Every winner is a current NBA team")
    func everyIdResolves() throws {
        let known = Set(try nbaIds().values)
        #expect(known.count == 30)
        #expect(Set(nbaTitles.values).isSubset(of: known))
    }

    @Test("Each franchise's total matches the source", arguments: nbaTotals)
    func perFranchiseTotals(abbreviation: String, titles: Int) throws {
        let id = try #require(try nbaIds()[abbreviation], "no NBA team \(abbreviation)")
        #expect(TrophyRegistry.trophies(teamId: id, league: .nba).count == titles)
    }

    @Test("The listed franchises account for every row")
    func totalsAccountForEveryRow() {
        #expect(nbaTotals.map(\.1).reduce(0, +) == nbaTitles.count)
    }

    /// COR-94's third call, season by season.
    @Test("Relocated titles follow the franchise")
    func titlesFollowTheFranchise() throws {
        let ids = try nbaIds()
        #expect(nbaTitles[1948] == ids["LAL"])   // Minneapolis Lakers
        #expect(nbaTitles[1950] == ids["SAC"])   // Rochester Royals
        #expect(nbaTitles[1954] == ids["PHI"])   // Syracuse Nationals
        #expect(nbaTitles[1946] == ids["GS"])    // Philadelphia Warriors
        #expect(nbaTitles[1957] == ids["ATL"])   // St. Louis Hawks
        #expect(nbaTitles[1977] == ids["WSH"])   // Washington Bullets
        #expect(nbaTitles[1978] == ids["OKC"])   // Seattle SuperSonics
        #expect(nbaTitles[1947] == nil)          // original Baltimore Bullets
    }

    /// The Celtics end to end, as their page assembles it: seventeen
    /// registry titles and 2023–24 off the wire make the eighteen COR-94
    /// names, all-time and with no source line.
    @Test("The Celtics' shelf reads 18, all-time")
    func celticsShelf() throws {
        let celtics = try #require(try nbaIds()["BOS"])
        let shelf = TrophyCase.assemble(
            derived: [Trophy(kind: nbaFinals, year: 2023)],
            registry: TrophyRegistry.trophies(teamId: celtics, league: .nba),
            allTimeKinds: TrophyRegistry.coveredKinds(in: .nba),
            derivedFloor: League.nba.seasonFloor,
            sources: TrophyRegistry.sources(in: .nba)
        )
        let titles = try #require(shelf.groups.first)
        #expect(titles.title == "NBA Finals")
        #expect(titles.count == 18)
        #expect(titles.years.first == 2023)
        #expect(titles.years.last == 1956)
        #expect(titles.coverage == .allTime)
        #expect(titles.source == nil)
    }

    /// The Lakers' 2019–20 title comes off the wire; a registry row for a
    /// derived season (none today) would merge rather than double.
    @Test("The Lakers' shelf reads 17, and an overlapping season counts once")
    func lakersShelf() throws {
        let lakers = try #require(try nbaIds()["LAL"])
        let shelf = TrophyCase.assemble(
            derived: [Trophy(kind: nbaFinals, year: 2019), Trophy(kind: nbaFinals, year: 2009)],
            registry: TrophyRegistry.trophies(teamId: lakers, league: .nba),
            allTimeKinds: TrophyRegistry.coveredKinds(in: .nba),
            derivedFloor: League.nba.seasonFloor
        )
        #expect(shelf.groups.first?.count == 17)
    }
}

// MARK: - The wire's own postseason wording

/// Every headline here is verbatim from a live probe of ESPN's team
/// schedules (2026-11-06, seasontype 3 and the in-season cups), across
/// both of its spellings eras where it has two. Before this suite, the
/// pro leagues' trophy wording was reasoned rather than seen, and the
/// reasoning was wrong twice: the NHL's title carries a " - Game N" tail
/// the round test read as the last word, and neither league's conference
/// round says "Conference" any more.
@Suite struct ProPostseasonHeadlines {
    @Test("Each league's title and conference round, as ESPN prints them", arguments: [
        ("Super Bowl LIX", League.nfl, "Super Bowl"),
        ("Super Bowl XLIX", League.nfl, "Super Bowl"),
        ("AFC Championship", League.nfl, "AFC Championship"),
        ("AFC CHAMPIONSHIP", League.nfl, "AFC Championship"),
        ("NBA Finals - Game 5", League.nba, "NBA Finals"),
        ("NBA FINALS - GAME 7", League.nba, "NBA Finals"),
        ("East Finals - Game 4", League.nba, "Eastern Conference Finals"),
        ("West Finals - Game 5", League.nba, "Western Conference Finals"),
        ("EASTERN CONFERENCE FINALS - GAME 6", League.nba, "Eastern Conference Finals"),
        ("WESTERN CONFERENCE FINALS - GAME 5", League.nba, "Western Conference Finals"),
        ("NBA Cup Championship", League.nba, "NBA Cup"),
        ("NBA In-Season Tournament Championship", League.nba, "NBA Cup"),
        ("Stanley Cup Final - Game 6", League.nhl, "Stanley Cup"),
        ("STANLEY CUP FINAL - GAME 6", League.nhl, "Stanley Cup"),
        ("East Final - Game 5", League.nhl, "Eastern Conference Final"),
        ("West Final - Game 6", League.nhl, "Western Conference Final"),
        ("WESTERN CONFERENCE FINALS - GAME 7", League.nhl, "Western Conference Final"),
        ("World Series - Game 5", League.mlb, "World Series"),
        ("NLCS - Game 6", League.mlb, "NL Pennant"),
        ("WNBA Finals - Game 5", League.wnba, "WNBA Finals"),
        ("WNBA Commissioner's Cup Championship", League.wnba, "Commissioner's Cup"),
    ])
    func recognized(headline: String, league: League, trophy: String) {
        #expect(TrophyKind.from(headline: headline, league: league)?.singular == trophy)
    }

    @Test("Every earlier round wins nothing", arguments: [
        ("NFC Wild Card Playoffs", League.nfl),
        ("AFC DIVISIONAL PLAYOFF", League.nfl),
        ("East 1st Round - Game 1", League.nba),
        ("East Semifinals - Game 5", League.nba),
        ("EASTERN CONFERENCE SEMIFINALS - GAME 4", League.nba),
        ("WESTERN CONFERENCE 1st ROUND - GAME 4", League.nba),
        ("NBA In-Season Tournament - Semifinals", League.nba),
        ("NBA Cup - Semifinals", League.nba),
        ("East 2nd Round - Game 7", League.nhl),
        ("WESTERN CONFERENCE SECOND ROUND - GAME 4", League.nhl),
        ("Stanley Cup Semifinals - Game 1", League.nhl),
        ("Central 1st Round - Game 1", League.nhl),
        ("NLDS - Game 5", League.mlb),
        ("First Round - Game 2", League.wnba),
        ("WNBA Semifinals - Game 4", League.wnba),
        ("WNBA Commissioner's Cup", League.wnba),
    ])
    func earlierRounds(headline: String, league: League) {
        #expect(TrophyKind.from(headline: headline, league: league) == nil)
    }

    /// The bug the old wording produced on the 2010s spelling: the game
    /// number stayed in the name, so each game of the conference final was
    /// a trophy of its own and every one the team won was a row.
    @Test("A conference final is one trophy across its games and its spellings")
    func conferenceFinalIsOneTrophy() {
        let kinds = ["EASTERN CONFERENCE FINALS - GAME 1", "EASTERN CONFERENCE FINALS - GAME 6",
                     "East Finals - Game 4"]
            .map { TrophyKind.from(headline: $0, league: .nba) }
        #expect(Set(kinds).count == 1)
    }

    /// The Panthers' 2025 run, as the wire shows it: a Final won in six.
    @Test("A Stanley Cup Final series derives one Stanley Cup")
    func stanleyCupSeries() {
        let results = [false, true, true, false, true, true]
        let games = results.enumerated().map { index, won in
            titledGame("\(index)", headline: "Stanley Cup Final - Game \(index + 1)",
                       day: index * 2 + 1, mineWon: won)
        }
        let trophies = TrophyCase.derive(from: season(games), league: .nhl)
        #expect(trophies.map(\.kind.singular) == ["Stanley Cup"])
    }
}
