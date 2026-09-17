import { describe, expect, it } from "vitest";
import {
  scoreboardUrl,
  seasonWindowUrl,
  espnWindow,
  espnDayTokens,
  espnMonthTokens,
  WINDOW_LIMIT,
  dayWindowUrl,
  teamRosterUrl,
} from "./endpoints";

describe("the groups parameter", () => {
  it("sends a named group for every league", () => {
    // ESPN honours `groups=` well beyond college football: probed live
    // 2026-09-09, `groups=4` on the NFL returns the three AFC East games of
    // a week rather than all fifteen. Dropping it silently was how a
    // division's Games tab came to show the whole league.
    expect(scoreboardUrl("nfl", { groups: 4 })).toContain("groups=4");
    expect(scoreboardUrl("nba", { groups: 1 })).toContain("groups=1");
    expect(scoreboardUrl("nhl", { groups: 32 })).toContain("groups=32");
    expect(scoreboardUrl("cfb", { groups: 8 })).toContain("groups=8");
  });

  it("defaults to FBS only where a request has to pick a division", () => {
    expect(scoreboardUrl("cfb")).toContain("groups=80");
    expect(scoreboardUrl("nfl")).not.toContain("groups=");
    expect(scoreboardUrl("nba")).not.toContain("groups=");
  });

  it("carries the group through a season window", () => {
    const url = seasonWindowUrl("nfl", "202609", { groups: 4 });
    expect(url).toContain("groups=4");
    expect(url).toContain("dates=202609");
  });

  it("never asks for a range — ESPN withdrew the form", () => {
    // `dates=20260915-20260919` answers 400 in every league, past seasons
    // included (probed live 2026-09-17). A span is several requests now.
    const tokens = espnWindow(new Date(2026, 8, 15), new Date(2026, 8, 19));
    for (const token of tokens) {
      expect(token).not.toContain("-");
      expect(seasonWindowUrl("nfl", token)).not.toMatch(/dates=\d+-\d+/);
    }
  });

  it("stays under ESPN's limit ceiling", () => {
    // `limit=501` does not clamp — it collapses the response to 25 events
    // and still answers 200, so there is no error to catch downstream.
    expect(WINDOW_LIMIT).toBe(500);
    expect(seasonWindowUrl("nfl", "202609")).toContain("limit=500");
    expect(dayWindowUrl("nfl", "20260917")).toContain("limit=500");
  });
});

describe("window tokens", () => {
  it("asks per day up to a week and per month beyond it", () => {
    // The Scores window is five days and revalidates every 30s, so it pays
    // for small exact requests. A fortnight-wide sweep does not.
    expect(espnWindow(new Date(2026, 8, 15), new Date(2026, 8, 19))).toEqual([
      "20260915",
      "20260916",
      "20260917",
      "20260918",
      "20260919",
    ]);
    expect(espnWindow(new Date(2026, 8, 15), new Date(2026, 8, 28))).toEqual([
      "202609",
    ]);
  });

  it("switches at a week", () => {
    expect(espnWindow(new Date(2026, 8, 1), new Date(2026, 8, 8))).toHaveLength(8);
    expect(espnWindow(new Date(2026, 8, 1), new Date(2026, 8, 9))).toEqual(["202609"]);
  });

  it("covers every month a span touches", () => {
    expect(espnMonthTokens(new Date(2026, 7, 1), new Date(2027, 1, 28))).toEqual([
      "202608",
      "202609",
      "202610",
      "202611",
      "202612",
      "202701",
      "202702",
    ]);
  });

  it("cannot stride over a span's last month from a month end", () => {
    // Jan 31 plus a month is Feb 28 in JS too, so a naive walk from the
    // 31st lands past March 1 and loses March entirely.
    expect(espnMonthTokens(new Date(2027, 0, 31), new Date(2027, 2, 1))).toEqual([
      "202701",
      "202702",
      "202703",
    ]);
  });

  it("gives a month its own days for the truncation fallback", () => {
    expect(espnDayTokens(new Date(2027, 1, 1), new Date(2027, 1, 28))).toHaveLength(28);
    expect(espnDayTokens(new Date(2028, 1, 1), new Date(2028, 1, 29))).toHaveLength(29);
  });

  it("asks once for a single day", () => {
    expect(espnDayTokens(new Date(2026, 8, 15), new Date(2026, 8, 15))).toEqual([
      "20260915",
    ]);
  });
});

describe("the season axis", () => {
  it("never spells a season as a bare year without a week", () => {
    // A bare `dates=YYYY` is the *calendar* year — it opens a season's slate
    // with the previous January's bowls and truncates before December.
    expect(scoreboardUrl("cfb", { seasonYear: 2019 })).not.toContain(
      "dates=2019"
    );
    expect(scoreboardUrl("cfb", { seasonYear: 2019, week: 3 })).toContain(
      "dates=2019"
    );
  });
});

describe("teamRosterUrl", () => {
  it("carries no season — the endpoint has no season axis", () => {
    const url = teamRosterUrl("cfb", "333");
    expect(url).toBe(
      "https://site.api.espn.com/apis/site/v2/sports/football/college-football/teams/333/roster"
    );
    expect(url).not.toContain("season");
  });

  it("uses each league's own base path", () => {
    expect(teamRosterUrl("nba", "13")).toContain("/basketball/nba/teams/13/roster");
    expect(teamRosterUrl("nhl", "1")).toContain("/hockey/nhl/teams/1/roster");
  });
});
