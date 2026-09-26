// The team-stats mapper, against the shapes ESPN ships. Fixtures are trimmed
// from live responses (2026-09-25): Ohio State (college football team 194)
// in its regular season, and the Celtics answering September with a
// "2026-27 Preseason" that is all of 2025-26.

import { describe, it, expect } from "vitest";
import {
  athleteIdFromRef,
  headlineNames,
  leaderCategories,
  leaderTitle,
  leaderValueIsStatLine,
  teamLeadersUrl,
  teamStatHeadlines,
  teamStatsSeasonLabel,
  teamStatsUrl,
  transformTeamLeaders,
  transformTeamStats,
  type EspnTeamLeadersResponse,
  type EspnTeamStatsResponse,
} from "./team-stats";

const footballStats: EspnTeamStatsResponse = {
  season: { year: 2026, type: 2 },
  results: {
    stats: {
      categories: [
        {
          name: "receiving",
          displayName: "Receiving",
          stats: [
            { name: "receivingYards", displayName: "Receiving Yards", shortDisplayName: "Rec. Yards", abbreviation: "YDS", displayValue: "1,094" },
            // ESPN repeats this one inside the same category.
            { name: "receivingYards", displayName: "Receiving Yards", shortDisplayName: "Rec. Yards", abbreviation: "YDS", displayValue: "1,094" },
          ],
        },
        {
          name: "miscellaneous",
          displayName: "Miscellaneous",
          stats: [
            { name: "thirdDownConvPct", displayName: "3rd Down Conversion Percentage", shortDisplayName: "3RD%", abbreviation: "3RDC%", displayValue: "51.4" },
            { name: "turnOverDifferential", displayName: "Turnover Ratio", shortDisplayName: "DIFF", abbreviation: "DIFF", displayValue: "3" },
          ],
        },
        {
          name: "scoring",
          displayName: "Scoring",
          stats: [
            { name: "totalPointsPerGame", displayName: "Total Points Per Game", shortDisplayName: "TP/G", abbreviation: "TP/G", displayValue: "41.3" },
            { name: "gamesPlayed", displayName: "Games Played", abbreviation: "GP", displayValue: "3" },
          ],
        },
        // A category with nothing usable in it doesn't become an empty card.
        { name: "kicking", displayName: "Kicking", stats: [{ name: "fieldGoals" }] },
        { displayName: "Nameless", stats: [{ name: "x", displayValue: "1" }] },
      ],
    },
    opponent: [
      {
        name: "passing",
        displayName: "Passing",
        stats: [
          { name: "completionPct", displayName: "Completion Percentage", shortDisplayName: "CMP%", abbreviation: "CMP%", displayValue: "53.7", rankDisplayValue: "19th" },
          { name: "completions", displayName: "Completions", abbreviation: "CMP", displayValue: "51", rankDisplayValue: "" },
        ],
      },
    ],
  },
};

const nbaRollover: EspnTeamStatsResponse = {
  season: { year: 2027, type: 1 },
  results: {
    stats: {
      categories: [
        {
          name: "general",
          displayName: "General",
          stats: [
            { name: "avgRebounds", displayName: "Rebounds Per Game", shortDisplayName: "RPG", abbreviation: "REB", displayValue: "46.4" },
            { name: "gamesPlayed", displayName: "Games Played", shortDisplayName: "GP", abbreviation: "GP", displayValue: "82" },
          ],
        },
        {
          name: "offensive",
          displayName: "Offensive",
          stats: [
            { name: "avgPoints", displayName: "Points Per Game", shortDisplayName: "PPG", abbreviation: "PTS", displayValue: "114.4" },
            { name: "fieldGoalPct", displayName: "Field Goal Percentage", shortDisplayName: "FG%", abbreviation: "FG%", displayValue: "46.5" },
          ],
        },
      ],
    },
  },
};

describe("transformTeamStats", () => {
  it("keeps ESPN's names, drops repeats and empty categories", () => {
    const stats = transformTeamStats(footballStats, "cfb");
    expect(stats.seasonLabel).toBe("2026");
    expect(stats.categories.map((c) => c.id)).toEqual([
      "receiving",
      "miscellaneous",
      "scoring",
    ]);
    expect(stats.categories[0].stats).toHaveLength(1);
    // A short name over six characters falls back to the abbreviation.
    expect(stats.categories[0].stats[0].label).toBe("YDS");
    expect(stats.categories[0].stats[0].fullName).toBe("Receiving Yards");
  });

  it("carries football's opponents' block with its ranks", () => {
    const stats = transformTeamStats(footballStats, "cfb");
    expect(stats.opponent).toHaveLength(1);
    expect(stats.opponent[0].stats[0].rank).toBe("19th");
    // An empty rank is no rank.
    expect(stats.opponent[0].stats[1].rank).toBeUndefined();
  });

  it("leads the Overview with the league's headline registry, in order", () => {
    const stats = transformTeamStats(footballStats, "cfb");
    // `yardsPerGame` wasn't sent, so its tile isn't drawn.
    expect(teamStatHeadlines(stats, "cfb").map((s) => s.name)).toEqual([
      "totalPointsPerGame",
      "thirdDownConvPct",
      "turnOverDifferential",
    ]);
  });

  it("relabels a rollover preseason as the season its games are from", () => {
    const stats = transformTeamStats(nbaRollover, "nba");
    expect(stats.seasonLabel).toBe("2025-26");
    expect(teamStatHeadlines(stats, "nba").map((s) => s.label)).toEqual([
      "PPG",
      "RPG",
      "FG%",
    ]);
    expect(stats.opponent).toEqual([]);
  });

  it("answers empty for a payload with no season", () => {
    const stats = transformTeamStats({ results: footballStats.results }, "cfb");
    expect(stats.categories).toEqual([]);
    expect(stats.seasonLabel).toBeUndefined();
  });

  it("answers empty for an empty payload", () => {
    expect(transformTeamStats({}, "nhl").categories).toEqual([]);
  });
});

describe("teamStatsSeasonLabel", () => {
  it("trusts a regular or postseason label", () => {
    expect(teamStatsSeasonLabel({ year: 2027, type: 2 }, "nhl", 10)).toBe("2026-27");
    expect(teamStatsSeasonLabel({ year: 2026, type: 3 }, "nfl", undefined)).toBe("2026");
  });

  it("hides a real preseason — a handful of exhibition games", () => {
    expect(teamStatsSeasonLabel({ year: 2027, type: 1 }, "nba", 4)).toBeUndefined();
    expect(teamStatsSeasonLabel({ year: 2027, type: 1 }, "nba", undefined)).toBeUndefined();
  });

  it("names a full season behind a preseason label by its own year", () => {
    expect(teamStatsSeasonLabel({ year: 2027, type: 1 }, "nhl", 82)).toBe("2025-26");
    // Twenty is the floor, inclusive.
    expect(teamStatsSeasonLabel({ year: 2027, type: 1 }, "nba", 20)).toBe("2025-26");
    expect(teamStatsSeasonLabel({ year: 2026, type: 1 }, "cfb", 13)).toBeUndefined();
  });
});

const footballLeaders: EspnTeamLeadersResponse = {
  categories: [
    {
      name: "rushingLeader",
      displayName: "Rushing Leader",
      leaders: [
        {
          displayValue: "58 CAR, 312 YDS, 4 TD",
          athlete: { $ref: "http://sports.core.api.espn.com/v2/sports/football/leagues/college-football/seasons/2026/athletes/4870906?lang=en&region=us" },
        },
      ],
    },
    {
      name: "passingLeader",
      displayName: "Passing Leader",
      leaders: [
        {
          displayValue: "56/79, 839 YDS, 6 TD, 1 INT",
          athlete: { $ref: "http://sports.core.api.espn.com/v2/sports/football/leagues/college-football/seasons/2026/athletes/4889929?lang=en" },
        },
      ],
    },
    // Not in the registry: dropped.
    { name: "passingYards", displayName: "Passing Yards", leaders: [{ displayValue: "839", athlete: { $ref: ".../athletes/4889929" } }] },
    // In the registry, but with no athlete to name.
    { name: "sacks", displayName: "Sacks", leaders: [{ displayValue: "3.0" }] },
    { name: "interceptions", displayName: "Interceptions", leaders: [] },
  ],
};

describe("transformTeamLeaders", () => {
  it("reads the registry in its own order, not the payload's", () => {
    const leaders = transformTeamLeaders(footballLeaders, "cfb");
    expect(leaders.map((l) => l.category)).toEqual([
      "passingLeader",
      "rushingLeader",
    ]);
    expect(leaders[0]).toEqual({
      category: "passingLeader",
      title: "Passing",
      athleteId: "4889929",
      value: "56/79, 839 YDS, 6 TD, 1 INT",
    });
    expect(leaderValueIsStatLine(leaders[0])).toBe(true);
  });

  it("keeps a single number as a single number", () => {
    const leaders = transformTeamLeaders(
      {
        categories: [
          {
            name: "pointsPerGame",
            displayName: "Points Per Game",
            leaders: [{ displayValue: "28.7", athlete: { $ref: "https://x/athletes/3917376?lang=en" } }],
          },
        ],
      },
      "nba"
    );
    expect(leaders).toHaveLength(1);
    expect(leaders[0].title).toBe("Points Per Game");
    expect(leaderValueIsStatLine(leaders[0])).toBe(false);
  });

  it("answers nothing for an empty payload", () => {
    expect(transformTeamLeaders({}, "nhl")).toEqual([]);
  });
});

describe("registries", () => {
  it("are straight copies of the iOS ones", () => {
    expect(headlineNames("nfl")).toEqual(headlineNames("cfb"));
    expect(headlineNames("nhl")).toEqual([
      "goals",
      "avgGoalsAgainst",
      "savePct",
      "faceoffPercent",
    ]);
    expect(leaderCategories("nba")).toEqual([
      "pointsPerGame",
      "reboundsPerGame",
      "assistsPerGame",
      "stealsPerGame",
      "blocksPerGame",
    ]);
    expect(leaderCategories("nhl")).toEqual([
      "points",
      "goals",
      "assists",
      "wins",
      "savePct",
    ]);
  });

  it("strips a heading about a heading", () => {
    expect(leaderTitle("Receiving Leader")).toBe("Receiving");
    expect(leaderTitle("Tackles")).toBe("Tackles");
  });
});

describe("urls", () => {
  it("reads stats off site.web.api, never site.api", () => {
    expect(teamStatsUrl("nba", "2")).toBe(
      "https://site.web.api.espn.com/apis/site/v2/sports/basketball/nba/teams/2/statistics"
    );
  });

  it("asks the core API for a season's regular-season leaders", () => {
    expect(teamLeadersUrl("cfb", "194", 2026)).toBe(
      "https://sports.core.api.espn.com/v2/sports/football/leagues/college-football/seasons/2026/types/2/teams/194/leaders"
    );
  });

  it("lifts an athlete id out of a $ref", () => {
    expect(athleteIdFromRef("http://x/seasons/2026/athletes/3139477?lang=en")).toBe("3139477");
    expect(athleteIdFromRef("http://x/seasons/2026/teams/5")).toBeUndefined();
  });
});
