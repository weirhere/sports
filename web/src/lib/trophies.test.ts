import { describe, expect, it } from "vitest";
import georgiaScheduleJson from "./espn/__fixtures__/georgia-schedule-2025.json";
import type { EspnScheduleResponse } from "./espn/types";
import { transformTeamSchedule } from "./espn/transformers";
import type { Game, GameStatus, Team } from "./types";
import type { League } from "./leagues";
import {
  assembleTrophyCase,
  coverageFloor,
  deriveTrophies,
  trophyGroupTitle,
  trophyKindFromHeadline,
  type TrophyKind,
} from "./trophies";
import { trophyFootnote } from "@/components/team-trophies-card";

function team(id: string, school: string, league: League = "cfb"): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name: school,
    school,
    abbreviation: school.slice(0, 3).toUpperCase(),
    conferenceId: "8",
    conferenceName: "",
    logoUrl: "",
  };
}

const MINE = team("61", "Georgia");

let nextId = 1;
function titledGame(fields: {
  headline?: string;
  won?: boolean;
  day?: number;
  status?: GameStatus;
  league?: League;
  /** Neither side is us — the "someone else's title" case. */
  without?: boolean;
}): Game {
  const league = fields.league ?? "cfb";
  const home = fields.without ? team("2", "Auburn", league) : MINE;
  return {
    id: `g${nextId++}`,
    league,
    status: fields.status ?? "complete",
    scheduledAt: new Date(Date.UTC(2026, 0, fields.day ?? 1, 20)).toISOString(),
    venue: { name: "", city: "", state: "" },
    homeTeam: { team: home, score: null, isWinner: fields.won ?? false },
    awayTeam: {
      team: team("333", "Alabama", league),
      score: null,
      isWinner: fields.won === undefined ? false : !fields.won,
    },
    seasonYear: 2025,
    conferenceGame: false,
    headline: fields.headline,
  };
}

function kind(headline: string, league: League = "cfb"): TrophyKind | undefined {
  return trophyKindFromHeadline(headline, league);
}

describe("reading a trophy off a headline", () => {
  it("recognizes each league's title in its own words", () => {
    expect(
      kind("College Football Playoff National Championship")?.singular
    ).toBe("National Championship");
    expect(kind("Super Bowl LIX", "nfl")?.singular).toBe("Super Bowl");
    expect(kind("NBA Finals", "nba")?.singular).toBe("NBA Finals");
    expect(kind("Stanley Cup Final", "nhl")?.singular).toBe("Stanley Cup");
  });

  it("keeps a conference title's own name, and pluralizes it", () => {
    const sec = kind("SEC Championship");
    expect(sec?.singular).toBe("SEC Championship");
    expect(sec?.plural).toBe("SEC Championships");
    expect(sec?.tier).toBe("conference");
    // A conference we have never heard of still reads correctly.
    expect(kind("Mountain West Championship")?.singular).toBe(
      "Mountain West Championship"
    );
  });

  it("names a title game after the trophy, not the fixture", () => {
    // A team holds three AFC Championships, not three AFC Championship Games.
    expect(kind("AFC Championship Game", "nfl")?.singular).toBe(
      "AFC Championship"
    );
  });

  it("stays silent on a headline that isn't a trophy", () => {
    // Branded kickoffs and neutral-site regular games live in this same field.
    expect(kind("Aflac Kickoff Game")).toBeUndefined();
    expect(kind("Aer Lingus College Football Classic")).toBeUndefined();
    expect(kind("NFL Melbourne Game", "nfl")).toBeUndefined();
    expect(kind("NBA Cup - Group Play", "nba")).toBeUndefined();
    expect(kind("Championship Week")).toBeUndefined();
    expect(kind("Championship")).toBeUndefined();
    expect(trophyKindFromHeadline(undefined, "cfb")).toBeUndefined();
    expect(trophyKindFromHeadline("", "cfb")).toBeUndefined();
  });

  it("gives a qualified round nothing — it decides nothing", () => {
    // Both end in "final", which is the whole problem: the NHL called its
    // early rounds "Stanley Cup Quarterfinals" for decades.
    expect(kind("NBA Cup - Quarterfinals", "nba")).toBeUndefined();
    expect(kind("Stanley Cup Quarterfinals", "nhl")).toBeUndefined();
    expect(kind("Stanley Cup Semifinals", "nhl")).toBeUndefined();
  });

  it("takes the deciding round either way a league spells it", () => {
    expect(kind("Stanley Cup Finals", "nhl")?.singular).toBe("Stanley Cup");
    expect(kind("NBA Cup - Championship", "nba")?.singular).toBe("NBA Cup");
  });

  it("checks the league title before the conference round", () => {
    // "National Championship" contains "championship", and "NBA Finals" and
    // "Eastern Conference Finals" both spell "Finals".
    expect(kind("CFP National Championship")?.tier).toBe("league");
    expect(kind("Eastern Conference Finals", "nba")?.tier).toBe("conference");
    expect(kind("Western Conference Final", "nhl")?.singular).toBe(
      "Western Conference Final"
    );
  });
});

describe("the payload gap this closed", () => {
  it("carries ESPN's printed game name on a team schedule", () => {
    // The schedule path decoded no `notes` at all before this — the field is
    // in every payload and was read on the scoreboard path only, which left a
    // team's own title games unnameable on its own page.
    const schedule = transformTeamSchedule(
      georgiaScheduleJson as EspnScheduleResponse,
      "cfb"
    );
    const titled = schedule.games.filter((game) => game.headline !== undefined);
    expect(titled).toHaveLength(1);
    expect(titled[0].headline).toBe("SEC Championship");
  });

  it("derives the SEC Championship Georgia actually won", () => {
    const schedule = transformTeamSchedule(
      georgiaScheduleJson as EspnScheduleResponse,
      "cfb"
    );
    const trophies = deriveTrophies(schedule.games, {
      teamId: "61",
      // Read off the payload, never off the calendar.
      year: schedule.year ?? 0,
      league: "cfb",
    });
    expect(trophies).toHaveLength(1);
    expect(trophies[0].kind.singular).toBe("SEC Championship");
    expect(trophies[0].year).toBe(2025);
  });
});

describe("deriving a season's titles", () => {
  const context = { teamId: MINE.id, year: 2025, league: "cfb" as const };

  it("wins nothing from a title game still to be played", () => {
    expect(
      deriveTrophies(
        [titledGame({ headline: "SEC Championship", status: "scheduled" })],
        context
      )
    ).toHaveLength(0);
  });

  it("wins nothing by losing the final", () => {
    expect(
      deriveTrophies(
        [titledGame({ headline: "SEC Championship", won: false })],
        context
      )
    ).toHaveLength(0);
  });

  it("decides a series on its last completed game, not on any win in it", () => {
    // Led 3-0 and lost it: taking every won game would hand over the trophy.
    const games = [
      titledGame({ headline: "NBA Finals", won: true, day: 1, league: "nba" }),
      titledGame({ headline: "NBA Finals", won: true, day: 3, league: "nba" }),
      titledGame({ headline: "NBA Finals", won: true, day: 5, league: "nba" }),
      titledGame({ headline: "NBA Finals", won: false, day: 7, league: "nba" }),
      titledGame({ headline: "NBA Finals", won: false, day: 9, league: "nba" }),
      titledGame({ headline: "NBA Finals", won: false, day: 11, league: "nba" }),
      titledGame({ headline: "NBA Finals", won: false, day: 13, league: "nba" }),
    ];
    expect(
      deriveTrophies(games, { ...context, league: "nba" })
    ).toHaveLength(0);
    // And the other way round, on the same seven games.
    const winners = games.map((game) => ({
      ...game,
      homeTeam: { ...game.homeTeam, isWinner: !game.homeTeam.isWinner },
    }));
    expect(deriveTrophies(winners, { ...context, league: "nba" })).toHaveLength(
      1
    );
  });

  it("never counts a title game the team wasn't in", () => {
    expect(
      deriveTrophies(
        [titledGame({ headline: "SEC Championship", won: true, without: true })],
        context
      )
    ).toHaveLength(0);
  });
});

describe("assembling the shelf", () => {
  const national: TrophyKind = {
    singular: "National Championship",
    plural: "National Championships",
    tier: "league",
  };
  const sec: TrophyKind = {
    singular: "SEC Championship",
    plural: "SEC Championships",
    tier: "conference",
  };
  const big: TrophyKind = {
    singular: "Big Ten Championship",
    plural: "Big Ten Championships",
    tier: "conference",
  };

  it("leads with league titles, then the most-won trophy in each tier", () => {
    const shelf = assembleTrophyCase({
      derived: [
        { kind: sec, year: 2025 },
        { kind: sec, year: 2022 },
        { kind: big, year: 2024 },
        { kind: national, year: 2021 },
      ],
      registry: [],
      allTimeKinds: new Set(),
      derivedFloor: 2014,
    });
    expect(shelf.groups.map((group) => group.id)).toEqual([
      "National Championship",
      "SEC Championship",
      "Big Ten Championship",
    ]);
    // Newest first inside a row — the most recent one is the headline.
    expect(shelf.groups[1].years).toEqual([2025, 2022]);
    expect(trophyGroupTitle(shelf.groups[0])).toBe("National Championship");
    expect(trophyGroupTitle(shelf.groups[1])).toBe("SEC Championships");
  });

  it("merges a title both sources know about into one row", () => {
    const shelf = assembleTrophyCase({
      derived: [{ kind: national, year: 2021 }],
      registry: [
        { kind: national, year: 2021 },
        { kind: national, year: 1980 },
      ],
      allTimeKinds: new Set(["National Championship"]),
      derivedFloor: 2014,
    });
    expect(shelf.groups).toHaveLength(1);
    expect(shelf.groups[0].years).toEqual([2021, 1980]);
    expect(shelf.groups[0].coverage).toEqual({ kind: "allTime" });
  });

  it("says what each row can speak for, and says it once", () => {
    // A shelf that quietly starts in 2014 is the omission this caption is
    // built against — an eighteen-time champion showing six of them.
    const derivedOnly = assembleTrophyCase({
      derived: [
        { kind: national, year: 2021 },
        { kind: sec, year: 2025 },
      ],
      registry: [],
      allTimeKinds: new Set(),
      derivedFloor: 2014,
    });
    expect(coverageFloor(derivedOnly)).toBe(2014);
    expect(trophyFootnote(derivedOnly)).toBe("Since 2014");

    const mixed = assembleTrophyCase({
      derived: [{ kind: sec, year: 2025 }],
      registry: [{ kind: national, year: 1980 }],
      allTimeKinds: new Set(["National Championship"]),
      derivedFloor: 2014,
    });
    expect(trophyFootnote(mixed)).toBe("SEC Championship since 2014");

    const allTime = assembleTrophyCase({
      derived: [],
      registry: [{ kind: national, year: 1980 }],
      allTimeKinds: new Set(["National Championship"]),
      derivedFloor: 2014,
    });
    // Silence is only the truth when every row is all-time.
    expect(coverageFloor(allTime)).toBeUndefined();
    expect(trophyFootnote(allTime)).toBeUndefined();
  });
});
