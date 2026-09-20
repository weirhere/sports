// The roster row → player page mapping. Mirrors iOS
// `sportsTests/PlayerIdentityTests.swift` assertion for assertion, because
// the two are one product and this is the file that proves it.

import { describe, it, expect } from "vitest";
import {
  findRosterPlayer,
  playerHref,
  playerMetaLine,
  playerProfileRows,
  playerSpokenSummary,
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

describe("the hero's meta line", () => {
  it("reads team, number, position", () => {
    expect(playerMetaLine(player(), "Georgia")).toBe("Georgia · #11 · QB");
  });

  it("drops each missing part on its own", () => {
    expect(playerMetaLine(player({ jersey: undefined }), "Georgia")).toBe(
      "Georgia · QB"
    );
    expect(
      playerMetaLine(player({ jersey: undefined, position: undefined }), "Georgia")
    ).toBe("Georgia");
    // A team name the schedule fetch never returned.
    expect(
      playerMetaLine(player({ jersey: undefined, position: undefined }))
    ).toBe("");
    // An empty string is ESPN's other way of not knowing.
    expect(playerMetaLine(player({ jersey: "" }), "Georgia")).toBe("Georgia · QB");
  });
});

describe("the spoken summary", () => {
  it("is a sentence, with the position spoken in full", () => {
    expect(playerSpokenSummary(player(), "Georgia")).toBe(
      "Carson Beck, Georgia, number 11, Quarterback"
    );
  });

  it("falls back to the abbreviation when that is all there is", () => {
    expect(
      playerSpokenSummary(
        player({ jersey: undefined, positionName: undefined }),
        "Georgia"
      )
    ).toBe("Carson Beck, Georgia, QB");
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
