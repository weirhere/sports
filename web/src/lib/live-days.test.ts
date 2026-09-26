import { describe, expect, it } from "vitest";
import type { Game, GameStatus } from "./types";
import { easternDayToken, liveDayTokens, patchGames } from "./live-days";

/**
 * The live poll's narrow ask (2026-09-26): only the Eastern days with games
 * in play, patched into the slate by id — iOS `ScoreboardStore.liveDays`.
 */

function game(
  id: string,
  status: GameStatus,
  scheduledAt: string,
  extra: Partial<Game> = {}
): Game {
  const team = {
    id,
    espnId: 1,
    league: "cfb" as const,
    name: id,
    school: id,
    abbreviation: id,
    conferenceId: "5",
    conferenceName: "",
    logoUrl: "",
  };
  return {
    id,
    league: "cfb",
    status,
    scheduledAt,
    venue: { name: "", city: "", state: "" },
    homeTeam: { team, score: null },
    awayTeam: { team, score: null },
    seasonYear: 2026,
    conferenceGame: false,
    ...extra,
  };
}

// 03:28 UTC Saturday is 11:28 PM Friday in Eastern daylight time.
const now = Date.parse("2026-09-26T03:28:00Z");

describe("easternDayToken", () => {
  it("names the Eastern day, not the UTC one", () => {
    expect(easternDayToken(new Date("2026-09-26T03:28:00Z"))).toBe("20260925");
    expect(easternDayToken(new Date("2026-09-26T04:30:00Z"))).toBe("20260926");
  });
});

describe("liveDayTokens", () => {
  it("names the day of a game in play", () => {
    const live = game("nu-iu", "in_progress", "2026-09-26T00:00:00Z");
    expect(liveDayTokens([live], now)).toEqual(["20260925"]);
  });

  it("counts halftime and period breaks as in play", () => {
    const games = [
      game("a", "halftime", "2026-09-26T00:00:00Z"),
      game("b", "end_period", "2026-09-26T00:30:00Z"),
    ];
    expect(liveDayTokens(games, now)).toEqual(["20260925"]);
  });

  it("counts a game past kickoff that ESPN hasn't flipped yet", () => {
    const late = game("late", "scheduled", "2026-09-26T03:27:00Z");
    expect(liveDayTokens([late], now)).toEqual(["20260925"]);
  });

  it("gives up on a game stuck at scheduled past the kickoff grace", () => {
    const stuck = game("stuck", "scheduled", "2026-09-23T23:00:00Z");
    expect(liveDayTokens([stuck], now)).toEqual([]);
  });

  it("ignores games not yet started, finished, or called off", () => {
    const games = [
      game("later", "scheduled", "2026-09-26T16:00:00Z"),
      game("done", "complete", "2026-09-25T23:00:00Z"),
      game("off", "postponed", "2026-09-25T23:00:00Z"),
    ];
    expect(liveDayTokens(games, now)).toEqual([]);
  });

  it("asks once per Eastern day, in order", () => {
    const games = [
      game("late-west", "in_progress", "2026-09-26T05:00:00Z"),
      game("a", "in_progress", "2026-09-26T00:00:00Z"),
      game("b", "in_progress", "2026-09-26T01:00:00Z"),
    ];
    expect(liveDayTokens(games, Date.parse("2026-09-26T06:00:00Z"))).toEqual([
      "20260925",
      "20260926",
    ]);
  });
});

describe("patchGames", () => {
  it("replaces games by id and leaves the rest alone", () => {
    const held = [
      game("live", "in_progress", "2026-09-26T00:00:00Z"),
      game("other", "scheduled", "2026-09-26T16:00:00Z"),
    ];
    const fresh = game("live", "complete", "2026-09-26T00:00:00Z");
    const patched = patchGames(held, new Map([["live", fresh]]));
    expect(patched[0]!.status).toBe("complete");
    expect(patched[1]).toBe(held[1]);
  });

  it("adds nothing the slate didn't hold", () => {
    const held = [game("live", "in_progress", "2026-09-26T00:00:00Z")];
    const stranger = game("new", "in_progress", "2026-09-26T00:00:00Z");
    expect(patchGames(held, new Map([["new", stranger]]))).toEqual(held);
  });

  it("keeps a favorite the fresh copy dropped", () => {
    const held = [
      game("live", "in_progress", "2026-09-26T00:00:00Z", {
        favoriteIsHome: true,
      }),
    ];
    const fresh = game("live", "in_progress", "2026-09-26T00:00:00Z");
    const [patched] = patchGames(held, new Map([["live", fresh]]));
    expect(patched!.favoriteIsHome).toBe(true);
  });
});
