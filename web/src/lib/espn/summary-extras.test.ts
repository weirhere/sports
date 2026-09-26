// The game summary's extras ported 2026-09-25: win probability, the
// standings block read in place of a fetch, and the `groups` shape the
// summary header and the rankings send a team in. Small inline fixtures,
// cut from live payloads (Georgia at Arkansas, 2026-09-19).

import { describe, it, expect } from "vitest";
import type { EspnSummaryStandings } from "./types";
import {
  conferenceIdFromGroups,
  transformMatchupStandings,
  transformTeam,
  transformWinProbability,
} from "./transformers";
import type { Team } from "@/lib/types";

describe("transformWinProbability", () => {
  const predictor = {
    homeTeam: { gameProjection: "29.7" },
    awayTeam: { gameProjection: "70.3" },
  };

  it("takes the per-play series once it has two points, clamped", () => {
    expect(
      transformWinProbability(predictor, [
        { homeWinPercentage: 0.0395 },
        { homeWinPercentage: 1.2 },
        { homeWinPercentage: -0.1 },
      ])
    ).toEqual({ kind: "series", points: [0.0395, 1, 0] });
  });

  it("falls back to the predictor, strings and all, before kickoff", () => {
    expect(transformWinProbability(predictor, [])).toEqual({
      kind: "pregame",
      home: 29.7,
      away: 70.3,
    });
    // One point is not a line; the predictor still answers.
    expect(
      transformWinProbability(predictor, [{ homeWinPercentage: 0.4 }])
    ).toEqual({ kind: "pregame", home: 29.7, away: 70.3 });
  });

  it("drops points it can't read rather than the series", () => {
    expect(
      transformWinProbability(undefined, [
        { homeWinPercentage: 0.5 },
        null,
        {},
        { homeWinPercentage: null },
        { homeWinPercentage: 0.6 },
      ])
    ).toEqual({ kind: "series", points: [0.5, 0.6] });
  });

  it("is absent where the payload has neither block (hockey)", () => {
    expect(transformWinProbability(undefined, undefined)).toBeUndefined();
    expect(
      transformWinProbability({ homeTeam: { gameProjection: "60" } }, [])
    ).toBeUndefined();
    expect(
      transformWinProbability(
        {
          homeTeam: { gameProjection: "n/a" },
          awayTeam: { gameProjection: 40 },
        },
        []
      )
    ).toBeUndefined();
    expect(
      transformWinProbability(
        { homeTeam: { gameProjection: 0 }, awayTeam: { gameProjection: 0 } },
        []
      )
    ).toBeUndefined();
  });
});

describe("conferenceIdFromGroups", () => {
  it("reads a summary header's bare group as the conference", () => {
    expect(conferenceIdFromGroups({ id: "5" })).toBe(5);
  });

  it("stops at a conference whose parent is the division root (rankings)", () => {
    expect(conferenceIdFromGroups({ id: "5", parent: { id: "80" } })).toBe(5);
    expect(conferenceIdFromGroups({ id: "20", parent: { id: "81" } })).toBe(20);
  });

  it("keeps the schedule endpoint's two shapes", () => {
    expect(
      conferenceIdFromGroups({
        id: "8",
        parent: { id: "80" },
        isConference: true,
      })
    ).toBe(8);
    // A division names its conference as its parent.
    expect(
      conferenceIdFromGroups({
        id: "163",
        parent: { id: "151" },
        isConference: false,
      })
    ).toBe(151);
  });

  it("walks up in the pro leagues, where 80 is not a division root", () => {
    expect(
      conferenceIdFromGroups(
        { id: "3", parent: { id: "7" }, isConference: false },
        "nfl"
      )
    ).toBe(7);
  });

  it("gives a summary-header team its conference", () => {
    const team = transformTeam(
      { id: "8", location: "Arkansas", groups: { id: "8" } },
      "cfb"
    );
    expect(team?.conferenceId).toBe("8");
    expect(team?.conferenceName).toBe("SEC");
  });
});

function team(id: string, conferenceId: string, school: string): Team {
  return {
    id,
    espnId: Number(id),
    league: "cfb",
    name: "",
    school,
    abbreviation: "",
    conferenceId,
    conferenceName: "",
    logoUrl: `https://example.test/${id}.png`,
  };
}

function entry(id: string, name: string, overall: string, conf: string) {
  return {
    id,
    team: name,
    logo: [
      { href: `https://a.espncdn.com/500/${id}.png`, rel: ["full", "default"] },
      { href: `https://a.espncdn.com/500-dark/${id}.png`, rel: ["full", "dark"] },
    ],
    stats: [
      { type: "total", summary: overall, displayValue: overall },
      { type: "vsconf", summary: conf, displayValue: conf },
    ],
  };
}

describe("transformMatchupStandings", () => {
  const georgia = team("61", "8", "Georgia");
  const arkansas = team("8", "8", "Arkansas");
  const block: EspnSummaryStandings = {
    groups: [
      {
        header: "2026 Southeastern Conference Standings",
        divisionHeader: "Southeastern Conference",
        shortDivisionHeader: "SEC",
        standings: {
          entries: [
            entry("333", "Alabama", "3-0", "1-0"),
            entry("61", "Georgia", "3-0", "1-0"),
            entry("8", "Arkansas", "1-2", "0-1"),
          ],
        },
      },
    ],
  };

  it("reads both conferences' tables out of the summary", () => {
    const [table, ...rest] = transformMatchupStandings(block, "cfb", [
      georgia,
      arkansas,
    ]);
    expect(rest).toHaveLength(0);
    expect(table.id).toBe("8");
    expect(table.name).toBe("SEC");
    expect(table.entries.map((row) => row.team.school)).toEqual([
      "Alabama",
      "Georgia",
      "Arkansas",
    ]);
    expect(table.entries[2]).toMatchObject({
      overallRecord: "1-2",
      conferenceRecord: "0-1",
    });
  });

  it("keeps the competing teams' own identity; the rest are stand-ins", () => {
    const [table] = transformMatchupStandings(block, "cfb", [georgia, arkansas]);
    expect(table.entries[1].team).toBe(georgia);
    // A stand-in takes the light logo, never the dark one.
    expect(table.entries[0].team.logoUrl).toBe(
      "https://a.espncdn.com/500/333.png"
    );
  });

  it("names a group neither team places from the payload's short header", () => {
    const [table] = transformMatchupStandings(block, "cfb", [
      team("1", "0", "Elsewhere"),
    ]);
    expect(table.id).toBe("");
    expect(table.name).toBe("SEC");
  });

  it("is empty outside college football, and where the block is missing", () => {
    expect(transformMatchupStandings(block, "nba", [georgia])).toEqual([]);
    expect(transformMatchupStandings(undefined, "cfb", [georgia])).toEqual([]);
    expect(
      transformMatchupStandings({ groups: [{ standings: {} }] }, "cfb", [
        georgia,
      ])
    ).toEqual([]);
  });
});
