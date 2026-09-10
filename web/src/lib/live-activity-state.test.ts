import { describe, expect, it } from "vitest";
import { activityPhase, contentState, periodLabel } from "@/lib/live-activity-state";
import type { Game, GameStatus } from "@/lib/types";
import type { League } from "@/lib/leagues";

function game(fields: Partial<Game> & { status: GameStatus }): Game {
  const team = (id: string, score: number | null) => ({
    team: {
      id,
      location: id,
      displayName: id,
      abbreviation: id.toUpperCase(),
      league: (fields.league ?? "cfb") as League,
    },
    score,
  });
  return {
    id: "g1",
    league: "cfb",
    scheduledAt: "2026-09-26T23:30:00Z",
    venue: { name: "V", city: "C", state: "S" },
    homeTeam: team("uga", 24),
    awayTeam: team("ala", 7),
    broadcast: "SECN",
    seasonYear: 2026,
    conferenceGame: true,
    ...fields,
  } as unknown as Game;
}

/**
 * The server half of a wire contract whose client half is Swift. These
 * assert the shape ActivityKit will decode into
 * `GameActivityAttributes.ContentState` — a mismatch fails silently on a
 * lock screen, so it has to fail loudly here instead.
 */
describe("activity phase", () => {
  it("maps every status the client has a case for", () => {
    expect(activityPhase("scheduled")).toBe("pre");
    expect(activityPhase("in_progress")).toBe("live");
    expect(activityPhase("halftime")).toBe("intermission");
    expect(activityPhase("end_period")).toBe("intermission");
    expect(activityPhase("complete")).toBe("final");
  });

  /** Folded in with complete, exactly as the client folds `.other`. */
  it("folds postponed and cancelled into final", () => {
    expect(activityPhase("postponed")).toBe("final");
    expect(activityPhase("cancelled")).toBe("final");
  });
});

describe("content state", () => {
  it("shows no scores at all before kickoff", () => {
    const state = contentState(game({ status: "scheduled" }));
    expect(state.phase).toBe("pre");
    expect(state.awayScore).toBeUndefined();
    expect(state.homeScore).toBeUndefined();
    expect(state.detail).toBe("SECN");
  });

  it("carries both scores once the game is live", () => {
    const state = contentState(game({ status: "in_progress", quarter: 3, clock: "5:24" }));
    expect(state).toMatchObject({ phase: "live", awayScore: 7, homeScore: 24, headline: "Q3 5:24" });
  });

  /** The single most important assertion in this file: a parked clock must
   *  never reach a card as "Q2 0:00". */
  it("says Half at the interval, never a parked clock", () => {
    const state = contentState(game({ status: "halftime", quarter: 2, clock: "0:00" }));
    expect(state.headline).toBe("Half");
    expect(state.headline).not.toContain("0:00");
  });

  it("names the period at any other break", () => {
    expect(contentState(game({ status: "end_period", quarter: 1 })).headline).toBe("End Q1");
  });

  it("drops the detail line once there is nothing left to tune into", () => {
    expect(contentState(game({ status: "complete" })).detail).toBeUndefined();
    expect(contentState(game({ status: "halftime", quarter: 2 })).detail).toBeUndefined();
  });

  /** Epoch seconds, not milliseconds and not the 2001 reference date. */
  it("stamps asOf in epoch seconds", () => {
    const now = new Date("2026-09-26T23:30:00Z");
    const state = contentState(game({ status: "in_progress" }), { now });
    expect(state.asOf).toBe(now.getTime() / 1000);
    // Seconds, not milliseconds: a 13-digit value would decode as a date
    // tens of thousands of years out, and the card would never look stale.
    expect(String(state.asOf)).toHaveLength(10);
  });

  it("says TBD for an unannounced kickoff rather than a midnight time", () => {
    expect(contentState(game({ status: "scheduled", timeTBD: true })).headline).toBe("TBD");
  });

  it("commits to a zone for the kickoff string", () => {
    const eastern = contentState(game({ status: "scheduled" }), { timeZone: "America/New_York" });
    const pacific = contentState(game({ status: "scheduled" }), { timeZone: "America/Los_Angeles" });
    // Matches the client's own .weekday(.abbreviated).hour().minute().
    expect(eastern.headline).toBe("Sat 7:30 PM");
    expect(pacific.headline).not.toBe(eastern.headline);
  });
});

describe("period labels", () => {
  it("counts quarters in football and periods in hockey", () => {
    expect(periodLabel(3, "cfb")).toBe("Q3");
    expect(periodLabel(2, "nhl")).toBe("P2");
  });

  it("names overtime rather than counting past regulation", () => {
    expect(periodLabel(5, "cfb")).toBe("OT");
    expect(periodLabel(6, "cfb")).toBe("2OT");
    expect(periodLabel(4, "nhl")).toBe("OT");
  });
});
