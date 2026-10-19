// The Roster tab's ESPN mappers, against the shapes probed live 2026-10-18.

import { describe, it, expect } from "vitest";
import {
  transformDepthChart,
  transformInjuries,
  transformLineup,
  transformOnIce,
} from "./game-roster-transformers";
import { espnPosition, idFromRef } from "./positions";
import { transformBoxScore } from "./transformers";
import { depthChartUrl, gameLineupUrl } from "./endpoints";

describe("transformLineup", () => {
  it("maps the NFL's game-day roster: starters, inactives, positions off the table", () => {
    const entries = transformLineup(
      {
        entries: [
          {
            playerId: 3139477,
            displayName: "P. Mahomes",
            jersey: "15",
            starter: true,
            position: { $ref: "http://sports.core.api.espn.com/v2/sports/football/leagues/nfl/positions/8?lang=en" },
            statistics: { $ref: "…/statistics/0" },
          },
          { playerId: 4035, displayName: "E. Greene III", jersey: "33", didNotPlay: true },
          { displayName: "No id" },
        ],
      },
      "nfl"
    );
    expect(entries).toHaveLength(2);
    expect(entries[0]).toMatchObject({
      athleteId: "3139477",
      shortName: "P. Mahomes",
      jersey: "15",
      isStarter: true,
      position: { abbreviation: "QB", name: "Quarterback" },
      recordedStat: true,
    });
    expect(entries[1]).toMatchObject({ athleteId: "4035", didNotPlay: true, recordedStat: false });
    expect(entries[1]!.note).toBeUndefined();
  });

  it("cases the NBA's reason and names a hockey scratch with none", () => {
    const entries = transformLineup(
      {
        entries: [
          { playerId: "1", didNotPlay: true, reason: "COACH'S DECISION" },
          { playerId: "2", scratched: true },
          { playerId: "3", scratched: true, scratchReason: "INJURED" },
        ],
      },
      "nhl"
    );
    expect(entries.map((entry) => entry.note)).toEqual(["Coach's decision", "Scratched", "Injured"]);
    expect(entries[1]!.isScratched).toBe(true);
  });
});

describe("transformDepthChart", () => {
  it("flattens every chart's slots in position-id order", () => {
    const slots = transformDepthChart({
      items: [
        {
          positions: {
            sg: {
              position: { id: "2", abbreviation: "SG", displayName: "Shooting Guard" },
              athletes: [{ athlete: { $ref: "…/athletes/2?lang=en" }, rank: 1 }],
            },
            pg: {
              position: { id: "1", abbreviation: "PG", displayName: "Point Guard" },
              athletes: [
                { athlete: { $ref: "…/athletes/1?lang=en" }, rank: 1 },
                { athlete: { $ref: "…/athletes/3?lang=en" }, rank: 2 },
                { athlete: { $ref: "…/athletes/4" } },
              ],
            },
            c: { athletes: [{ athlete: { $ref: "…/athletes/5?lang=en" }, rank: 1 }] },
          },
        },
      ],
    });
    expect(slots).toEqual([
      { position: "PG", positionName: "Point Guard", rank: 1, athleteId: "1" },
      { position: "PG", positionName: "Point Guard", rank: 2, athleteId: "3" },
      { position: "SG", positionName: "Shooting Guard", rank: 1, athleteId: "2" },
      { position: "C", positionName: undefined, rank: 1, athleteId: "5" },
    ]);
  });
});

describe("transformInjuries", () => {
  it("keeps a team's list, requires a name, and drops an undisclosed detail", () => {
    const teams = transformInjuries([
      {
        team: { id: "34" },
        injuries: [
          {
            status: "Questionable",
            athlete: { id: "1", displayName: "Hurt Guy", jersey: "9", position: { abbreviation: "CB" } },
            details: { type: "Neck", returnDate: "2026-10-25" },
          },
          { type: { description: "out" }, athlete: { fullName: "Mystery Man" }, details: { type: "Undisclosed" } },
          { status: "Out" },
        ],
      },
      { team: { id: "12" }, injuries: [] },
      { injuries: [{ status: "Out", athlete: { displayName: "No team" } }] },
    ]);
    expect(teams).toHaveLength(1);
    expect(teams[0]!.teamId).toBe("34");
    expect(teams[0]!.injuries).toEqual([
      {
        id: "1",
        name: "Hurt Guy",
        jersey: "9",
        position: "CB",
        headshotUrl: undefined,
        status: "Questionable",
        detail: "Neck",
        returnDate: "2026-10-25",
      },
      {
        id: "34-Mystery Man",
        name: "Mystery Man",
        jersey: undefined,
        position: undefined,
        headshotUrl: undefined,
        status: "Out",
        detail: undefined,
        returnDate: undefined,
      },
    ]);
  });
});

describe("transformOnIce", () => {
  it("counts only the skaters in play", () => {
    expect(
      transformOnIce([
        {
          teamId: "25",
          entries: [
            { athleteid: "1", whereabouts: { description: "In Play" } },
            { athleteid: "2", whereabouts: { description: "Bench" } },
            { athleteid: "3", whereabouts: { description: "in play" } },
          ],
        },
        { teamId: "6", entries: [{ athleteid: "9", whereabouts: { description: "Penalty Box" } }] },
      ])
    ).toEqual({ "25": ["1", "3"] });
  });
});

describe("positions", () => {
  it("resolves ids per sport and reads an id off a ref", () => {
    expect(espnPosition("8", "cfb")).toEqual({ abbreviation: "QB", name: "Quarterback" });
    expect(espnPosition("1", "nba")).toEqual({ abbreviation: "PG", name: "Point Guard" });
    expect(espnPosition("13", "nhl")).toEqual({ abbreviation: "LD", name: "Left Defense" });
    expect(espnPosition("999", "nfl")).toBeUndefined();
    expect(idFromRef("http://x/v2/sports/football/leagues/nfl/positions/30?lang=en", "positions")).toBe("30");
    expect(idFromRef("…/seasons/2026/athletes/4430841?lang=en", "athletes")).toBe("4430841");
    expect(idFromRef(undefined, "athletes")).toBeUndefined();
  });
});

describe("transformBoxScore — lineup flags", () => {
  it("carries basketball's starter and DNP flags and the athlete's position", () => {
    const [team] = transformBoxScore(
      {
        players: [
          {
            team: { id: "13" },
            statistics: [
              {
                name: null as unknown as undefined,
                labels: ["MIN"],
                athletes: [
                  { athlete: { id: "1", displayName: "Luka Doncic", position: { abbreviation: "PG", displayName: "Point Guard" } }, stats: ["36"], starter: true },
                  { athlete: { id: "2", displayName: "Sat Guy" }, stats: ["0"], didNotPlay: true, reason: "COACH'S DECISION" },
                  { athlete: { id: "3", displayName: "Played" }, stats: ["5"] },
                ],
              },
            ],
          },
        ],
      },
      "nba"
    );
    const players = team!.categories[0]!.players;
    expect(players[0]).toMatchObject({ isStarter: true, didNotPlay: false, position: "PG", positionName: "Point Guard" });
    expect(players[1]).toMatchObject({ isStarter: undefined, didNotPlay: true, didNotPlayReason: "Coach's decision" });
    expect(players[2]).toMatchObject({ isStarter: undefined, didNotPlay: false });
  });
});

describe("endpoints", () => {
  it("builds the core API's game-day roster and depth chart URLs", () => {
    expect(gameLineupUrl("nfl", "401", "34")).toBe(
      "https://sports.core.api.espn.com/v2/sports/football/leagues/nfl/events/401/competitions/401/competitors/34/roster"
    );
    // The NBA names a season by the year it ends: our 2026 is ESPN's 2027.
    expect(depthChartUrl("nba", "13", 2026)).toBe(
      "https://sports.core.api.espn.com/v2/sports/basketball/leagues/nba/seasons/2027/teams/13/depthcharts"
    );
    expect(depthChartUrl("cfb", "61", 2026)).toContain("/seasons/2026/teams/61/depthcharts");
  });
});
