import { describe, it, expect } from "vitest";
import {
  deriveHomeVenue,
  venueCityLine,
  transformTeamSchedule,
} from "./transformers";
import type { EspnScheduleEvent, EspnScheduleResponse } from "./types";

const date = (
  venue: string | undefined,
  opts: {
    city?: string;
    isHome?: boolean;
    isNeutral?: boolean;
    attendance?: number;
  } = {}
) => ({
  venue,
  city: opts.city,
  isHome: opts.isHome ?? true,
  isNeutral: opts.isNeutral ?? false,
  attendance: opts.attendance,
});

describe("a team's home ground, derived from its own schedule", () => {
  it("takes the ground the team keeps hosting at", () => {
    const venue = deriveHomeVenue([
      date("Sanford Stadium", { city: "Athens, GA" }),
      date("Sanford Stadium"),
      date("Neyland Stadium", { isHome: false }),
    ]);
    expect(venue?.name).toBe("Sanford Stadium");
    expect(venue?.city).toBe("Athens, GA");
    expect(venue?.homeGames).toBe(2);
  });

  it("never calls a neutral site home", () => {
    // Georgia's season opens at the Mercedes-Benz Stadium as the nominal
    // host. A neutral site is nobody's home ground, so even a majority of
    // them can't take the name.
    const venue = deriveHomeVenue([
      date("Mercedes-Benz Stadium", { isNeutral: true }),
      date("Mercedes-Benz Stadium", { isNeutral: true }),
      date("Sanford Stadium"),
    ]);
    expect(venue?.name).toBe("Sanford Stadium");
    expect(venue?.homeGames).toBe(1);
  });

  it("doesn't let a one-off relocation rename home", () => {
    const venue = deriveHomeVenue([
      date("Somewhere Else"),
      date("Sanford Stadium"),
      date("Sanford Stadium"),
    ]);
    expect(venue?.name).toBe("Sanford Stadium");
  });

  it("breaks ties toward the earlier date", () => {
    expect(deriveHomeVenue([date("Zed Field"), date("Alpha Field")])?.name).toBe(
      "Zed Field"
    );
  });

  it("averages only the published gates", () => {
    const venue = deriveHomeVenue([
      date("Ground", { attendance: 100 }),
      date("Ground", { attendance: 201 }),
      date("Ground"),
      // A zero gate is ESPN not knowing, not an empty stadium.
      date("Ground", { attendance: 0 }),
      // An away gate is somebody else's crowd.
      date("Elsewhere", { isHome: false, attendance: 90_000 }),
    ]);
    expect(venue?.homeGames).toBe(4);
    expect(venue?.countedGames).toBe(2);
    expect(venue?.averageAttendance).toBe(151); // 301 / 2, rounded
  });

  it("has nothing to say about a season with no home date", () => {
    expect(deriveHomeVenue([])).toBeUndefined();
    expect(deriveHomeVenue([date("Elsewhere", { isHome: false })])).toBeUndefined();
    // A home date ESPN didn't place can't name a ground.
    expect(deriveHomeVenue([date(undefined)])).toBeUndefined();
  });

  it("names the ground of a season nobody has played yet", () => {
    const venue = deriveHomeVenue([date("Lumen Field", { city: "Seattle, WA" })]);
    expect(venue?.name).toBe("Lumen Field");
    expect(venue?.countedGames).toBe(0);
    expect(venue?.averageAttendance).toBeUndefined();
  });

  it("joins whatever of the address shipped", () => {
    expect(venueCityLine("Athens", "GA")).toBe("Athens, GA");
    expect(venueCityLine("Toronto", undefined)).toBe("Toronto");
    expect(venueCityLine(undefined, undefined)).toBeUndefined();
    expect(venueCityLine("  ", undefined)).toBeUndefined();
  });
});

const event = (
  id: string,
  attendance: number
): EspnScheduleEvent => ({
  id,
  date: "2026-09-13T20:00Z",
  competitions: [
    {
      date: "2026-09-13T20:00Z",
      neutralSite: false,
      attendance,
      venue: {
        fullName: "Lumen Field",
        address: { city: "Seattle", state: "WA" },
      },
      competitors: [
        { homeAway: "home", team: { id: "26", location: "Seattle" } },
        { homeAway: "away", team: { id: "21", location: "Los Angeles" } },
      ],
    },
  ],
});

describe("the preseason is not a home date", () => {
  it("counts the regular season and the playoffs, never the exhibitions", () => {
    // Exhibitions would inflate "home games" past what anyone means by it
    // and drag the average down with a crowd nobody turned up for. A home
    // *playoff* date is a real game at the real ground.
    const response: EspnScheduleResponse = {
      season: { year: 2026 },
      requestedSeason: { year: 2026 },
      team: { id: "26", location: "Seattle", displayName: "Seattle Seahawks" },
      events: [event("2", 68_000)],
    };
    const schedule = transformTeamSchedule(response, "nfl", {
      preseason: [event("1", 40_000)],
      postseason: [event("3", 69_000)],
    });
    expect(schedule.homeVenue?.name).toBe("Lumen Field");
    expect(schedule.homeVenue?.city).toBe("Seattle, WA");
    expect(schedule.homeVenue?.homeGames).toBe(2);
    expect(schedule.homeVenue?.averageAttendance).toBe(68_500);
  });
});
