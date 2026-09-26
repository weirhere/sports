import { describe, it, expect } from "vitest";
import { orderedAroundNow, unionGames } from "./search-games";
import type { Game, GameStatus, Team } from "./types";
import type { League } from "./leagues";

function team(id: string, league: League = "nhl"): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name: `Team ${id}`,
    school: `School ${id}`,
    abbreviation: `T${id}`,
    conferenceId: "",
    conferenceName: "",
    logoUrl: "",
  };
}

function game(
  id: string,
  scheduledAt: string,
  options: { status?: GameStatus; league?: League; homeScore?: number } = {}
): Game {
  const league = options.league ?? "nhl";
  return {
    id,
    league,
    status: options.status ?? "scheduled",
    scheduledAt,
    venue: { name: "", city: "", state: "" },
    homeTeam: { team: team("1", league), score: options.homeScore ?? null },
    awayTeam: { team: team("2", league), score: null },
    seasonYear: 2026,
    conferenceGame: false,
  };
}

const now = new Date("2026-09-25T18:00:00Z");

describe("unionGames", () => {
  it("prefers the slate's copy over a schedule's frozen one", () => {
    const frozen = game("10", "2026-09-25T17:00:00Z", { status: "halftime", homeScore: 1 });
    const live = game("10", "2026-09-25T17:00:00Z", { status: "in_progress", homeScore: 3 });
    const union = unionGames([frozen], [live]);
    expect(union).toHaveLength(1);
    expect(union[0]).toBe(live);
  });

  it("adds schedule games the slate doesn't have", () => {
    const loaded = [game("1", "2026-09-25T17:00:00Z")];
    const schedule = [game("1", "2026-09-25T17:00:00Z"), game("2", "2026-10-02T17:00:00Z")];
    expect(unionGames(schedule, loaded).map((g) => g.id)).toEqual(["1", "2"]);
  });

  it("dedupes a game that arrives in two teams' schedules", () => {
    // "new york": the Islanders and the Rangers both carry their meeting.
    const derby = game("7", "2026-10-10T23:00:00Z");
    expect(unionGames([derby, { ...derby }], [])).toHaveLength(1);
  });

  it("keeps two leagues' games that share an event id", () => {
    const hockey = game("5", "2026-10-10T23:00:00Z", { league: "nhl" });
    const football = game("5", "2026-10-11T17:00:00Z", { league: "nfl" });
    expect(unionGames([hockey, football], [])).toHaveLength(2);
  });
});

describe("orderedAroundNow", () => {
  it("leads with the most recent final, then the next kickoff forward", () => {
    const games = [
      game("oct", "2026-10-03T17:00:00Z"),
      game("aug", "2026-08-30T17:00:00Z", { status: "complete" }),
      game("sep20", "2026-09-20T17:00:00Z", { status: "complete" }),
      game("sep27", "2026-09-27T17:00:00Z"),
      game("sep13", "2026-09-13T17:00:00Z", { status: "complete" }),
    ];
    expect(orderedAroundNow(games, now).map((g) => g.id)).toEqual([
      "sep20",
      "sep27",
      "oct",
      "sep13",
      "aug",
    ]);
  });

  it("puts the next game first when nothing has been played", () => {
    const games = [game("b", "2026-10-03T17:00:00Z"), game("a", "2026-09-27T17:00:00Z")];
    expect(orderedAroundNow(games, now).map((g) => g.id)).toEqual(["a", "b"]);
  });

  it("counts a kickoff at exactly now as upcoming", () => {
    const games = [game("now", now.toISOString()), game("past", "2026-09-20T17:00:00Z")];
    expect(orderedAroundNow(games, now).map((g) => g.id)).toEqual(["past", "now"]);
  });

  it("drops a game with no parseable kickoff", () => {
    const games = [game("tbd", "not a date"), game("a", "2026-09-27T17:00:00Z")];
    expect(orderedAroundNow(games, now).map((g) => g.id)).toEqual(["a"]);
  });
});
