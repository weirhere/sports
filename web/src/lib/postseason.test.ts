import { describe, expect, it } from "vitest";
import type { Game, GameStatus, GameTeam, Team } from "./types";
import type { League } from "./leagues";
import {
  bracketPairing,
  bracketPlacements,
  defaultRound,
  feeders,
  postseasonExhibition,
  postseasonRounds,
  sourceTops,
} from "./postseason";

function team(id: string, school: string, league: League = "cfb"): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name: school,
    school,
    abbreviation: school.slice(0, 3).toUpperCase(),
    conferenceId: "8",
    conferenceName: "",
    logoUrl: "",
  };
}

function side(t: Team, isWinner?: boolean): GameTeam {
  return { team: t, score: null, isWinner };
}

let nextId = 1;
function game(fields: {
  home: Team;
  away: Team;
  winner?: "home" | "away";
  day?: number;
  week?: number;
  headline?: string;
  seasonType?: number;
  status?: GameStatus;
  league?: League;
}): Game {
  const decided = fields.winner !== undefined;
  return {
    id: `g${nextId++}`,
    league: fields.league ?? fields.home.league,
    status: fields.status ?? (decided ? "complete" : "scheduled"),
    scheduledAt: new Date(2026, 0, fields.day ?? 1, 12).toISOString(),
    venue: { name: "", city: "", state: "" },
    homeTeam: side(fields.home, decided ? fields.winner === "home" : undefined),
    awayTeam: side(fields.away, decided ? fields.winner === "away" : undefined),
    seasonYear: 2025,
    conferenceGame: false,
    week: fields.week,
    seasonType: fields.seasonType ?? 3,
    headline: fields.headline,
  };
}

// The 2025 CFP as ESPN published it: twelve teams, every round in
// `seasontype=3` week 1, the round named only in the headline.
const osu = team("194", "Ohio State");
const uga = team("61", "Georgia");
const iu = team("84", "Indiana");
const alabama = team("333", "Alabama");
const oregon = team("2483", "Oregon");
const miami = team("2390", "Miami");
const miss = team("145", "Ole Miss");

const FIRST = "College Football Playoff First Round Game";
const QUARTER = "College Football Playoff Quarterfinal at the Allstate Sugar Bowl";
const SEMI = "College Football Playoff Semifinal at the Vrbo Fiesta Bowl";
const TITLE = "College Football Playoff National Championship Presented by AT&T";

describe("naming a round", () => {
  it("reads college football's round off the headline, sponsors and all", () => {
    const rounds = postseasonRounds(
      [
        game({ home: alabama, away: oregon, headline: FIRST, day: 19 }),
        game({ home: osu, away: miami, headline: QUARTER, day: 31 }),
        game({ home: iu, away: miss, headline: SEMI, day: 9 }),
      ],
      "cfb"
    );
    expect(rounds.map((r) => r.name)).toEqual([
      "Semifinals",
      "First Round",
      "Quarterfinals",
    ]);
  });

  it("orders rounds by first kickoff, not by a hardcoded sequence", () => {
    const rounds = postseasonRounds(
      [
        game({ home: iu, away: miss, headline: SEMI, day: 9 }),
        game({ home: alabama, away: oregon, headline: FIRST, day: 2 }),
        game({ home: osu, away: miami, headline: TITLE, day: 19 }),
      ],
      "cfb"
    );
    expect(rounds.map((r) => r.name)).toEqual([
      "First Round",
      "Semifinals",
      "National Championship",
    ]);
  });

  it("leaves a bowl out of the bracket entirely", () => {
    const rounds = postseasonRounds(
      [
        game({ home: alabama, away: oregon, headline: "Duke's Mayo Bowl" }),
        game({ home: osu, away: miami, headline: QUARTER }),
      ],
      "cfb"
    );
    expect(rounds).toHaveLength(1);
    expect(rounds[0].name).toBe("Quarterfinals");
  });

  it("makes no rounds at all out of a slate of only bowls", () => {
    const rounds = postseasonRounds(
      [game({ home: alabama, away: oregon, headline: "Gator Bowl" })],
      "cfb"
    );
    expect(rounds).toEqual([]);
  });

  it("names the NFL's rounds by week, and never the NBA's or NHL's", () => {
    const bills = team("2", "Buffalo", "nfl");
    const chiefs = team("12", "Kansas City", "nfl");
    const nfl = postseasonRounds(
      [
        game({ home: bills, away: chiefs, week: 1, league: "nfl" }),
        game({ home: bills, away: chiefs, week: 3, league: "nfl" }),
        game({ home: bills, away: chiefs, week: 5, league: "nfl" }),
      ],
      "nfl"
    );
    expect(nfl.map((r) => r.name)).toEqual([
      "Wild Card",
      "Conference Championships",
      "Super Bowl",
    ]);

    const celtics = team("2", "Boston", "nba");
    const knicks = team("18", "New York", "nba");
    expect(
      postseasonRounds(
        [game({ home: celtics, away: knicks, league: "nba" })],
        "nba"
      )
    ).toEqual([]);
  });
});

describe("the Pro Bowl", () => {
  const bills = team("2", "Buffalo", "nfl");
  const chiefs = team("12", "Kansas City", "nfl");

  it("is lifted out of the bracket rather than taking a round chip", () => {
    const slate = [
      game({ home: bills, away: chiefs, week: 3, league: "nfl", day: 20 }),
      game({ home: bills, away: chiefs, week: 4, league: "nfl", day: 26 }),
      game({ home: bills, away: chiefs, week: 5, league: "nfl", day: 30 }),
    ];
    expect(postseasonRounds(slate, "nfl").map((r) => r.name)).toEqual([
      "Conference Championships",
      "Super Bowl",
    ]);
    expect(postseasonExhibition(slate, "nfl")?.name).toBe("Pro Bowl");
  });

  it("is the NFL's alone", () => {
    expect(
      postseasonExhibition(
        [game({ home: alabama, away: oregon, headline: QUARTER })],
        "cfb"
      )
    ).toBeUndefined();
  });
});

describe("which round a page opens on", () => {
  it("is the first one still being played", () => {
    const done = { name: "First Round", games: [game({ home: alabama, away: oregon, winner: "home" })] };
    const live = { name: "Quarterfinals", games: [game({ home: osu, away: miami })] };
    expect(defaultRound([done, live])).toBe("Quarterfinals");
  });

  it("is the last one once the postseason is over", () => {
    const first = { name: "Semifinals", games: [game({ home: alabama, away: oregon, winner: "home" })] };
    const last = { name: "National Championship", games: [game({ home: osu, away: miami, winner: "away" })] };
    expect(defaultRound([first, last])).toBe("National Championship");
  });
});

describe("advancement is earned, never assumed", () => {
  it("draws a line only where a winner turns up in a later game", () => {
    const won = game({ home: alabama, away: oregon, winner: "home" });
    const unplayed = game({ home: miami, away: miss });
    const next = game({ home: osu, away: alabama });
    expect(feeders(next, [won, unplayed])).toEqual([won]);
  });

  it("connects nothing at all when a round hasn't been played", () => {
    const round = [game({ home: alabama, away: oregon }), game({ home: miami, away: miss })];
    const next = [game({ home: osu, away: uga })];
    expect(bracketPairing(round, next)).toBeUndefined();
  });

  it("synthesises a bye for a team that reached a round without playing it", () => {
    // Alabama beat Oregon in the first round; Ohio State sat it out.
    const first = game({ home: alabama, away: oregon, winner: "home" });
    const quarter = game({ home: osu, away: alabama });
    const pairing = bracketPairing([first], [quarter]);
    expect(pairing).toBeDefined();
    // Byes lead — a bye is always the better seed.
    expect(pairing!.sources.map((s) => s.kind)).toEqual(["bye", "game"]);
    expect(pairing!.sources[0]).toMatchObject({ kind: "bye" });
    expect(pairing!.links[0].sourceIndices).toEqual([0, 1]);
  });

  it("never invents a bye in a round nothing connects", () => {
    // No result links these, so no bye is claimed either.
    const first = [game({ home: alabama, away: oregon })];
    const quarter = [game({ home: osu, away: miami })];
    expect(bracketPairing(first, quarter)).toBeUndefined();
  });

  it("keeps a game of the round that fed nothing visible", () => {
    const fed = game({ home: alabama, away: oregon, winner: "home" });
    const orphan = game({ home: miami, away: miss, winner: "home" });
    const next = game({ home: osu, away: alabama });
    const pairing = bracketPairing([fed, orphan], [next])!;
    const ids = pairing.sources.map((s) => s.id);
    expect(ids).toContain(`game-${orphan.id}`);
    // …but nothing links to it.
    expect(pairing.links[0].sourceIndices).not.toContain(
      ids.indexOf(`game-${orphan.id}`)
    );
  });

  it("wires a whole four-into-two round without crossing lines", () => {
    // Two first-round games feed one quarterfinal each; the higher seeds
    // have byes. Each next-round game must sit level with its own sources.
    const a = game({ home: alabama, away: oregon, winner: "home", day: 19 });
    const b = game({ home: miami, away: miss, winner: "away", day: 19 });
    const q1 = game({ home: osu, away: alabama, day: 31 });
    const q2 = game({ home: uga, away: miss, day: 31 });
    const pairing = bracketPairing([a, b], [q1, q2])!;
    const tops = sourceTops(pairing.sources);
    const placements = bracketPlacements(pairing, tops);

    // q1's sources sit above q2's, so q1 is placed above q2.
    const top1 = placements.find((p) => p.game.id === q1.id)!.top;
    const top2 = placements.find((p) => p.game.id === q2.id)!.top;
    expect(top1).toBeLessThan(top2);
    // Four sources: two byes and two games, in bracket order.
    expect(pairing.sources.map((s) => s.kind)).toEqual([
      "bye",
      "game",
      "bye",
      "game",
    ]);
  });
});

describe("bracket geometry", () => {
  it("stacks a bye shorter than a game", () => {
    const first = game({ home: alabama, away: oregon, winner: "home" });
    const quarter = game({ home: osu, away: alabama });
    const pairing = bracketPairing([first], [quarter])!;
    const tops = sourceTops(pairing.sources);
    expect(tops[0]).toBe(0);
    // The bye is 46 tall, then an 8pt gap.
    expect(tops[1]).toBe(54);
  });

  it("nudges a placement down rather than letting two collide", () => {
    // Both quarterfinals are fed from the same single source, so their
    // ideal centres are identical.
    const first = game({ home: alabama, away: oregon, winner: "home" });
    const q1 = game({ home: osu, away: alabama, day: 30 });
    const q2 = game({ home: uga, away: alabama, day: 31 });
    const pairing = bracketPairing([first], [q1, q2])!;
    const placements = bracketPlacements(pairing, sourceTops(pairing.sources));
    expect(placements[1].top - placements[0].top).toBeGreaterThanOrEqual(90);
  });
});
