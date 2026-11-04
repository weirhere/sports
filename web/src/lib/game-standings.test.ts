import { describe, expect, it } from "vitest";
import type { ConferenceStanding, ConferenceStandingsGroup } from "./types";
import type { League } from "./leagues";
import { gameStandingsScopes, gameStandingsTables } from "./game-standings";

function entry(id: string, winPercent = 0.5): ConferenceStanding {
  return {
    team: {
      id,
      espnId: Number(id) || 1,
      league: "nfl",
      name: "",
      school: id,
      abbreviation: id.slice(0, 3),
      conferenceId: "0",
      conferenceName: "",
      logoUrl: "",
    },
    conferenceWins: 0,
    conferenceLosses: 0,
    overallWins: 0,
    overallLosses: 0,
    conferenceRank: 1,
    winPercent,
  };
}

function table(
  id: number,
  name: string,
  ids: string[],
  extra: Partial<ConferenceStandingsGroup> = {},
  league: League = "nfl"
): ConferenceStandingsGroup {
  return { id: String(id), league, name, entries: ids.map((t) => entry(t)), ...extra };
}

// Buccaneers (27) at Panthers (29): both NFC South. Ravens (33) are AFC North.
const nfc = table(7, "National Football Conference", ["27", "29", "25"]);
const afc = table(8, "American Football Conference", ["33", "2"]);
const nfcSouth = table(11, "NFC South", ["27", "29"], { parentId: 7 });
const nfcWest = table(3, "NFC West", ["25"], { parentId: 7 });
const afcNorth = table(12, "AFC North", ["33"], { parentId: 8 });
const afcEast = table(4, "AFC East", ["2"], { parentId: 8 });
const nfl = [nfc, afc, nfcSouth, nfcWest, afcNorth, afcEast];

describe("gameStandingsScopes", () => {
  it("follows each league's hierarchy", () => {
    for (const league of ["cfb", "mcbb", "wcbb"] as League[]) {
      expect(gameStandingsScopes(league)).toEqual([]);
    }
    for (const league of ["nfl", "nba", "nhl", "mlb"] as League[]) {
      expect(gameStandingsScopes(league)).toEqual(["league", "conference", "division"]);
    }
    // Two conferences and no divisions: a Division chip would table nothing.
    expect(gameStandingsScopes("wnba")).toEqual(["league", "conference"]);
  });
});

describe("gameStandingsTables", () => {
  it("shows a divisional game's conference once, with both rows in it", () => {
    const shown = gameStandingsTables(nfl, "nfl", "27", "29", "conference");
    expect(shown.map((t) => t.id)).toEqual(["7"]);
  });

  it("shows a cross-conference game as two tables, away's first", () => {
    const shown = gameStandingsTables(nfl, "nfl", "33", "27", "conference");
    expect(shown.map((t) => t.id)).toEqual(["8", "7"]);
  });

  it("reads the divisional tables at Division scope", () => {
    expect(gameStandingsTables(nfl, "nfl", "27", "29", "division").map((t) => t.id))
      .toEqual(["11"]);
    expect(gameStandingsTables(nfl, "nfl", "33", "25", "division").map((t) => t.id))
      .toEqual(["12", "3"]);
  });

  it("is one league table at League scope", () => {
    const shown = gameStandingsTables(nfl, "nfl", "33", "27", "league");
    expect(shown).toHaveLength(1);
    expect(shown[0].id).toBe("9");
    expect(shown[0].entries).toHaveLength(5);
  });

  it("prefers a college conference over its division, and falls back to one", () => {
    const sec = table(8, "SEC", ["a", "b"], {}, "cfb");
    const secEast = table(99, "SEC - East", ["a"], { parentId: 8 }, "cfb");
    expect(gameStandingsTables([secEast, sec], "cfb", "a", "b", undefined).map((t) => t.id))
      .toEqual(["8"]);
    expect(gameStandingsTables([secEast], "cfb", "a", "b", undefined).map((t) => t.id))
      .toEqual(["99"]);
  });

  it("skips a team no table knows rather than inventing one", () => {
    expect(gameStandingsTables(nfl, "nfl", "27", "999", "conference").map((t) => t.id))
      .toEqual(["7"]);
  });

  it("ignores another league's tables", () => {
    const sec = table(8, "SEC", ["27"], {}, "cfb");
    expect(gameStandingsTables([sec, ...nfl], "nfl", "27", "29", "conference").map((t) => t.id))
      .toEqual(["7"]);
  });
});
