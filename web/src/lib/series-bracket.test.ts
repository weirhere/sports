import { describe, expect, it } from "vitest";
import type { Game, GameStatus, PlayoffSeries, Team } from "./types";
import type { League } from "./leagues";
import { loadsWholeSeasonSlate, playsSeries, pollSportName } from "./leagues";
import { bracketPairing, postseasonRounds, seriesRoundName } from "./postseason";
import { playoffSeries } from "./espn/transformers";
import { daysToReask, monthDayTokens, WINDOW_LIMIT } from "./espn/endpoints";
import { requestGate } from "./espn/request-gate";
import { sharesMensName } from "./team-name";
import { conferenceSharesMensName } from "./conferences";

// The series bracket and the season-fetch fixes (iOS, 2026-11-03).

function team(id: string, league: League = "mlb"): Team {
  return {
    id,
    espnId: Number(id) || 0,
    league,
    name: id,
    school: id,
    abbreviation: id,
    conferenceId: "",
    conferenceName: "",
    logoUrl: "",
  };
}

let next = 1;
function game(fields: {
  home: string;
  away: string;
  headline: string;
  day: number;
  winner?: string;
  status?: GameStatus;
  wins: Record<string, number>;
  length?: number;
  completed?: boolean;
  summary?: string;
}): Game {
  const series: PlayoffSeries = {
    length: fields.length ?? 3,
    summary: fields.summary,
    completed: fields.completed ?? false,
    wins: fields.wins,
  };
  const decided = fields.winner !== undefined;
  return {
    id: `g${next++}`,
    league: "mlb",
    status: fields.status ?? (decided ? "complete" : "scheduled"),
    scheduledAt: new Date(2026, 9, fields.day, 19).toISOString(),
    venue: { name: "", city: "", state: "" },
    homeTeam: { team: team(fields.home), score: decided ? 3 : null,
      isWinner: decided ? fields.winner === fields.home : undefined },
    awayTeam: { team: team(fields.away), score: decided ? 2 : null,
      isWinner: decided ? fields.winner === fields.away : undefined },
    seasonYear: 2026,
    conferenceGame: false,
    seasonType: 3,
    headline: fields.headline,
    series,
  };
}

describe("series round names", () => {
  it("reads each league's headlines", () => {
    const cases: [League, string, string][] = [
      ["mlb", "NLWC - Game 1", "Wild Card"],
      ["mlb", "ALDS - Game 3", "Division Series"],
      ["mlb", "NLCS - Game 4", "Championship Series"],
      ["mlb", "World Series - Game 5", "World Series"],
      ["nba", "East 1st Round - Game 2", "First Round"],
      ["nba", "West Semifinals - Game 1", "Conference Semifinals"],
      ["nba", "West Finals - Game 2", "Conference Finals"],
      ["nba", "NBA Finals - Game 2", "NBA Finals"],
      ["nhl", "West 2nd Round - Game 2", "Second Round"],
      ["nhl", "West Final - Game 1", "Conference Finals"],
      ["nhl", "Stanley Cup Final - Game 3", "Stanley Cup Final"],
      ["wnba", "WNBA Semifinals - Game 3", "Semifinals"],
      ["wnba", "WNBA Finals - Game 7", "Finals"],
    ];
    for (const [league, headline, round] of cases) {
      expect(seriesRoundName(headline, league)).toBe(round);
    }
    expect(seriesRoundName("Something New - Game 1", "nba")).toBe("Playoffs");
    expect(seriesRoundName(undefined, "nba")).toBeUndefined();
  });
});

describe("series cards", () => {
  it("draws a series as one card, opening the game that decided it", () => {
    const games = [
      game({ home: "ATL", away: "SD", headline: "NLWC - Game 1", day: 1, winner: "ATL", wins: { ATL: 1, SD: 0 } }),
      game({ home: "ATL", away: "SD", headline: "NLWC - Game 2", day: 2, winner: "SD", wins: { ATL: 1, SD: 1 } }),
      game({ home: "ATL", away: "SD", headline: "NLWC - Game 3", day: 3, winner: "ATL",
        wins: { ATL: 2, SD: 1 }, completed: true, summary: "ATL wins series 2-1" }),
    ];
    const rounds = postseasonRounds(games, "mlb");
    expect(rounds.map((round) => round.name)).toEqual(["Wild Card"]);
    const [card] = rounds[0].games;
    expect(rounds[0].games).toHaveLength(1);
    expect([card.homeTeam.score, card.awayTeam.score]).toEqual([2, 1]);
    expect(card.homeTeam.isWinner).toBe(true);
    expect(card.status).toBe("complete");
    expect(rounds[0].opens?.[card.id]?.id).toBe(games[2].id);
  });

  it("opens the live game of a series being played", () => {
    const games = [
      game({ home: "NYY", away: "CHW", headline: "ALDS - Game 1", day: 4, winner: "NYY", wins: { NYY: 1, CHW: 0 }, length: 5 }),
      game({ home: "NYY", away: "CHW", headline: "ALDS - Game 2", day: 5, status: "in_progress", wins: { NYY: 1, CHW: 0 }, length: 5 }),
    ];
    const round = postseasonRounds(games, "mlb")[0];
    const [card] = round.games;
    expect(card.status).toBe("in_progress");
    expect(card.homeTeam.isWinner).toBeUndefined();
    expect(round.opens?.[card.id]?.id).toBe(games[1].id);
  });

  it("wires a series winner into the next round, with a bye for the seed that sat out", () => {
    const games = [
      game({ home: "ATL", away: "SD", headline: "NLWC - Game 1", day: 1, winner: "ATL", wins: { ATL: 1, SD: 0 } }),
      game({ home: "ATL", away: "SD", headline: "NLWC - Game 2", day: 2, winner: "ATL",
        wins: { ATL: 2, SD: 0 }, completed: true, summary: "ATL wins series 2-0" }),
      game({ home: "LAD", away: "ATL", headline: "NLDS - Game 1", day: 4, wins: { LAD: 0, ATL: 0 }, length: 5 }),
    ];
    const rounds = postseasonRounds(games, "mlb");
    expect(rounds.map((round) => round.name)).toEqual(["Wild Card", "Division Series"]);
    const pairing = bracketPairing(rounds[0].games, rounds[1].games);
    expect(pairing).toBeDefined();
    expect(pairing?.sources[0]).toMatchObject({ kind: "bye" });
  });

  it("settles a series whose winner plays on, when its deciding game is missing", () => {
    const games = [
      game({ home: "DAL", away: "MIN", headline: "West 1st Round - Game 5", day: 1, winner: "MIN",
        wins: { DAL: 2, MIN: 3 }, length: 7 }),
      game({ home: "COL", away: "MIN", headline: "West 2nd Round - Game 1", day: 6, wins: { COL: 0, MIN: 0 }, length: 7 }),
    ].map((entry) => ({ ...entry, league: "nhl" as League }));
    const [first] = postseasonRounds(games, "nhl");
    const [card] = first.games;
    expect(card.awayTeam.isWinner).toBe(true);
    expect([card.awayTeam.score, card.homeTeam.score]).toEqual([4, 2]);
    expect(card.series?.summary).toBe("MIN wins series 4-2");
  });

  it("leaves single-game leagues' games as they are", () => {
    expect(playsSeries("nfl")).toBe(false);
    expect(playsSeries("mcbb")).toBe(false);
    expect(["mlb", "nba", "nhl", "wnba"].every((league) => playsSeries(league as League))).toBe(true);
  });
});

describe("the scoreboard's series record", () => {
  it("decodes a playoff series and only a playoff series", () => {
    expect(
      playoffSeries({
        type: "playoff",
        summary: "MIL wins series 4-1",
        completed: true,
        totalCompetitions: 7,
        competitors: [{ id: "30", wins: 1 }, { id: "8", wins: 4 }],
      })
    ).toEqual({ length: 7, summary: "MIL wins series 4-1", completed: true, wins: { "30": 1, "8": 4 } });
    expect(playoffSeries({ type: "season", competitors: [{ id: "1", wins: 2 }] })).toBeUndefined();
    expect(playoffSeries(undefined)).toBeUndefined();
  });
});

describe("re-asking a short month", () => {
  const noon = (month: number, day: number) => new Date(2026, month - 1, day, 12).toISOString();

  it("re-asks from the last day a month returned — the NHL's missing April 30", () => {
    const april = Array.from({ length: 29 }, (_, i) => noon(4, i + 1));
    expect(daysToReask("202604", april)).toEqual(["20260429", "20260430"]);
  });

  it("re-asks the rest of a month cut short below the limit — NCAAW's March", () => {
    const march = Array.from({ length: 15 }, (_, i) => noon(3, i + 1));
    const days = daysToReask("202603", march);
    expect(days[0]).toBe("20260315");
    expect(days[days.length - 1]).toBe("20260331");
    expect(days).toHaveLength(17);
  });

  it("re-asks an empty month or one at the limit whole", () => {
    expect(daysToReask("202511", [])).toHaveLength(30);
    expect(daysToReask("202512", Array(WINDOW_LIMIT).fill(noon(12, 31)))).toHaveLength(31);
    expect(monthDayTokens("202602")).toHaveLength(28);
  });
});

describe("the request gate", () => {
  it("never runs more than its limit at once", async () => {
    const gate = requestGate(3);
    let now = 0;
    let peak = 0;
    await Promise.all(
      Array.from({ length: 20 }, () =>
        gate(async () => {
          now += 1;
          peak = Math.max(peak, now);
          await new Promise((resolve) => setTimeout(resolve, 2));
          now -= 1;
        })
      )
    );
    expect(peak).toBe(3);
  });

  it("retries a failure once, and throws the second", async () => {
    const gate = requestGate(1);
    let calls = 0;
    await expect(
      gate(async () => {
        calls += 1;
        if (calls === 1) throw new Error("flaky");
        return 7;
      })
    ).resolves.toBe(7);
    let failures = 0;
    await expect(
      gate(async () => {
        failures += 1;
        throw new Error("down");
      })
    ).rejects.toThrow("down");
    expect(failures).toBe(2);
  });
});

describe("college pages", () => {
  it("names the Top 25's sport, and only college basketball skips the whole season", () => {
    expect(pollSportName("cfb")).toBe("Men's Football");
    expect(pollSportName("mcbb")).toBe("Men's Basketball");
    expect(pollSportName("wcbb")).toBe("Women's Basketball");
    expect(pollSportName("nba")).toBeUndefined();
    expect(loadsWholeSeasonSlate("mcbb")).toBe(false);
    expect(loadsWholeSeasonSlate("cfb")).toBe(true);
  });

  it("marks a women's team or conference whose name the men's share", () => {
    const uconn = { ...team("41", "wcbb"), school: "UConn", name: "Huskies" };
    const georgia = { ...team("61", "wcbb"), school: "Georgia", name: "Lady Bulldogs" };
    const mens = [{ school: "UConn", name: "Huskies" }, { school: "Georgia", name: "Bulldogs" }];
    expect(sharesMensName(uconn, mens)).toBe(true);
    expect(sharesMensName(georgia, mens)).toBe(false);
    expect(sharesMensName({ ...uconn, league: "mcbb" }, mens)).toBe(false);
    expect(conferenceSharesMensName({ league: "wcbb", id: 23 })).toBe(true);
    expect(conferenceSharesMensName({ league: "mcbb", id: 23 })).toBe(false);
  });
});
