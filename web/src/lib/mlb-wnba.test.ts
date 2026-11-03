// MLB and the WNBA (2026-11-03) — the web twin of iOS `MLBTests.swift` and
// `WNBATests.swift`. Fixtures: the 2026 World Series' Game 5 (Brewers 4,
// Rays 1) and MLB's final divisional standings.

import { describe, expect, it } from "vitest";
import summaryJson from "./espn/__fixtures__/mlb-summary.json";
import standingsJson from "./espn/__fixtures__/mlb-standings-level3.json";
import {
  collegeFeeder,
  espnSeason,
  hasGameClock,
  hasPoll,
  hasWeeks,
  isBaseball,
  isBasketball,
  LEAGUE_DISPLAY_ORDER,
  playsOnASurface,
  seasonLabel,
  seasonSpan,
  seasonSpansNewYear,
  seasonYear,
  seasonYearContaining,
  shortName,
} from "./leagues";
import { conferenceName, divisionForTeamId, hasDivisions, parentOf } from "./conferences";
import { liveStatusText } from "./format";
import { halfInningText, periodShort } from "./period-label";
import { standingsColumns, standingsScrollsHorizontally } from "./standings-columns";
import { transformGameSummary, transformHeaderGame, transformStandings } from "./espn/transformers";
import {
  athleteNames,
  baseballGamecast,
  currentDiamond,
  halfInningSegments,
  inningText,
  isBreak,
} from "./baseball-gamecast";
import { trophyKindFromHeadline } from "./trophies";
import type { EspnGameSummaryResponse, EspnStandingsResponse } from "./espn/types";
import type { PlayItem } from "./types";

const summary = summaryJson as unknown as EspnGameSummaryResponse;

function gameDetail() {
  const game = transformHeaderGame("401908046", summary, "mlb");
  if (!game) throw new Error("no game");
  return { game, detail: transformGameSummary("401908046", game, summary) };
}

function through(plays: readonly PlayItem[], prefix: string): PlayItem[] {
  const index = plays.findIndex((p) => p.text?.startsWith(prefix));
  if (index < 0) throw new Error(`no play starting ${prefix}`);
  return plays.slice(0, index + 1);
}

describe("MLB and the WNBA, as leagues", () => {
  it("name and place themselves", () => {
    expect(shortName("mlb")).toBe("MLB");
    expect(shortName("wnba")).toBe("WNBA");
    expect(isBaseball("mlb")).toBe(true);
    expect(isBasketball("wnba")).toBe(true);
    expect(hasGameClock("mlb")).toBe(false);
    expect(hasGameClock("wnba")).toBe(true);
    expect(hasPoll("mlb")).toBe(false);
    expect(hasWeeks("mlb")).toBe(false);
    expect(hasWeeks("wnba")).toBe(false);
    expect(playsOnASurface("mlb")).toBe(true);
    expect(collegeFeeder("wnba")).toBe("wcbb");
    expect(LEAGUE_DISPLAY_ORDER[0]).toBe("mlb");
    expect(LEAGUE_DISPLAY_ORDER[LEAGUE_DISPLAY_ORDER.length - 1]).toBe("wnba");
  });

  it("run their seasons inside one calendar year", () => {
    expect(seasonSpansNewYear("mlb")).toBe(false);
    expect(seasonSpansNewYear("cfb")).toBe(true);
    expect(espnSeason("mlb", 2026)).toBe(2026);
    expect(seasonLabel("wnba", 2026)).toBe("2026");
    expect(seasonSpan("mlb", 2026)).toEqual({
      start: new Date(2026, 1, 1),
      end: new Date(2026, 10, 30),
    });
    expect(seasonSpan("wnba", 2026).end).toEqual(new Date(2026, 9, 31));
    expect(seasonYear("mlb", new Date(2027, 0, 15))).toBe(2026);
    expect(seasonYear("mlb", new Date(2027, 2, 15))).toBe(2027);
    // The app's July–June season is the cross-year leagues' alone.
    expect(seasonYearContaining(new Date(2026, 8, 15))).toBe(2026);
    expect(seasonYearContaining(new Date(2027, 6, 15))).toBe(2027);
  });

  it("print a live MLB line as ESPN's inning", () => {
    expect(
      liveStatusText({ league: "mlb", quarter: 5, clock: "0:00", detail: "Top 5th" })
    ).toBe("Top 5th");
    expect(liveStatusText({ league: "nba", quarter: 3, clock: "5:24" })).toBe("Q3 5:24");
    expect(periodShort(10, "mlb")).toBe("10");
    expect(halfInningText(1, "top")).toBe("TOP 1ST");
  });
});

describe("their registries", () => {
  it("collide on id 1 and stay apart", () => {
    expect(conferenceName(1, "cfb")).toBe("ACC");
    expect(conferenceName(1, "wnba")).toBe("Eastern");
    expect(conferenceName(1, "mlb")).toBe("AL East");
    expect(conferenceName(6, "mlb")).toBe("NL West");
    expect(parentOf(1, "mlb")).toBe(7);
    expect(divisionForTeamId("10", "mlb")).toBe(1);
    expect(divisionForTeamId("131935", "wnba")).toBe(1);
    expect(hasDivisions("mlb")).toBe(true);
    expect(hasDivisions("wnba")).toBe(false);
  });

  it("give MLB a scrolling table with L10", () => {
    expect(standingsScrollsHorizontally("mlb")).toBe(true);
    expect(standingsColumns("mlb").map((c) => c.caption)).toEqual([
      "W", "L", "PCT", "GB", "HOME", "AWAY", "RS", "RA", "DIFF", "STRK", "L10",
    ]);
    const tables = transformStandings(standingsJson as unknown as EspnStandingsResponse, "mlb");
    const entries = tables.flatMap((table) => table.entries);
    expect(entries.length).toBe(30);
    expect(entries.every((entry) => entry.lastTenGames !== undefined)).toBe(true);
  });
});

describe("baseball's game page", () => {
  it("ends the line score R H E", () => {
    const { game } = gameDetail();
    expect(game.awayTeam.linescores).toEqual([0, 1, 0, 0, 1, 2, 0, 0, 0]);
    expect(game.awayTeam.hits).toBe(8);
    expect(game.awayTeam.errors).toBe(2);
    expect(game.homeTeam.hits).toBe(4);
  });

  it("groups the plays by half-inning, one result per at-bat", () => {
    const { detail } = gameDetail();
    const segments = halfInningSegments(detail.plays ?? []);
    expect(segments).toHaveLength(18);
    expect(segments[0]).toMatchObject({ period: 9, half: "bottom" });
    expect(segments[segments.length - 1]).toMatchObject({ period: 1, half: "top" });
    expect(segments.reduce((sum, s) => sum + s.plays.length, 0)).toBe(84);
  });

  it("names its box score groups by type", () => {
    const { detail } = gameDetail();
    expect(detail.boxScore?.[0]?.categories.map((c) => c.label)).toEqual([
      "Batting",
      "Pitching",
    ]);
  });
});

describe("the live diamond", () => {
  it("reads runners after the play and outs off the last finished at-bat", () => {
    const plays = gameDetail().detail.plays ?? [];
    const double = currentDiamond(through(plays, "Turang doubled"))!;
    expect([double.onFirst, double.onSecond, double.onThird]).toEqual([false, true, false]);
    expect(double.outs).toBe(1);
    expect(inningText(double)).toBe("Top 2nd");
    const single = currentDiamond(through(plays, "Pratt singled"))!;
    expect([single.onFirst, single.onSecond, single.onThird]).toEqual([false, false, true]);
    expect(single.outs).toBe(2);
    const mid = currentDiamond(through(plays, "Pitch 4 : Strike 2 Looking"))!;
    expect([mid.balls, mid.strikes, mid.outs]).toEqual([2, 2, 2]);
    expect(mid.lastPitch).toMatch(/mph/);
  });

  it("clears between halves and names the matchup", () => {
    const { detail } = gameDetail();
    const plays = detail.plays ?? [];
    const middle = currentDiamond(through(plays, "Middle of the 2nd"))!;
    expect(isBreak(middle)).toBe(true);
    expect(middle.onThird).toBe(false);
    expect(inningText(middle)).toBe("Mid 2nd");
    const atBat = currentDiamond(through(plays, "Pitch 4 : Strike 2 Looking"))!;
    const content = baseballGamecast(atBat, athleteNames(detail.boxScore));
    expect(content.slots.map((s) => s.value)).toEqual(["2-2", "2", atBat.lastPitch]);
    expect(content.lastPlayLabel).toContain(" vs ");
    expect(content.accessibilitySummary).toContain("runners on third");
  });
});

describe("their trophies", () => {
  it("count the World Series, the pennants, the WNBA Finals and the Cup", () => {
    expect(trophyKindFromHeadline("World Series - Game 5", "mlb")?.singular).toBe("World Series");
    expect(trophyKindFromHeadline("ALCS - Game 6", "mlb")?.singular).toBe("AL Pennant");
    expect(trophyKindFromHeadline("ALDS - Game 1", "mlb")).toBeUndefined();
    expect(trophyKindFromHeadline("WNBA Finals - Game 7", "wnba")?.singular).toBe("WNBA Finals");
    expect(
      trophyKindFromHeadline("WNBA Commissioner's Cup Championship", "wnba")?.singular
    ).toBe("Commissioner's Cup");
    expect(trophyKindFromHeadline("WNBA Commissioner's Cup", "wnba")).toBeUndefined();
  });
});
