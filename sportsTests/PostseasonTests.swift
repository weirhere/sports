import Foundation
import Testing
@testable import StatSide

/// The postseason round split, against both leagues' real shapes (probed
/// live 2026-09-06).
private func team(_ id: String, _ location: String) -> Team {
    Team(id: id, location: location, name: nil, abbreviation: nil, displayName: location,
         shortDisplayName: location, logoURL: nil, conferenceId: nil)
}

private func competitor(_ id: String, _ location: String, home: Bool) -> Competitor {
    Competitor(team: team(id, location), score: nil, record: nil,
               rank: nil, isHome: home, winner: nil)
}

private func game(_ id: String, week: Int?, month: Int = 1, day: Int,
                  headline: String? = nil,
                  final: Bool = true, seasonType: Int = 3) -> Game {
    Game(id: id,
         date: Calendar.current.date(from: DateComponents(year: 2026, month: month, day: day)),
         name: nil, shortName: nil, weekNumber: week, seasonType: seasonType,
         headline: headline,
         status: final ? .final(detail: nil) : .pre(detail: nil),
         home: competitor("1", "Home", home: true),
         away: competitor("2", "Away", home: false),
         broadcast: nil)
}

@Suite struct PostseasonTests {
    /// The NFL's rounds are its weeks. Week 4 — the Pro Bowl — is not one
    /// of them; it leaves the bracket entirely (see `ExhibitionTests`).
    @Test func nflRoundsComeFromTheWeekNumber() {
        let games = [
            game("a", week: 1, day: 10), game("b", week: 2, day: 17),
            game("c", week: 3, day: 24), game("d", week: 4, month: 2, day: 1),
            game("e", week: 5, month: 2, day: 8),
        ]
        let names = Postseason.rounds(from: games, league: .nfl).map(\.name)
        #expect(names == ["Wild Card", "Divisional",
                          "Conference Championships", "Super Bowl"])
    }

    /// College football files every bowl and every playoff round under one
    /// week, so the round has to come out of ESPN's printed headline — and
    /// the bowls are then left out entirely (Andy, 2026-09-06): the tab is
    /// the playoff, and they stay on the Games tab in date order.
    @Test func collegeRoundsComeFromTheHeadline() {
        let games = [
            game("bowl", week: 1, day: 2, headline: "Bucked Up LA Bowl"),
            game("first", week: 1, day: 4, headline: "College Football Playoff First Round Game"),
            game("quarter", week: 1, day: 6,
                 headline: "College Football Playoff Quarterfinal at the Allstate Sugar Bowl"),
            game("semi", week: 1, day: 9,
                 headline: "College Football Playoff Semifinal at the Vrbo Fiesta Bowl"),
            game("title", week: 1, day: 20,
                 headline: "College Football Playoff National Championship Presented by AT&T"),
        ]
        let names = Postseason.rounds(from: games, league: .collegeFootball).map(\.name)
        #expect(names == ["First Round", "Quarterfinals",
                          "Semifinals", "National Championship"])
    }

    /// A slate of nothing but bowls has no bracket at all, so the tab hides
    /// itself rather than opening on 38 exhibition games.
    @Test func aBowlOnlySlateHasNoRounds() {
        let games = [game("b1", week: 1, day: 2, headline: "Bucked Up LA Bowl"),
                     game("b2", week: 1, day: 3, headline: "StaffDNA Cure Bowl"),
                     game("b3", week: 1, day: 4, headline: nil)]
        #expect(Postseason.rounds(from: games, league: .collegeFootball).isEmpty)
    }

    /// A quarterfinal played *at* a bowl must read as a quarterfinal — the
    /// headline contains both words, and dropping the bowls must not drop
    /// it. This is the case that makes the bowl rule a leftover rather
    /// than a match on the word "bowl".
    @Test func aPlayoffGameAtABowlIsNotABowl() {
        let games = [game("q", week: 1, day: 1,
                          headline: "College Football Playoff Quarterfinal at the Rose Bowl")]
        #expect(Postseason.rounds(from: games, league: .collegeFootball).map(\.name)
                == ["Quarterfinals"])
    }

    /// Rounds order by first kickoff, which is what reads correctly for
    /// both leagues without a hardcoded sequence.
    @Test func roundsOrderByKickoff() {
        let games = [game("late", week: 5, month: 2, day: 8),
                     game("early", week: 1, day: 10)]
        #expect(Postseason.rounds(from: games, league: .nfl).map(\.name)
                == ["Wild Card", "Super Bowl"])
    }

    /// Only postseason games; a regular-season slate produces no rounds, so
    /// the tab hides itself.
    @Test func regularSeasonGamesProduceNoRounds() {
        let games = [game("r", week: 3, day: 5, seasonType: 2)]
        #expect(Postseason.rounds(from: games, league: .nfl).isEmpty)
    }

    /// The page opens on the round being played, not on January's Wild Card.
    @Test func theDefaultRoundIsTheOneStillBeingPlayed() {
        let rounds = Postseason.rounds(from: [
            game("wc", week: 1, day: 10),
            game("div", week: 2, day: 17, final: false),
        ], league: .nfl)
        #expect(Postseason.defaultRound(in: rounds) == "Divisional")
    }

    /// Once it's all over, the page opens on the championship.
    @Test func afinishedPostseasonOpensOnItsLastRound() {
        let rounds = Postseason.rounds(from: [
            game("wc", week: 1, day: 10), game("sb", week: 5, month: 2, day: 8),
        ], league: .nfl)
        #expect(Postseason.defaultRound(in: rounds) == "Super Bowl")
    }

    /// An unnameable round keeps its games rather than dropping them.
    @Test func anUnknownRoundStillCarriesItsGames() {
        let rounds = Postseason.rounds(from: [game("x", week: 9, day: 5)], league: .nfl)
        #expect(rounds.map(\.name) == ["Postseason"])
        #expect(rounds.first?.games.count == 1)
    }
}

/// The bracket's connectors — the one thing that must never be guessed.
@Suite struct BracketAdvancementTests {
    private func decided(_ id: String, home: String, away: String,
                         homeWins: Bool, day: Int) -> Game {
        Game(id: id,
             date: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: day)),
             name: nil, shortName: nil, weekNumber: nil, seasonType: 3, headline: nil,
             status: .final(detail: nil),
             home: Competitor(team: team(home, home), score: 21, record: nil,
                              rank: nil, isHome: true, winner: homeWins),
             away: Competitor(team: team(away, away), score: 14, record: nil,
                              rank: nil, isHome: false, winner: !homeWins),
             broadcast: nil)
    }

    private func upcoming(_ id: String, home: String, away: String, day: Int) -> Game {
        Game(id: id,
             date: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: day)),
             name: nil, shortName: nil, weekNumber: nil, seasonType: 3, headline: nil,
             status: .pre(detail: nil),
             home: Competitor(team: team(home, home), score: nil, record: nil,
                              rank: nil, isHome: true, winner: nil),
             away: Competitor(team: team(away, away), score: nil, record: nil,
                              rank: nil, isHome: false, winner: nil),
             broadcast: nil)
    }

    /// A line is drawn from each game whose winner turns up in the next.
    @Test func aRoundFeedsTheGameItsWinnersReach() {
        let wildCard = [decided("wc1", home: "A", away: "B", homeWins: true, day: 10),
                        decided("wc2", home: "C", away: "D", homeWins: false, day: 11)]
        // A beat B, D beat C — so the divisional game is A vs D.
        let divisional = upcoming("dv", home: "A", away: "D", day: 17)
        let feeders = Postseason.feeders(of: divisional, from: wildCard)
        #expect(Set(feeders.map(\.id)) == ["wc1", "wc2"])
    }

    /// A game the round didn't feed gets no line — the losers' games are
    /// not connected to anything.
    @Test func anUnrelatedGameIsNotConnected() {
        let wildCard = [decided("wc1", home: "A", away: "B", homeWins: true, day: 10)]
        let elsewhere = upcoming("dv", home: "X", away: "Y", day: 17)
        #expect(Postseason.feeders(of: elsewhere, from: wildCard).isEmpty)
    }

    /// The whole point: an unplayed round proves nothing, so it draws
    /// nothing rather than guessing a pairing from position.
    @Test func anUnplayedRoundDrawsNoLines() {
        let wildCard = [upcoming("wc1", home: "A", away: "B", day: 10),
                        upcoming("wc2", home: "C", away: "D", day: 11)]
        let divisional = upcoming("dv", home: "A", away: "D", day: 17)
        #expect(Postseason.feeders(of: divisional, from: wildCard).isEmpty)
    }

    /// A bye: only one feeder, because the top seed didn't play a round.
    @Test func aByeLeavesASingleFeeder() {
        let wildCard = [decided("wc1", home: "A", away: "B", homeWins: true, day: 10)]
        // The 1 seed (Z) had a bye and meets A in the divisional round.
        let divisional = upcoming("dv", home: "Z", away: "A", day: 17)
        #expect(Postseason.feeders(of: divisional, from: wildCard).map(\.id) == ["wc1"])
    }

    @Test func aWinnerIsReadOffTheCompetitorFlag() {
        #expect(decided("g", home: "A", away: "B", homeWins: true, day: 1).winnerTeamId == "A")
        #expect(decided("g", home: "A", away: "B", homeWins: false, day: 1).winnerTeamId == "B")
        #expect(upcoming("g", home: "A", away: "B", day: 1).winnerTeamId == nil)
    }
}

/// The bracket's own shape: which sources feed which game, and in what
/// order they stack — the thing that was wrong when the columns were laid
/// out by kickoff (Andy, 2026-09-06).
@Suite struct BracketPairingTests {
    private func played(_ id: String, winner w: String, loser l: String, day: Int) -> Game {
        Game(id: id,
             date: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: day)),
             name: nil, shortName: nil, weekNumber: nil, seasonType: 3, headline: nil,
             status: .final(detail: nil),
             home: Competitor(team: team(w, w), score: 30, record: nil,
                              rank: nil, isHome: true, winner: true),
             away: Competitor(team: team(l, l), score: 10, record: nil,
                              rank: nil, isHome: false, winner: false),
             broadcast: nil)
    }

    private func matchup(_ id: String, _ a: String, _ b: String, day: Int) -> Game {
        Game(id: id,
             date: Calendar.current.date(from: DateComponents(year: 2026, month: 1, day: day)),
             name: nil, shortName: nil, weekNumber: nil, seasonType: 3, headline: nil,
             status: .pre(detail: nil),
             home: Competitor(team: team(a, a), score: nil, record: nil,
                              rank: nil, isHome: true, winner: nil),
             away: Competitor(team: team(b, b), score: nil, record: nil,
                              rank: nil, isHome: false, winner: nil),
             broadcast: nil)
    }

    /// The real 2025 CFP shape: four first-round games, four quarterfinals,
    /// each pairing one winner with a seed that had a bye. The quarterfinal
    /// order on screen must follow the bracket, not the calendar — and the
    /// bye teams must appear as their own sources.
    @Test func byeTeamsBecomeTheirOwnSource() {
        let first = [played("f1", winner: "ALA", loser: "OU", day: 20),
                     played("f2", winner: "MIA", loser: "TAMU", day: 20)]
        // Chronologically MIA's quarterfinal comes first, but ALA's is the
        // one fed by the first game listed.
        let quarters = [matchup("q1", "OSU", "MIA", day: 1),
                        matchup("q2", "IU", "ALA", day: 2)]
        let pairing = Postseason.pairing(round: first, next: quarters)
        #expect(pairing != nil)
        // MIA's quarterfinal is first (earliest), and its sources are the
        // bye seed then the game that produced MIA.
        #expect(pairing?.sources.map(\.id)
                == ["bye-cfb:OSU", "game-f2", "bye-cfb:IU", "game-f1"])
        #expect(pairing?.links.map(\.sourceIndices) == [[0, 1], [2, 3]])
    }

    /// Every game of the round stays on screen even if it fed nothing we
    /// can see — a round is never partly shown.
    @Test func anUnconnectedGameStillAppears() {
        let first = [played("f1", winner: "ALA", loser: "OU", day: 20),
                     played("f2", winner: "MIA", loser: "TAMU", day: 20)]
        let quarters = [matchup("q1", "IU", "ALA", day: 2)]
        let pairing = Postseason.pairing(round: first, next: quarters)
        #expect(pairing?.sources.contains { $0.id == "game-f2" } == true)
    }

    /// Bowls don't feed the playoff, so there is no bracket to draw — and
    /// crucially no bye entries invented for eight teams that simply
    /// weren't in a bowl.
    @Test func unconnectedRoundsHaveNoPairing() {
        let bowls = [played("b1", winner: "BOISE", loser: "WASH", day: 2)]
        let first = [matchup("f1", "ALA", "OU", day: 20)]
        #expect(Postseason.pairing(round: bowls, next: first) == nil)
    }

    /// Nothing played yet proves nothing, so no bracket and no byes.
    @Test func anUnplayedRoundHasNoPairing() {
        let first = [matchup("f1", "ALA", "OU", day: 20)]
        let quarters = [matchup("q1", "IU", "ALA", day: 2)]
        #expect(Postseason.pairing(round: first, next: quarters) == nil)
    }

    /// The NFL's divisional round: two winners into one championship game,
    /// no byes at this depth.
    @Test func twoWinnersCanFeedOneGame() {
        let divisional = [played("d1", winner: "DEN", loser: "BUF", day: 17),
                          played("d2", winner: "NE", loser: "HOU", day: 18)]
        let title = [matchup("c1", "DEN", "NE", day: 24)]
        let pairing = Postseason.pairing(round: divisional, next: title)
        #expect(pairing?.sources.map(\.id) == ["game-d1", "game-d2"])
        #expect(pairing?.links.first?.sourceIndices == [0, 1])
    }
}

/// The Pro Bowl: a real postseason fixture that is not a round (Andy,
/// 2026-09-06).
@Suite struct ExhibitionTests {
    private func nfl(_ id: String, week: Int, month: Int = 1, day: Int) -> Game {
        game(id, week: week, month: month, day: day)
    }

    /// It never becomes a chip — a bracket must not imply an all-star game
    /// sits between the conference championships and the Super Bowl.
    @Test func theProBowlIsNotARound() {
        let games = [nfl("wc", week: 1, day: 10), nfl("cc", week: 3, day: 24),
                     nfl("pb", week: 4, month: 2, day: 1),
                     nfl("sb", week: 5, month: 2, day: 8)]
        let names = Postseason.rounds(from: games, league: .nfl).map(\.name)
        #expect(names == ["Wild Card", "Conference Championships", "Super Bowl"])
    }

    @Test func theProBowlIsReturnedSeparately() {
        let games = [nfl("sb", week: 5, month: 2, day: 8),
                     nfl("pb", week: 4, month: 2, day: 1)]
        let exhibition = Postseason.exhibition(from: games, league: .nfl)
        #expect(exhibition?.name == "Pro Bowl")
        #expect(exhibition?.games.map(\.id) == ["pb"])
    }

    /// College football has no equivalent, and week 4 means nothing there —
    /// its whole postseason is week 1.
    @Test func collegeFootballHasNoExhibition() {
        let games = [game("b", week: 1, day: 2, headline: "LA Bowl")]
        #expect(Postseason.exhibition(from: games, league: .collegeFootball) == nil)
    }

    /// A season without one is nil, not an empty round that would render a
    /// heading over nothing.
    @Test func noProBowlMeansNoExhibition() {
        #expect(Postseason.exhibition(from: [nfl("sb", week: 5, month: 2, day: 8)],
                                      league: .nfl) == nil)
    }
}
