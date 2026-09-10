import { describe, expect, it } from "vitest";
import type { Game, GameTeam, Team } from "./types";
import { bySeasonPhase, seasonPhaseOf, seasonPhaseTitle } from "./season-phase";

const team: Team = {
  id: "2",
  espnId: 2,
  league: "nfl",
  name: "Bills",
  school: "Buffalo",
  abbreviation: "BUF",
  conferenceId: "4",
  conferenceName: "AFC East",
  logoUrl: "",
};
const side: GameTeam = { team, score: null };

let nextId = 1;
function game(seasonType?: number): Game {
  return {
    id: `g${nextId++}`,
    league: "nfl",
    status: "scheduled",
    scheduledAt: "2026-09-13T17:00:00Z",
    venue: { name: "", city: "", state: "" },
    homeTeam: side,
    awayTeam: side,
    seasonYear: 2026,
    conferenceGame: false,
    seasonType,
  };
}

describe("season phases", () => {
  it("names each card for the football in it", () => {
    expect(seasonPhaseTitle("preseason")).toBe("Preseason");
    expect(seasonPhaseTitle("regular")).toBe("Regular Season");
    expect(seasonPhaseTitle("postseason")).toBe("Postseason");
  });

  it("counts a game with no season type as regular season", () => {
    expect(seasonPhaseOf(game(undefined))).toBe("regular");
    expect(seasonPhaseOf(game(1))).toBe("preseason");
    expect(seasonPhaseOf(game(3))).toBe("postseason");
  });

  it("splits in season order", () => {
    const split = bySeasonPhase([game(3), game(2), game(1)]);
    expect(split.map((entry) => entry.phase)).toEqual([
      "preseason",
      "regular",
      "postseason",
    ]);
  });

  it("drops a phase the team has no games in", () => {
    const split = bySeasonPhase([game(2), game(2)]);
    expect(split).toHaveLength(1);
    expect(split[0].phase).toBe("regular");
    expect(split[0].games).toHaveLength(2);
  });

  it("makes no cards at all out of no games", () => {
    expect(bySeasonPhase([])).toEqual([]);
  });
});
