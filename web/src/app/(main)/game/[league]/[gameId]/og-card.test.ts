import { describe, expect, it } from "vitest";
import type { Game, Team } from "@/lib/types";
import { easternDayText, easternTimeText, ogCardModel } from "./og-card";

function team(id: string, school: string): Team {
  return {
    id,
    espnId: Number(id),
    league: "cfb",
    name: "Team",
    school,
    abbreviation: "T",
    conferenceId: "8",
    conferenceName: "SEC",
    division: "FBS",
    logoUrl: `https://a.espncdn.com/i/teamlogos/ncaa/500/${id}.png`,
  };
}

function game(overrides: Partial<Game> = {}): Game {
  return {
    id: "401",
    league: "cfb",
    status: "scheduled",
    // 12:30 PM Eastern, deliberately an afternoon that is still the SAME
    // day in UTC — the timezone assertions below pick their own cases.
    scheduledAt: "2026-09-05T16:30Z",
    venue: { name: "Ohio Stadium", city: "Columbus", state: "OH" },
    homeTeam: { team: team("194", "Ohio State"), score: null, ranking: 1 },
    awayTeam: { team: team("2050", "Ball State"), score: null },
    week: 2,
    seasonYear: 2026,
    conferenceGame: false,
    ...overrides,
  };
}

describe("the kickoff a link preview shows", () => {
  it("splits the time from the date, the app's header shape", () => {
    const card = ogCardModel(game());
    expect(card.kickoff).toEqual({ time: "12:30 PM ET", date: "Sat, Sep 5" });
    expect(card.status).toBeNull();
  });

  it("names its timezone, because the reader's is unknown", () => {
    // The whole reason this differs from the app: one image, many readers,
    // rendered on a server whose own clock is UTC.
    expect(easternTimeText("2026-09-05T16:30Z")).toBe("12:30 PM ET");
    expect(easternTimeText("2026-01-02T00:30Z")).toBe("7:30 PM ET");
  });

  it("reads a kickoff's day on Eastern, not on the server's UTC", () => {
    // 8:00 PM ET on Sep 5 is already Sep 6 in UTC. A card that filed this
    // under Sunday would be wrong about the day of a Saturday night game.
    expect(easternDayText("2026-09-06T00:00Z")).toBe("Sat, Sep 5");
  });

  it("headlines TBD and keeps the real day", () => {
    const card = ogCardModel(game({ timeTBD: true }));
    expect(card.kickoff).toEqual({ time: "TBD", date: "Sat, Sep 5" });
    expect(card.description).toContain("time TBD");
  });

  it("shows no score before kickoff — no 0-0, no dashes", () => {
    const card = ogCardModel(
      game({
        homeTeam: { team: team("194", "Ohio State"), score: 0 },
        awayTeam: { team: team("2050", "Ball State"), score: 0 },
      })
    );
    expect(card.showsScores).toBe(false);
  });

  it("titles the matchup and describes when, where and on what", () => {
    const card = ogCardModel(game({ broadcast: "BTN" }));
    expect(card.title).toBe("Ball State at #1 Ohio State");
    expect(card.description).toBe(
      "Sat, Sep 5 12:30 PM ET · on BTN · Ohio Stadium, Columbus, OH"
    );
  });
});

describe("a game that has started", () => {
  const live = game({
    status: "in_progress",
    quarter: 3,
    clock: "5:24",
    livePhase: "playing",
    broadcast: "FOX",
    homeTeam: { team: team("194", "Ohio State"), score: 21, ranking: 1 },
    awayTeam: { team: team("2050", "Ball State"), score: 7 },
  });

  it("swaps the kickoff for the clock and leads with the score", () => {
    const card = ogCardModel(live);
    expect(card.kickoff).toBeNull();
    expect(card.status).toBe("Q3 5:24");
    expect(card.isLive).toBe(true);
    expect(card.title).toBe("Ball State 7, #1 Ohio State 21");
    expect(card.description).toBe("Q3 5:24 · on FOX");
  });

  it("keeps the network live and drops it at final", () => {
    expect(ogCardModel(live).broadcast).toBe("FOX");
    const final = ogCardModel({
      ...live,
      status: "complete",
      statusDetail: "Final",
    });
    // Nothing left to tune into — the app's own rule, since the widget.
    expect(final.broadcast).toBeUndefined();
    expect(final.title).toBe("Final: Ball State 7, #1 Ohio State 21");
  });

  it("never dims a side that hasn't lost", () => {
    // The loser's score goes muted on the card, so "not called yet" must
    // stay distinct from "lost" — a live game has no winner.
    const card = ogCardModel(live);
    expect(card.away.isWinner).toBeUndefined();
    expect(card.home.isWinner).toBeUndefined();

    const called = ogCardModel({
      ...live,
      status: "complete",
      homeTeam: { ...live.homeTeam, isWinner: true },
      awayTeam: { ...live.awayTeam, isWinner: false },
    });
    expect(called.home.isWinner).toBe(true);
    expect(called.away.isWinner).toBe(false);
  });

  it("makes a postponement the news", () => {
    const card = ogCardModel(game({ status: "postponed" }));
    expect(card.title).toBe("Ball State at #1 Ohio State · Postponed");
  });
});
