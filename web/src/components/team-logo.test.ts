import { describe, expect, it } from "vitest";
import { teamLogoSrc } from "./team-logo";
import type { Team } from "@/lib/types";
import type { League } from "@/lib/leagues";

function team(espnId: number, league: League, logoUrl = ""): Team {
  return {
    id: String(espnId),
    espnId,
    league,
    name: "",
    school: "Team",
    abbreviation: "TM",
    conferenceId: "0",
    conferenceName: "",
    logoUrl,
  };
}

describe("team marks are per league", () => {
  it("prefers the mark the payload published", () => {
    // Derivation can't work for the NHL at all — it files by abbreviation,
    // not by id — so the payload's own URL is the rule, not the fallback.
    const seattle = team(
      124292,
      "nhl",
      "https://a.espncdn.com/i/teamlogos/nhl/500/scoreboard/sea.png"
    );
    expect(teamLogoSrc(seattle)).toContain("/nhl/500/scoreboard/sea.png");
  });

  it("derives from the LEAGUE's bucket, never a hardcoded college one", () => {
    // The bug this closes: the mark was built from a bare id against the
    // college bucket, so New England (NFL 17) wore Claremont-Mudd-Scripps
    // and Seattle (NFL 26) wore UCLA.
    expect(teamLogoSrc(team(17, "nfl"))).toBe(
      "https://a.espncdn.com/i/teamlogos/nfl/500/17.png"
    );
    expect(teamLogoSrc(team(26, "nfl"))).toBe(
      "https://a.espncdn.com/i/teamlogos/nfl/500/26.png"
    );
    // And the same ids in college football still resolve to college marks.
    expect(teamLogoSrc(team(26, "cfb"))).toBe(
      "https://a.espncdn.com/i/teamlogos/ncaa/500/26.png"
    );
  });

  it("never returns a college URL for a pro team", () => {
    for (const league of ["nfl", "nba", "nhl"] as const) {
      expect(teamLogoSrc(team(5, league))).not.toContain("/ncaa/");
    }
  });
});
