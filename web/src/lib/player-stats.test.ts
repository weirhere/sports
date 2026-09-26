// The This season card's numbers and the game row's line. The registry is a
// straight copy of iOS `PlayerStats.headlineNames(for:)`, and these cases
// pin it so the two platforms can't drift apart quietly.

import { describe, expect, it } from "vitest";
import {
  categoryValue,
  gameLogHeadline,
  gameLogIsEmpty,
  gameLogResult,
  headlineNames,
  seasonHeadlines,
  seasonLabelFor,
  type PlayerGameLog,
  type PlayerGameLogEntry,
  type PlayerStatsCategory,
} from "./player-stats";

function category(overrides: Partial<PlayerStatsCategory> = {}): PlayerStatsCategory {
  return {
    id: "passing",
    title: "Passing",
    labels: ["GP", "CMP", "YDS", "TD", "INT"],
    names: [
      "gamesPlayed",
      "completions",
      "passingYards",
      "passingTouchdowns",
      "interceptions",
    ],
    displayNames: [
      "Games Played",
      "Completions",
      "Passing Yards",
      "Passing Touchdowns",
      "Interceptions",
    ],
    seasons: [
      { year: 2025, label: "2025", values: ["14", "250", "3200", "28", "7"] },
      { year: 2026, label: "2026", values: ["2", "40", "566", "5", "1"] },
    ],
    career: [],
    ...overrides,
  };
}

describe("the headline registry", () => {
  it("is keyed by category, not by league", () => {
    expect(headlineNames(category())).toEqual([
      "passingYards",
      "passingTouchdowns",
      "interceptions",
    ]);
    expect(headlineNames(category({ id: "rushing" }))).toEqual([
      "rushingYards",
      "rushingTouchdowns",
      "yardsPerRushAttempt",
    ]);
    expect(headlineNames(category({ id: "receiving" }))).toEqual([
      "receptions",
      "receivingYards",
      "receivingTouchdowns",
    ]);
    expect(headlineNames(category({ id: "averages" }))).toEqual([
      "avgPoints",
      "avgRebounds",
      "avgAssists",
    ]);
    expect(headlineNames(category({ id: "goaltender" }))).toEqual([
      "wins",
      "avgGoalsAgainst",
      "savePct",
    ]);
  });

  it("gives every skater category the same three", () => {
    for (const id of ["center", "leftWing", "rightWing", "defense", "forward", "skater"]) {
      expect(headlineNames(category({ id }))).toEqual(["goals", "assists", "points"]);
    }
  });

  it("falls back to ESPN's first three columns after games played", () => {
    const unknown = category({
      id: "kicking",
      names: ["gamesPlayed", "fieldGoalsMade", "fieldGoalAttempts", "longFieldGoalMade", "extraPointsMade"],
    });
    expect(headlineNames(unknown)).toEqual([
      "fieldGoalsMade",
      "fieldGoalAttempts",
      "longFieldGoalMade",
    ]);
  });
});

describe("the This season card", () => {
  const stats = { categories: [category()] };

  it("leads with games played, then the category's own numbers", () => {
    expect(seasonHeadlines(stats, 2026)).toEqual([
      { label: "GP", spokenLabel: "Games Played", value: "2" },
      { label: "YDS", spokenLabel: "Passing Yards", value: "566" },
      { label: "TD", spokenLabel: "Passing Touchdowns", value: "5" },
      { label: "INT", spokenLabel: "Interceptions", value: "1" },
    ]);
    expect(seasonLabelFor(stats, 2026)).toBe("2026");
  });

  it("is empty for a season with no line, rather than a row of zeroes", () => {
    expect(seasonHeadlines(stats, 2027)).toEqual([]);
    expect(seasonLabelFor(stats, 2027)).toBeUndefined();
    expect(seasonHeadlines({ categories: [] }, 2026)).toEqual([]);
  });

  it("reads only the first category — the player's own table", () => {
    const receiving = category({
      id: "receiving",
      labels: ["REC", "YDS", "TD"],
      names: ["receptions", "receivingYards", "receivingTouchdowns"],
      displayNames: ["Receptions", "Receiving Yards", "Receiving Touchdowns"],
      seasons: [{ year: 2026, label: "2026", values: ["2", "11", "1"] }],
    });
    const labels = seasonHeadlines(
      { categories: [receiving, category()] },
      2026
    ).map((headline) => headline.label);
    expect(labels).toEqual(["REC", "YDS", "TD"]);
  });

  it("takes a traded player's last line for the year and sums nothing", () => {
    const traded = category({
      seasons: [
        { year: 2026, label: "2026", teamId: "1", values: ["5", "90", "1000", "8", "2"] },
        { year: 2026, label: "2026", teamId: "2", values: ["3", "50", "400", "2", "1"] },
      ],
    });
    const yards = seasonHeadlines({ categories: [traded] }, 2026).find(
      (headline) => headline.label === "YDS"
    );
    expect(yards?.value).toBe("400");
  });

  it("skips a dash or a blank rather than printing it", () => {
    const sparse = category({
      seasons: [{ year: 2026, label: "2026", values: ["2", "40", "-", "", "1"] }],
    });
    expect(seasonHeadlines({ categories: [sparse] }, 2026).map((h) => h.label)).toEqual([
      "GP",
      "INT",
    ]);
  });

  it("never shows one label twice", () => {
    // Football's repeated "YDS": a fallback category that lists two columns
    // under one label keeps the first.
    const repeated = category({
      id: "unknown",
      labels: ["GP", "YDS", "YDS", "TD"],
      names: ["gamesPlayed", "a", "b", "c"],
      displayNames: [],
      seasons: [{ year: 2026, label: "2026", values: ["1", "10", "20", "3"] }],
    });
    expect(seasonHeadlines({ categories: [repeated] }, 2026)).toEqual([
      { label: "GP", spokenLabel: "GP", value: "1" },
      { label: "YDS", spokenLabel: "YDS", value: "10" },
      { label: "TD", spokenLabel: "TD", value: "3" },
    ]);
  });

  it("looks values up by name, not by position", () => {
    expect(categoryValue(category(), "passingYards", ["2", "40", "566", "5", "1"])).toBe("566");
    expect(categoryValue(category(), "nope", ["2"])).toBeUndefined();
    expect(categoryValue(category(), "interceptions", ["2"])).toBeUndefined();
  });
});

describe("a game row's line", () => {
  const log: PlayerGameLog = {
    labels: ["MIN", "REB", "AST", "PTS"],
    names: ["minutes", "totalRebounds", "assists", "points"],
    sections: [],
    availableSeasons: [],
  };
  const entry: PlayerGameLogEntry = {
    eventId: "1",
    isAway: false,
    result: "W",
    teamScore: "110",
    opponentScore: "104",
    values: ["36", "8", "9", "27"],
  };

  it("uses the player's category to pick its columns", () => {
    expect(gameLogHeadline(log, entry, "averages")).toBe("27 PTS · 8 REB · 9 AST");
  });

  it("falls back to the first three columns", () => {
    expect(gameLogHeadline(log, entry, undefined)).toBe("36 MIN · 8 REB · 9 AST");
  });

  it("prints the result with the player's side first", () => {
    expect(gameLogResult(entry)).toBe("W 110-104");
    expect(gameLogResult({ ...entry, teamScore: undefined })).toBe("W");
    expect(gameLogResult({ ...entry, result: undefined })).toBeUndefined();
  });

  it("calls a log with no games empty", () => {
    expect(gameLogIsEmpty(log)).toBe(true);
    expect(gameLogIsEmpty({ ...log, sections: [{ title: "x", entries: [entry] }] })).toBe(false);
  });
});
