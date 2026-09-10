import { describe, expect, it } from "vitest";
import { scoreboardUrl, seasonWindowUrl, espnDayRange } from "./endpoints";

describe("the groups parameter", () => {
  it("sends a named group for every league", () => {
    // ESPN honours `groups=` well beyond college football: probed live
    // 2026-09-09, `groups=4` on the NFL returns the three AFC East games of
    // a week rather than all fifteen. Dropping it silently was how a
    // division's Games tab came to show the whole league.
    expect(scoreboardUrl("nfl", { groups: 4 })).toContain("groups=4");
    expect(scoreboardUrl("nba", { groups: 1 })).toContain("groups=1");
    expect(scoreboardUrl("nhl", { groups: 32 })).toContain("groups=32");
    expect(scoreboardUrl("cfb", { groups: 8 })).toContain("groups=8");
  });

  it("defaults to FBS only where a request has to pick a division", () => {
    expect(scoreboardUrl("cfb")).toContain("groups=80");
    expect(scoreboardUrl("nfl")).not.toContain("groups=");
    expect(scoreboardUrl("nba")).not.toContain("groups=");
  });

  it("carries the group through a season window", () => {
    const url = seasonWindowUrl(
      "nfl",
      new Date(2026, 6, 1),
      new Date(2027, 1, 28),
      { groups: 4 }
    );
    expect(url).toContain("groups=4");
    expect(url).toContain(
      `dates=${espnDayRange(new Date(2026, 6, 1), new Date(2027, 1, 28))}`
    );
  });
});

describe("the season axis", () => {
  it("never spells a season as a bare year without a week", () => {
    // A bare `dates=YYYY` is the *calendar* year — it opens a season's slate
    // with the previous January's bowls and truncates before December.
    expect(scoreboardUrl("cfb", { seasonYear: 2019 })).not.toContain(
      "dates=2019"
    );
    expect(scoreboardUrl("cfb", { seasonYear: 2019, week: 3 })).toContain(
      "dates=2019"
    );
  });
});
