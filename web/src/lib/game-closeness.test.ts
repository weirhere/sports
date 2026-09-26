import { describe, expect, it } from "vitest";
import { isTight, keepingFavorites } from "./game-closeness";
import type { League } from "./leagues";
import type { Game, GameStatus, Team } from "./types";

// The Tight filter's rule (Coard Miller, 2026-09-24): live, and either late
// and within one score, or with the underdog leading in the second half.
// The cases mirror iOS `GameClosenessTests` one for one.

function team(id: string, league: League): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name: `Team ${id}`,
    school: `Team ${id}`,
    abbreviation: `T${id}`,
    conferenceId: "",
    conferenceName: "",
    logoUrl: "",
  };
}

function game(
  league: League,
  period: number | undefined,
  home: number | null,
  away: number | null,
  options: { status?: GameStatus; favoriteIsHome?: boolean; id?: string } = {}
): Game {
  return {
    id: options.id ?? "g",
    league,
    status: options.status ?? "in_progress",
    scheduledAt: "2026-09-26T19:30:00Z",
    venue: { name: "", city: "", state: "" },
    homeTeam: { team: team("1", league), score: home },
    awayTeam: { team: team("2", league), score: away },
    quarter: period,
    seasonYear: 2026,
    conferenceGame: false,
    favoriteIsHome: options.favoriteIsHome,
  };
}

describe("late and within one score", () => {
  it("is one score in football's fourth, and overtime counts", () => {
    expect(isTight(game("nfl", 4, 21, 13))).toBe(true);
    expect(isTight(game("nfl", 4, 22, 13))).toBe(false);
    expect(isTight(game("cfb", 3, 14, 14))).toBe(false);
    expect(isTight(game("cfb", 5, 31, 31))).toBe(true);
  });

  it("is two possessions in basketball's fourth", () => {
    expect(isTight(game("nba", 4, 100, 94))).toBe(true);
    expect(isTight(game("nba", 4, 101, 94))).toBe(false);
  });

  it("is one goal in hockey's third", () => {
    expect(isTight(game("nhl", 3, 2, 1))).toBe(true);
    expect(isTight(game("nhl", 3, 3, 1))).toBe(false);
    expect(isTight(game("nhl", 2, 1, 1))).toBe(false);
    expect(isTight(game("nhl", 4, 2, 2))).toBe(true);
  });

  it("counts a quarter break as live", () => {
    expect(isTight(game("nfl", 4, 20, 17, { status: "end_period" }))).toBe(
      true
    );
  });
});

describe("the underdog leading", () => {
  it("counts in the second half", () => {
    // Home favored, away up 17 in the 3rd: not close, but an upset brewing.
    expect(isTight(game("cfb", 3, 7, 24, { favoriteIsHome: true }))).toBe(
      true
    );
    // The favorite ahead is just the expected game.
    expect(isTight(game("cfb", 3, 24, 7, { favoriteIsHome: true }))).toBe(
      false
    );
  });

  it("treats halftime as the second half's doorstep", () => {
    expect(
      isTight(
        game("nfl", 2, 3, 17, { status: "halftime", favoriteIsHome: true })
      )
    ).toBe(true);
    expect(isTight(game("nfl", 2, 3, 17, { favoriteIsHome: true }))).toBe(
      false
    );
  });

  it("uses hockey's second period as its second half", () => {
    expect(isTight(game("nhl", 2, 0, 3, { favoriteIsHome: true }))).toBe(
      true
    );
  });

  it("can't speak without a line — only the late rule does", () => {
    expect(isTight(game("cfb", 3, 7, 24))).toBe(false);
  });
});

describe("only live games", () => {
  it("never qualifies a pre-game game or a final", () => {
    expect(isTight(game("nfl", undefined, null, null, { status: "scheduled" })))
      .toBe(false);
    expect(isTight(game("nfl", 4, 20, 17, { status: "complete" }))).toBe(
      false
    );
  });
});

describe("keepingFavorites", () => {
  it("carries a favorite past the payload that drops it", () => {
    const kept = keepingFavorites(
      [game("nfl", 1, 0, 0, { id: "1" }), game("nfl", 1, 0, 0, { id: "2" })],
      [game("nfl", undefined, null, null, { id: "1", favoriteIsHome: false })]
    );
    expect(kept.map((g) => g.favoriteIsHome)).toEqual([false, undefined]);
  });

  it("lets a fresh favorite win", () => {
    const kept = keepingFavorites(
      [game("nfl", 1, 0, 0, { id: "1", favoriteIsHome: true })],
      [game("nfl", 1, 0, 0, { id: "1", favoriteIsHome: false })]
    );
    expect(kept[0]?.favoriteIsHome).toBe(true);
  });
});
