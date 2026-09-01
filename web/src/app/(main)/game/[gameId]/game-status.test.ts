import { describe, expect, it } from "vitest";
import type { Game, Team } from "@/lib/types";
import {
  isLiveStatus,
  quarterMarkerLabel,
  showsScores,
  statusLine,
  statusSubline,
} from "./game-status";

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

function game(overrides: Partial<Game> = {}): Game {
  return {
    id: "401",
    status: "scheduled",
    scheduledAt: "2026-09-05T16:00Z",
    venue: { name: "Stadium", city: "City", state: "ST" },
    homeTeam: { team: team("61"), score: null },
    awayTeam: { team: team("52"), score: null },
    week: 2,
    seasonYear: 2026,
    conferenceGame: false,
    ...overrides,
  };
}

describe("statusLine", () => {
  it("renders the live clock through the shared formatter", () => {
    expect(
      statusLine(
        game({ status: "in_progress", quarter: 3, clock: "5:24", livePhase: "playing" })
      )
    ).toBe("Q3 5:24");
  });

  it("says Half at halftime, never Q2 0:00", () => {
    expect(
      statusLine(
        game({ status: "halftime", quarter: 2, clock: "0:00", livePhase: "halftime" })
      )
    ).toBe("Half");
  });

  it("says End Q1 with the clock parked", () => {
    expect(
      statusLine(
        game({ status: "end_period", quarter: 1, clock: "0:00", livePhase: "endOfPeriod" })
      )
    ).toBe("End Q1");
  });

  it("renders ESPN's final detail, falling back to Final", () => {
    expect(statusLine(game({ status: "complete", statusDetail: "Final/OT" }))).toBe(
      "Final/OT"
    );
    expect(statusLine(game({ status: "complete" }))).toBe("Final");
  });

  it("renders TBD kicks day-only", () => {
    expect(statusLine(game({ timeTBD: true }))).toMatch(/ · TBD$/);
  });
});

describe("statusSubline", () => {
  it("carries the network pre-game and live, and the date on finals", () => {
    expect(statusSubline(game({ broadcast: "ESPN" }))).toBe("ESPN");
    expect(
      statusSubline(game({ status: "in_progress", broadcast: "FOX" }))
    ).toBe("FOX");
    expect(statusSubline(game({ status: "complete" }))).toMatch(/Sep/);
  });

  it("stays quiet when a final has no date", () => {
    expect(
      statusSubline(game({ status: "complete", scheduledAt: "" }))
    ).toBeUndefined();
  });
});

describe("showsScores / isLiveStatus", () => {
  it("hides scores pre-game only", () => {
    expect(showsScores(game())).toBe(false);
    expect(showsScores(game({ status: "in_progress" }))).toBe(true);
    expect(showsScores(game({ status: "complete" }))).toBe(true);
  });

  it("treats halftime and end-of-period as live", () => {
    expect(isLiveStatus("halftime")).toBe(true);
    expect(isLiveStatus("end_period")).toBe(true);
    expect(isLiveStatus("scheduled")).toBe(false);
    expect(isLiveStatus("complete")).toBe(false);
  });
});

describe("quarterMarkerLabel", () => {
  it("labels quarters and overtimes", () => {
    expect(quarterMarkerLabel(1)).toBe("1ST QUARTER");
    expect(quarterMarkerLabel(5)).toBe("OVERTIME");
    expect(quarterMarkerLabel(6)).toBe("2OT");
    expect(quarterMarkerLabel(undefined)).toBe("—");
  });
});
