// Men's and women's college basketball (2026-11-02) — the web twin of iOS
// `sportsTests/CollegeBasketballTests.swift`. Fixtures captured live the
// season's second night.

import { describe, expect, it } from "vitest";
import scoreboardJson from "./espn/__fixtures__/mcbb-scoreboard.json";
import standingsJson from "./espn/__fixtures__/wcbb-standings.json";
import {
  apiBase,
  collegeFeeder,
  espnSeason,
  hasCollegeDivisions,
  hasPlayoffRanking,
  hasPoll,
  hasWeeks,
  isBasketball,
  isCollege,
  isCollegeBasketball,
  leagueGroupId,
  leagueLogoUrl,
  parseLeague,
  periodFormat,
  playsOnASurface,
  seasonLabel,
  seasonYear,
  shortName,
  slateSplitsByConference,
  teamLogoBase,
} from "./leagues";
import {
  conferenceLogoUrl,
  conferenceName,
  isKnownConference,
  rootAbove,
  tier,
  topLevelIds,
} from "./conferences";
import { scoreboardUrl, standingsUrl } from "./espn/endpoints";
import { transformScoreboard, transformStandings } from "./espn/transformers";
import { basketballRoundName } from "./postseason";
import { trophyKindFromHeadline } from "./trophies";
import { startsClosed } from "./hooks/use-ui-state";
import { buildSections } from "./game-sections";
import { periodLabel } from "./live-activity-state";
import type { EspnEvent, EspnStandingsResponse } from "./espn/types";

const BOTH = ["mcbb", "wcbb"] as const;

describe("college basketball leagues", () => {
  it("are their own persisted leagues on ESPN's basketball paths", () => {
    expect(parseLeague("mcbb")).toBe("mcbb");
    expect(parseLeague("wcbb")).toBe("wcbb");
    expect(apiBase("mcbb")).toContain("/basketball/mens-college-basketball");
    expect(apiBase("wcbb")).toContain("/basketball/womens-college-basketball");
    expect(shortName("mcbb")).toBe("NCAAM");
    expect(shortName("wcbb")).toBe("NCAAW");
  });

  it("are college, basketball, polled and weekless", () => {
    for (const league of BOTH) {
      expect(isCollege(league)).toBe(true);
      expect(isBasketball(league)).toBe(true);
      expect(isCollegeBasketball(league)).toBe(true);
      expect(hasPoll(league)).toBe(true);
      expect(hasPlayoffRanking(league)).toBe(false);
      expect(hasCollegeDivisions(league)).toBe(false);
      expect(hasWeeks(league)).toBe(false);
      expect(playsOnASurface(league)).toBe(false);
      expect(slateSplitsByConference(league)).toBe(true);
      expect(leagueGroupId(league)).toBe(50);
      expect(teamLogoBase(league)).toBe("https://a.espncdn.com/i/teamlogos/ncaa/500");
    }
    expect(leagueGroupId("cfb")).toBe(80);
    expect(leagueGroupId("nba")).toBeUndefined();
    expect(isCollegeBasketball("nba")).toBe(false);
  });

  it("wear the marks their own scoreboards declare", () => {
    expect(leagueLogoUrl("mcbb")).toContain("NCAASports_MensBasketball.png");
    expect(leagueLogoUrl("wcbb")).toContain("NCAASports_WomensBasketball.png");
  });

  it("name a season for the year it ends, and roll over after April", () => {
    for (const league of BOTH) {
      expect(espnSeason(league, 2026)).toBe(2027);
      expect(seasonLabel(league, 2026)).toBe("2026-27");
      expect(seasonYear(league, new Date(2027, 3, 15))).toBe(2026);
      expect(seasonYear(league, new Date(2027, 4, 15))).toBe(2027);
    }
  });

  it("play halves for the men and quarters for the women", () => {
    expect(periodFormat("mcbb").regulationCount).toBe(2);
    expect(periodFormat("wcbb").regulationCount).toBe(4);
    expect(periodLabel(2, "mcbb")).toBe("H2");
    expect(periodLabel(3, "mcbb")).toBe("OT");
    expect(periodLabel(3, "wcbb")).toBe("Q3");
  });

  it("send an NBA player's College row to men's basketball", () => {
    expect(collegeFeeder("nba")).toBe("mcbb");
    expect(collegeFeeder("nfl")).toBe("cfb");
    expect(collegeFeeder("mcbb")).toBeUndefined();
  });
});

describe("college basketball requests", () => {
  it("scope the scoreboard and standings to Division I", () => {
    const board = new URL(scoreboardUrl("mcbb", { dates: "20261102" }));
    expect(board.searchParams.get("groups")).toBe("50");
    expect(board.searchParams.get("limit")).toBe("500");
    const table = new URL(standingsUrl("wcbb"));
    expect(table.searchParams.get("group")).toBe("50");
    expect(new URL(standingsUrl("nba")).searchParams.get("group")).toBeNull();
  });
});

describe("college basketball conferences", () => {
  it("are their own id space", () => {
    expect(conferenceName(8, "mcbb")).toBe("Big 12");
    expect(conferenceName(8, "cfb")).toBe("SEC");
    expect(conferenceName(13, "wcbb")).toBe("MAAC");
  });

  it("disagree only on the Summit League", () => {
    expect(conferenceName(49, "mcbb")).toBe("Summit League");
    expect(conferenceName(47, "wcbb")).toBe("Summit League");
    expect(isKnownConference(47, "mcbb")).toBe(false);
  });

  it("lead with the high majors and have no root above them", () => {
    const ids = topLevelIds("mcbb");
    expect(ids).toHaveLength(32);
    expect(new Set(ids.slice(0, 5))).toEqual(new Set([2, 4, 7, 8, 23]));
    expect(tier(29, "mcbb")).toBe("group5");
    expect(rootAbove({ league: "mcbb", id: 7 })).toBeUndefined();
  });

  it("wear their ncaa_conf marks", () => {
    expect(conferenceLogoUrl(4, "mcbb")).toBe(
      "https://a.espncdn.com/i/teamlogos/ncaa_conf/500/big_east.png"
    );
    expect(conferenceLogoUrl(30, "wcbb")).toBeUndefined();
  });
});

describe("college basketball payloads", () => {
  it("decode the scoreboard with inline conferences and ranks", () => {
    const games = transformScoreboard(
      (scoreboardJson as { events: EspnEvent[] }).events,
      "mcbb"
    );
    expect(games).toHaveLength(10);
    expect(games.every((game) => game.league === "mcbb")).toBe(true);
    expect(games.some((game) => game.homeTeam.team.conferenceId !== "")).toBe(true);
    expect(
      games.some((game) => game.homeTeam.ranking !== undefined || game.awayTeam.ranking !== undefined)
    ).toBe(true);
  });

  it("split the slate into conference sections that start closed", () => {
    const games = transformScoreboard(
      (scoreboardJson as { events: EspnEvent[] }).events,
      "mcbb"
    );
    const sections = buildSections(games, { followedTeamKeys: [] });
    const conferences = sections.filter((section) => section.kind === "conference");
    expect(conferences.length).toBeGreaterThan(1);
    expect(conferences.every((section) => section.league === "mcbb")).toBe(true);
    expect(conferences.every((section) => startsClosed(section.id))).toBe(true);
    expect(startsClosed("conf-cfb:8")).toBe(false);
    expect(startsClosed("league-nba")).toBe(false);
  });

  it("decode a conference table", () => {
    const tables = transformStandings(
      standingsJson as unknown as EspnStandingsResponse,
      "wcbb"
    );
    expect(tables.map((table) => table.name)).toEqual(["ACC"]);
    expect(tables[0].entries.length).toBeGreaterThan(10);
  });
});

describe("college basketball postseason", () => {
  it("names the NCAA tournament's rounds and nothing else", () => {
    const cases: [string | undefined, string | undefined][] = [
      ["NCAA Men's Basketball Championship - Midwest Region - First Four", "First Four"],
      ["NCAA Men's Basketball Championship - East Region - 1st Round", "First Round"],
      ["NCAA Men's Basketball Championship - West Region - 2nd Round", "Second Round"],
      ["NCAA Men's Basketball Championship - South Region - Sweet 16", "Sweet 16"],
      ["NCAA Men's Basketball Championship - West Region - Elite 8", "Elite Eight"],
      ["NCAA Men's Basketball Championship - Final Four", "Final Four"],
      ["NCAA Women's Basketball Championship - National Championship", "National Championship"],
      ["NIT - 1st Round", undefined],
      ["WBIT - Quarterfinal", undefined],
      ["College Basketball Crown - Semifinals", undefined],
      [undefined, undefined],
    ];
    for (const [headline, round] of cases) {
      expect(basketballRoundName(headline)).toBe(round);
    }
  });

  it("counts the NCAA final and conference tournament finals as trophies", () => {
    expect(
      trophyKindFromHeadline(
        "NCAA Men's Basketball Championship - National Championship",
        "mcbb"
      )
    ).toEqual({
      singular: "National Championship",
      plural: "National Championships",
      tier: "league",
    });
    expect(trophyKindFromHeadline("NIT - Championship", "mcbb")).toBeUndefined();
    expect(trophyKindFromHeadline("SEC Tournament - Final", "wcbb")?.singular).toBe(
      "SEC Tournament"
    );
    expect(
      trophyKindFromHeadline("Ivy League Tournament pres. by TIAA - Final", "mcbb")?.singular
    ).toBe("Ivy League Tournament");
    expect(trophyKindFromHeadline("Big Ten Tournament - Semifinal", "mcbb")).toBeUndefined();
    expect(trophyKindFromHeadline("Women's NIT - Final", "wcbb")).toBeUndefined();
  });
});
