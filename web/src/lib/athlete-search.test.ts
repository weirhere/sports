import { describe, it, expect } from "vitest";
import { linkableAthletes, teamDisplayName } from "./athlete-search";
import {
  athleteIdFromUid,
  transformAthleteSearch,
} from "./espn/athlete-search";
import type { ConferenceTeams, SearchAthlete, Team } from "./types";
import type { League } from "./leagues";

function team(id: string, league: League, school: string, name: string): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name,
    school,
    abbreviation: "",
    conferenceId: "",
    conferenceName: "",
    logoUrl: "",
  };
}

function conference(league: League, teams: Team[]): ConferenceTeams {
  return { league, name: "", teams, rowId: `${league}-x` };
}

// The directory loads FBS and FCS: Tarleton State and Harvard are in it,
// Mars Hill (Division II) is not.
const directory = [
  conference("cfb", [
    team("2627", "cfb", "Tarleton State", "Texans"),
    team("108", "cfb", "Harvard", "Crimson"),
    team("2", "cfb", "Auburn", "Tigers"),
  ]),
  conference("nhl", [team("6", "nhl", "Edmonton", "Oilers")]),
  conference("nfl", [team("2", "nfl", "Buffalo", "Bills")]),
];

function athlete(overrides: Partial<SearchAthlete> & { athleteId: string }): SearchAthlete {
  return { league: "cfb", name: "Somebody", ...overrides };
}

describe("teamDisplayName", () => {
  it("joins school and nickname the way ESPN's subtitle spells it", () => {
    expect(teamDisplayName(team("6", "nhl", "Edmonton", "Oilers"))).toBe("Edmonton Oilers");
    expect(teamDisplayName({ school: "Army", name: "" })).toBe("Army");
  });
});

describe("linkableAthletes", () => {
  it("keeps FBS and FCS players and drops Division II", () => {
    const found = linkableAthletes(
      [
        athlete({ athleteId: "5093788", teamName: "Tarleton State Texans" }),
        athlete({ athleteId: "152735", teamName: "Harvard Crimson" }),
        athlete({ athleteId: "3935499", teamName: "Mars Hill Lions" }),
      ],
      directory
    );
    expect(found.map((a) => [a.athleteId, a.teamId])).toEqual([
      ["5093788", "2627"],
      ["152735", "108"],
    ]);
  });

  it("resolves a pro player's club to the team id the player route needs", () => {
    const [mcdavid] = linkableAthletes(
      [athlete({ athleteId: "3895074", league: "nhl", teamName: "Edmonton Oilers" })],
      directory
    );
    expect(mcdavid.teamId).toBe("6");
  });

  it("resolves within the athlete's own league — id 2 is Auburn and the Bills", () => {
    const [player] = linkableAthletes(
      [athlete({ athleteId: "1", league: "nfl", teamName: "Buffalo Bills" })],
      directory
    );
    expect(player.teamId).toBe("2");
    expect(
      linkableAthletes(
        [athlete({ athleteId: "1", league: "nfl", teamName: "Auburn Tigers" })],
        directory
      )
    ).toEqual([]);
  });

  it("matches the club regardless of case and accents", () => {
    expect(
      linkableAthletes(
        [athlete({ athleteId: "9", league: "nhl", teamName: "edmonton OILERS" })],
        directory
      )
    ).toHaveLength(1);
  });

  it("drops a player with no club or a club the directory lacks", () => {
    expect(
      linkableAthletes(
        [
          athlete({ athleteId: "1", league: "nhl" }),
          athlete({ athleteId: "2", league: "nhl", teamName: "Utah Mammoth" }),
        ],
        directory
      )
    ).toEqual([]);
  });

  it("drops everything while the directory hasn't loaded", () => {
    expect(
      linkableAthletes([athlete({ athleteId: "1", teamName: "Harvard Crimson" })], [])
    ).toEqual([]);
  });

  it("dedupes a player listed twice", () => {
    const twice = athlete({ athleteId: "5", teamName: "Harvard Crimson" });
    expect(linkableAthletes([twice, { ...twice }], directory)).toHaveLength(1);
  });
});

describe("athleteIdFromUid", () => {
  it("reads the athlete segment, not the GUID", () => {
    expect(athleteIdFromUid("s:70~l:90~a:3895074")).toBe("3895074");
    expect(athleteIdFromUid("a:12~s:20")).toBe("12");
  });

  it("is undefined without an athlete segment", () => {
    expect(athleteIdFromUid("s:70~l:90")).toBeUndefined();
    expect(athleteIdFromUid("s:70~l:90~a:")).toBeUndefined();
    expect(athleteIdFromUid(undefined)).toBeUndefined();
  });
});

describe("transformAthleteSearch", () => {
  it("keeps the player group's people in the four leagues only", () => {
    const athletes = transformAthleteSearch({
      results: [
        {
          type: "player",
          contents: [
            {
              uid: "s:70~l:90~a:3895074",
              displayName: "Connor McDavid",
              subtitle: "Edmonton Oilers",
              defaultLeagueSlug: "nhl",
              image: { default: "https://a.espncdn.com/x.png" },
            },
            {
              uid: "s:20~l:23~a:152735",
              displayName: "Clem McDavid",
              subtitle: "Harvard Crimson",
              defaultLeagueSlug: "college-football",
              image: null,
            },
            {
              uid: "s:40~l:41~a:60456",
              displayName: "Tim McDavid",
              subtitle: null,
              defaultLeagueSlug: "mens-college-basketball",
            },
            { displayName: "No Uid", defaultLeagueSlug: "nfl" },
          ],
        },
        { type: "article", contents: [{ uid: "s:1~a:1", displayName: "x" }] },
        {},
      ],
    });
    expect(athletes).toEqual([
      {
        athleteId: "3895074",
        league: "nhl",
        name: "Connor McDavid",
        teamName: "Edmonton Oilers",
        headshotUrl: "https://a.espncdn.com/x.png",
      },
      {
        athleteId: "152735",
        league: "cfb",
        name: "Clem McDavid",
        teamName: "Harvard Crimson",
        headshotUrl: undefined,
      },
    ]);
  });

  it("reads an empty payload as no athletes", () => {
    expect(transformAthleteSearch({})).toEqual([]);
  });
});
