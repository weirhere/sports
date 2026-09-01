import { describe, expect, it } from "vitest";
import type { Game, GameDetail, GameStatus, Team } from "@/lib/types";
import { mergeLiveSnapshot } from "./use-live-game";

function team(id: string): Team {
  return {
    id,
    espnId: Number(id),
    name: "Team",
    school: `School ${id}`,
    abbreviation: "T",
    conferenceId: "8",
    conferenceName: "SEC",
    division: "FBS",
    logoUrl: `https://a.espncdn.com/i/teamlogos/ncaa/500/${id}.png`,
  };
}

function detail(
  status: GameStatus,
  overrides: Partial<Game> = {}
): GameDetail {
  const game: Game = {
    id: "401",
    status,
    scheduledAt: "2026-09-05T16:00Z",
    venue: { name: "Stadium", city: "City", state: "ST" },
    homeTeam: { team: team("61"), score: 14, linescores: [7, 7] },
    awayTeam: { team: team("52"), score: 10, linescores: [3, 7] },
    clock: "5:24",
    quarter: 3,
    week: 2,
    seasonYear: 2026,
    conferenceGame: false,
    livePhase: "playing",
    statusDetail: "Q3 5:24",
    ...overrides,
  };
  return {
    game,
    homeStats: emptyStats(),
    awayStats: emptyStats(),
  };
}

function emptyStats() {
  return {
    totalYards: 0,
    passingYards: 0,
    rushingYards: 0,
    turnovers: 0,
    penalties: 0,
    penaltyYards: 0,
    firstDowns: 0,
    thirdDownEfficiency: "0-0",
    fourthDownEfficiency: "0-0",
    timeOfPossession: "0:00",
    redZoneEfficiency: "0-0",
    sacks: 0,
    interceptions: 0,
    fumbles: 0,
  };
}

describe("mergeLiveSnapshot", () => {
  it("keeps the live status and scores when a stale pre-game summary arrives", () => {
    const live = detail("in_progress");
    const stalePre = detail("scheduled", {
      clock: undefined,
      quarter: undefined,
      livePhase: undefined,
      statusDetail: "9/5 - 12:00 PM EDT",
    });
    stalePre.game.homeTeam = { ...stalePre.game.homeTeam, score: null, linescores: [] };
    stalePre.game.awayTeam = { ...stalePre.game.awayTeam, score: null, linescores: [] };

    const merged = mergeLiveSnapshot(live, stalePre);
    expect(merged.game.status).toBe("in_progress");
    expect(merged.game.clock).toBe("5:24");
    expect(merged.game.quarter).toBe(3);
    expect(merged.game.homeTeam.score).toBe(14);
    expect(merged.game.awayTeam.score).toBe(10);
    expect(merged.game.awayTeam.linescores).toEqual([3, 7]);
  });

  it("lets a final summary win over a live snapshot", () => {
    const live = detail("in_progress");
    const final = detail("complete", {
      clock: "0:00",
      quarter: 4,
      statusDetail: "Final",
    });
    const merged = mergeLiveSnapshot(live, final);
    expect(merged.game.status).toBe("complete");
    expect(merged.game.statusDetail).toBe("Final");
  });

  it("takes a live incoming summary as-is", () => {
    const live = detail("in_progress");
    const fresher = detail("in_progress", { clock: "2:01", quarter: 4 });
    fresher.game.homeTeam = { ...fresher.game.homeTeam, score: 21 };
    const merged = mergeLiveSnapshot(live, fresher);
    expect(merged.game.clock).toBe("2:01");
    expect(merged.game.homeTeam.score).toBe(21);
  });

  it("keeps a genuinely pre-game state pre-game", () => {
    const pre = detail("scheduled");
    const stillPre = detail("scheduled");
    expect(mergeLiveSnapshot(pre, stillPre).game.status).toBe("scheduled");
  });
});
