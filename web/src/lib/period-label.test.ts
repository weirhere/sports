import { describe, expect, it } from "vitest";
import { allowsShootout, periodShort, periodText } from "./period-label";
import type { Game } from "./types";

function game(league: Game["league"], seasonType?: number): Game {
  return {
    id: "g",
    league,
    status: "complete",
    scheduledAt: "2026-09-05T19:30:00Z",
    venue: { name: "", city: "", state: "" },
    homeTeam: { team: {} as never, score: null },
    awayTeam: { team: {} as never, score: null },
    seasonYear: 2026,
    conferenceGame: false,
    seasonType,
  };
}

describe("what a period is called", () => {
  it("is quarters in football and basketball", () => {
    expect(periodText(1, "cfb")).toBe("1ST QUARTER");
    expect(periodText(4, "nba")).toBe("4TH QUARTER");
  });

  it("is periods in hockey, which plays three of them", () => {
    expect(periodText(3, "nhl")).toBe("3RD PERIOD");
  });

  it("says OVERTIME past regulation, then counts", () => {
    expect(periodText(5, "nfl")).toBe("OVERTIME");
    expect(periodText(6, "nfl")).toBe("2OT");
    // Hockey's regulation is one period shorter, so its overtime is 4.
    expect(periodText(4, "nhl")).toBe("OVERTIME");
  });

  it("calls a hockey period 5 a shootout only where one is possible", () => {
    // The NHL settles a *regular-season* tie in a shootout after the
    // overtime; a playoff period 5 is a second overtime.
    expect(periodText(5, "nhl", true)).toBe("SHOOTOUT");
    expect(periodText(5, "nhl", false)).toBe("2OT");
    expect(periodShort(5, "nhl", true)).toBe("SO");
    expect(periodShort(5, "nhl", false)).toBe("2OT");
  });

  it("offers the shootout to a hockey regular-season game alone", () => {
    expect(allowsShootout(game("nhl"))).toBe(true);
    expect(allowsShootout(game("nhl", 3))).toBe(false);
    expect(allowsShootout(game("nfl"))).toBe(false);
  });

  it("says nothing at all about a period it wasn't given", () => {
    expect(periodText(undefined, "nhl")).toBe("—");
  });
});
