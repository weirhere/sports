import { describe, it, expect } from "vitest";
import {
  rosterMetric,
  rosterMetricValue,
  rosterSentence,
  spokenMetric,
} from "./roster-metric";
import type { RosterPlayer } from "./types";

const collegePlayer: RosterPlayer = {
  id: "5269389",
  name: "Chris Booker",
  jersey: "73",
  position: "OL",
  positionName: "Offensive Lineman",
  height: "6' 4\"",
  weight: "288 lbs",
  classAbbreviation: "FR",
};

const proPlayer: RosterPlayer = {
  id: "5113969",
  name: "Cameron Carr",
  position: "G",
  positionName: "Guard",
  height: "6' 5\"",
  weight: "184 lbs",
  age: 21,
};

describe("rosterMetric", () => {
  it("gives college football a class column, the pro leagues an age one", () => {
    expect(rosterMetric("cfb").caption).toBe("CLASS");
    for (const league of ["nfl", "nba", "nhl"] as const) {
      expect(rosterMetric(league).caption).toBe("AGE");
    }
  });

  it("reads the value its own league actually publishes", () => {
    expect(rosterMetricValue(collegePlayer, rosterMetric("cfb"))).toBe("FR");
    expect(rosterMetricValue(proPlayer, rosterMetric("nba"))).toBe("21");
  });

  it("is undefined where the league's own field is missing", () => {
    // College football ships no age at all (0 of 100 players), which is the
    // whole reason the column is per league — an AGE caption there would
    // promise a number that never arrives.
    expect(rosterMetricValue(collegePlayer, rosterMetric("nfl"))).toBeUndefined();
    expect(rosterMetricValue(proPlayer, rosterMetric("cfb"))).toBeUndefined();
  });
});

describe("spokenMetric", () => {
  it("spells the class out rather than reading initials", () => {
    expect(spokenMetric("FR", rosterMetric("cfb"))).toBe("freshman");
    expect(spokenMetric("SR", rosterMetric("cfb"))).toBe("senior");
  });

  it("passes an unknown class through rather than dropping it", () => {
    expect(spokenMetric("GR", rosterMetric("cfb"))).toBe("GR");
  });

  it("names the age", () => {
    expect(spokenMetric("21", rosterMetric("nba"))).toBe("age 21");
  });
});

describe("rosterSentence", () => {
  it("says the position in full — 'QB' would be read as letters", () => {
    expect(rosterSentence(collegePlayer, rosterMetric("cfb"))).toBe(
      "Number 73, Chris Booker, Offensive Lineman, 6' 4\", 288 lbs, freshman"
    );
  });

  it("drops the parts ESPN didn't ship", () => {
    expect(rosterSentence(proPlayer, rosterMetric("nba"))).toBe(
      "Cameron Carr, Guard, 6' 5\", 184 lbs, age 21"
    );
  });

  it("carries an injury designation last", () => {
    expect(
      rosterSentence(
        { ...proPlayer, injuryStatus: "Questionable" },
        rosterMetric("nfl")
      )
    ).toContain("age 21, Questionable");
  });
});
