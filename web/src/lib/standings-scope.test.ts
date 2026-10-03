import { describe, expect, it } from "vitest";
import { defaultScope, scopesFor } from "./standings-scope";

describe("defaultScope", () => {
  it("opens a pro conference page on its divisions, stacked", () => {
    // The AFC (8) and the NBA's East (5): divisions have no pages of their
    // own, so the conference is where they're read (iOS, 2026-09-26).
    for (const ref of [
      { league: "nfl", id: 8 },
      { league: "nba", id: 5 },
    ] as const) {
      expect(defaultScope(scopesFor(ref), "conference")).toBe("division");
    }
  });

  it("opens the league page on the league's own table", () => {
    expect(defaultScope(scopesFor({ league: "nfl", id: 9 }), "conference")).toBe(
      "league"
    );
  });

  it("offers nothing to open on in college football", () => {
    expect(defaultScope(scopesFor({ league: "cfb", id: 8 }), "conference")).toBe(
      undefined
    );
  });

  it("still opens a team page on its conference", () => {
    expect(
      defaultScope(["league", "conference", "division"], "team")
    ).toBe("conference");
  });
});
