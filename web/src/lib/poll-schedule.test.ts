import { describe, expect, it } from "vitest";
import { nextPollDelay } from "./poll-schedule";
import type { Game, GameStatus, Team } from "./types";

// Polling through kickoff (iOS `ScoreboardStoreTests`, 2026-09-25). The
// cases mirror the Swift suite's.

const NOW = Date.UTC(2026, 8, 26, 17, 0, 0);
const INTERVAL = 30_000;

const team: Team = {
  id: "1",
  espnId: 1,
  league: "cfb",
  name: "A",
  school: "A",
  abbreviation: "A",
  conferenceId: "",
  conferenceName: "",
  logoUrl: "",
};

function kickoff(
  inSeconds: number,
  options: { status?: GameStatus; timeTBD?: boolean } = {}
): Game {
  return {
    id: String(inSeconds),
    league: "cfb",
    status: options.status ?? "scheduled",
    scheduledAt: new Date(NOW + inSeconds * 1000).toISOString(),
    venue: { name: "", city: "", state: "" },
    homeTeam: { team, score: null },
    awayTeam: { team, score: null },
    seasonYear: 2026,
    conferenceGame: false,
    timeTBD: options.timeTBD,
  };
}

const delay = (games: Game[]) => nextPollDelay(games, NOW, INTERVAL);

describe("nextPollDelay", () => {
  it("polls a live game at the interval", () => {
    expect(delay([kickoff(-600, { status: "in_progress" })])).toBe(INTERVAL);
    expect(delay([kickoff(-5400, { status: "halftime" })])).toBe(INTERVAL);
  });

  it("polls a kickoff inside one interval at the interval", () => {
    expect(delay([kickoff(10)])).toBe(INTERVAL);
  });

  it("sleeps until a later kickoff", () => {
    expect(delay([kickoff(20 * 60), kickoff(6 * 3600)])).toBe(20 * 60 * 1000);
  });

  it("keeps polling a game still pre-game an hour past kickoff", () => {
    expect(delay([kickoff(-3600)])).toBe(INTERVAL);
  });

  it("stops polling a game still pre-game four hours past kickoff", () => {
    expect(delay([kickoff(-4 * 3600)])).toBeNull();
  });

  it("schedules nothing for a placeholder kickoff", () => {
    expect(delay([kickoff(60, { timeTBD: true })])).toBeNull();
  });

  it("stops on an all-final slate", () => {
    expect(delay([kickoff(-3600, { status: "complete" })])).toBeNull();
  });

  it("never sleeps for less than one interval", () => {
    expect(delay([kickoff(45)])).toBe(45_000);
    expect(delay([kickoff(31)])).toBe(INTERVAL + 1000);
  });

  it("stops on an empty slate", () => {
    expect(delay([])).toBeNull();
  });
});
