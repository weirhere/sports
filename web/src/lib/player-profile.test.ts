// The roster row → player page mapping. Mirrors iOS
// `sportsTests/PlayerIdentityTests.swift` assertion for assertion, because
// the two are one product and this is the file that proves it.

import { describe, it, expect } from "vitest";
import {
  findRosterPlayer,
  mergePlayer,
  playerHref,
  playerProfileRows,
  playerSpokenSummary,
  type AthleteProfile,
} from "./player-profile";
import type { RosterPlayer, TeamRoster } from "./types";

function player(overrides: Partial<RosterPlayer> = {}): RosterPlayer {
  return {
    id: "4430841",
    name: "Carson Beck",
    jersey: "11",
    position: "QB",
    positionName: "Quarterback",
    height: "6' 4\"",
    weight: "220 lbs",
    classAbbreviation: "JR",
    ...overrides,
  };
}

const labels = (p: RosterPlayer, league: Parameters<typeof playerProfileRows>[1]) =>
  playerProfileRows(p, league).map((row) => row.label);

describe("the league's own third row", () => {
  it("gives college football a class and never an age", () => {
    expect(labels(player(), "cfb")).toContain("Class");
    expect(labels(player(), "cfb")).not.toContain("Age");
  });

  it("gives the pro leagues an age and never a class", () => {
    for (const league of ["nfl", "nba", "nhl"] as const) {
      const pro = player({ age: 27, classAbbreviation: undefined });
      expect(labels(pro, league)).toContain("Age");
      expect(labels(pro, league)).not.toContain("Class");
    }
  });

  it("spells out only the class abbreviations it knows", () => {
    const classValue = (abbreviation: string) =>
      playerProfileRows(player({ classAbbreviation: abbreviation }), "cfb").find(
        (row) => row.label === "Class"
      )?.value;
    expect(classValue("FR")).toBe("Freshman");
    expect(classValue("SR")).toBe("Senior");
    // Capitalizing an unmapped value would spell "GR" as "Gr".
    expect(classValue("GR")).toBe("GR");
  });
});

describe("profile rows", () => {
  it("follow the design's order", () => {
    expect(labels(player(), "cfb")).toEqual([
      "Height",
      "Weight",
      "Class",
      "Position",
      "Jersey",
    ]);
  });

  it("skip what ESPN did not send", () => {
    const sparse = player({
      jersey: undefined,
      position: undefined,
      positionName: undefined,
      height: undefined,
      weight: undefined,
      classAbbreviation: undefined,
    });
    expect(playerProfileRows(sparse, "cfb")).toEqual([]);
  });

  it("give an injury designation its own row, last", () => {
    const hurt = player({
      age: 27,
      classAbbreviation: undefined,
      injuryStatus: "Questionable",
    });
    const rows = playerProfileRows(hurt, "nfl");
    expect(rows.at(-1)).toEqual({ label: "Status", value: "Questionable" });
  });
});

describe("the spoken summary", () => {
  // Name and club, which is exactly what the hero draws (2026-09-21). The
  // number and the position are Profile rows, and speak there.
  it("is the name and the club, and nothing the hero doesn't show", () => {
    expect(playerSpokenSummary(player(), "Georgia Bulldogs")).toBe(
      "Carson Beck, Georgia Bulldogs"
    );
  });

  it("is the name alone when there is no club", () => {
    expect(playerSpokenSummary(player())).toBe("Carson Beck");
  });
});

describe("merging the roster row with the athlete payload", () => {
  const athlete: AthleteProfile = {
    name: "Carson Beck",
    age: 23,
    jersey: "99",
    position: "QB",
    positionName: "Quarterback",
    height: "6' 5\"",
    weight: "230 lbs",
    headshotUrl: "https://example.com/full.png",
    injuryStatus: "Out",
    teamId: "2390",
  };

  it("keeps the roster's facts wherever both sources answer", () => {
    const merged = mergePlayer("4430841", player(), athlete);
    expect(merged?.jersey).toBe("11");
    expect(merged?.height).toBe("6' 4\"");
    expect(merged?.classAbbreviation).toBe("JR");
  });

  it("fills the roster's gaps from the athlete payload", () => {
    const merged = mergePlayer(
      "4430841",
      player({ height: undefined, headshotUrl: undefined }),
      athlete
    );
    expect(merged?.height).toBe("6' 5\"");
    expect(merged?.headshotUrl).toBe("https://example.com/full.png");
    expect(merged?.injuryStatus).toBe("Out");
  });

  it("builds the page from the athlete alone when the roster doesn't list him", () => {
    const merged = mergePlayer("4430841", undefined, athlete);
    expect(merged).toMatchObject({ id: "4430841", name: "Carson Beck", jersey: "99" });
  });

  it("builds the page from the roster alone when the athlete fetch failed", () => {
    expect(mergePlayer("4430841", player(), undefined)).toEqual(player());
  });

  it("is nothing when neither source can name him", () => {
    expect(mergePlayer("4430841", undefined, undefined)).toBeUndefined();
    expect(mergePlayer("4430841", undefined, { teamId: "1" })).toBeUndefined();
  });
});

describe("the route", () => {
  // The team id is in the path because a URL has to rebuild the page from
  // nothing, and the roster endpoint — the only thing that knows this
  // player — is addressed by team.
  it("carries league, team and athlete", () => {
    expect(playerHref("cfb", "61", "4430841")).toBe("/player/cfb/61/4430841");
  });
});

describe("finding the player a URL names", () => {
  const roster: TeamRoster = {
    groups: [
      { name: "Offense", players: [player({ id: "1", name: "One" })] },
      {
        name: "Defense",
        players: [
          player({ id: "2", name: "Two" }),
          player({ id: "3", name: "Three" }),
        ],
      },
    ],
  };

  it("searches across every group, not just the first", () => {
    expect(findRosterPlayer(roster, "3")?.name).toBe("Three");
  });

  it("returns nothing for an id this team has no player for", () => {
    expect(findRosterPlayer(roster, "999")).toBeUndefined();
  });
});
