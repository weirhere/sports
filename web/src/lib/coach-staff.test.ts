import { describe, it, expect } from "vitest";
import { coachLines, coachesFileKey, staffFor } from "./coach-staff";

const file = {
  leagues: {
    "college-football": {
      "113": {
        source: "https://en.wikipedia.org/wiki/UMass_Minutemen_football",
        staff: [
          { name: "Shane Montgomery", role: "Offensive coordinator/quarterbacks" },
          { name: "", role: "Nobody" },
          { role: "No name" },
          { name: "Ben Albert" },
        ],
      },
    },
    nfl: { "12": { staff: "not a list" } },
  },
};

describe("coach staff", () => {
  it("keys the file by ESPN's league segment", () => {
    expect(coachesFileKey("cfb")).toBe("college-football");
    expect(coachesFileKey("nfl")).toBe("nfl");
    expect(coachesFileKey("nhl")).toBe("nhl");
  });

  it("reads a team's staff and degrades a malformed entry, never the list", () => {
    expect(staffFor(file, "cfb", "113")).toEqual([
      { name: "Shane Montgomery", role: "Offensive coordinator/quarterbacks" },
      { name: "Ben Albert", role: "" },
    ]);
    expect(staffFor(file, "cfb", "999")).toEqual([]);
    expect(staffFor(file, "nfl", "12")).toEqual([]);
    expect(staffFor(undefined, "nba", "13")).toEqual([]);
    expect(staffFor("garbage", "nba", "13")).toEqual([]);
  });

  it("leads with the head coach, linked, then the staff in the file's order", () => {
    const lines = coachLines({ id: "27", name: "Jim Harbaugh" }, [{ name: "Greg Roman", role: "Offensive coordinator" }]);
    expect(lines.map((line) => [line.name, line.role, line.coachId])).toEqual([
      ["Jim Harbaugh", "Head coach", "27"],
      ["Greg Roman", "Offensive coordinator", undefined],
    ]);
    expect(coachLines(undefined, [])).toEqual([]);
  });
});
