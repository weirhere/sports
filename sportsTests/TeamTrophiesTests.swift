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
    /// It ships empty on purpose (see `TrophyRegistry`), and what has to
    /// hold while it is empty is that nothing claims to be all-time.
    @Test("An unpopulated registry contributes nothing and claims nothing")
    func shipsEmptyAndGated() {
        for league in League.allCases {
            #expect(TrophyRegistry.trophies(teamId: "61", league: league).isEmpty)
            #expect(TrophyRegistry.coveredKinds(in: league).isEmpty)
        }
    }
}
