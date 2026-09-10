import { describe, expect, it } from "vitest";
import type { ConferenceStanding, ConferenceStandingsGroup } from "./types";
import type { League } from "./leagues";
import {
  divisionsIn,
  foldingDivisions,
  leaderOf,
  leaderRecord,
  leagueTable,
} from "./standings-tables";

function entry(
  school: string,
  overrides: Partial<ConferenceStanding> = {}
): ConferenceStanding {
  return {
    team: {
      id: school,
      espnId: 1,
      league: "nfl",
      name: "",
      school,
      abbreviation: school.slice(0, 3),
      conferenceId: "0",
      conferenceName: "",
      logoUrl: "",
    },
    conferenceWins: 0,
    conferenceLosses: 0,
    overallWins: 0,
    overallLosses: 0,
    conferenceRank: 1,
    ...overrides,
  };
}

function table(
  id: number,
  name: string,
  entries: ConferenceStanding[],
  extra: Partial<ConferenceStandingsGroup> = {},
  league: League = "nfl"
): ConferenceStandingsGroup {
  return { id: String(id), league, name, entries, ...extra };
}

describe("foldingDivisions", () => {
  it("merges a conference's divisions into one row", () => {
    // The Sun Belt, not "Sun Belt - East" and "Sun Belt - West"; the AFC,
    // not its four.
    const folded = foldingDivisions([
      table(4, "AFC East", [entry("Buffalo")], { parentId: 8 }),
      table(12, "AFC North", [entry("Baltimore")], { parentId: 8 }),
    ]);
    expect(folded).toHaveLength(1);
    expect(folded[0].name).toBe("AFC");
    expect(folded[0].entries).toHaveLength(2);
  });

  it("marks a merged row so nothing reads a division leader as the conference's", () => {
    const folded = foldingDivisions([
      table(4, "AFC East", [entry("Buffalo", { overallWins: 4 })], { parentId: 8 }),
      table(12, "AFC North", [entry("Baltimore")], { parentId: 8 }),
    ]);
    expect(folded[0].spansDivisions).toBe(true);
    expect(leaderOf(folded[0])).toBeUndefined();
  });

  it("leaves a single-division conference unmarked", () => {
    const folded = foldingDivisions([
      table(4, "AFC East", [entry("Buffalo", { conferenceRecord: "3-1" })], {
        parentId: 8,
      }),
    ]);
    expect(folded[0].spansDivisions).toBe(false);
    expect(leaderOf(folded[0])?.team.school).toBe("Buffalo");
  });

  it("passes an unparented table through untouched", () => {
    const sec = table(8, "SEC", [entry("Georgia")], {}, "cfb");
    expect(foldingDivisions([sec])).toEqual([sec]);
  });

  it("re-sorts by tier, which is what puts FBS above FCS in one pass", () => {
    // College football's two divisions are separate fetches but one list,
    // and `.fcs` sits below `.independent` on the tier rung.
    const folded = foldingDivisions([
      table(20, "Big Sky", [entry("Montana")], {}, "cfb"),
      table(8, "SEC", [entry("Georgia")], {}, "cfb"),
      table(18, "Independents", [entry("Notre Dame")], {}, "cfb"),
      table(15, "MAC", [entry("Toledo")], {}, "cfb"),
    ]);
    expect(folded.map((t) => t.name)).toEqual([
      "SEC", // power4
      "MAC", // group5
      "Independents",
      "Big Sky", // fcs
    ]);
  });
});

describe("leagueTable", () => {
  const afc = table(8, "AFC", [
    entry("Buffalo", { winPercent: 0.8 }),
    entry("Miami", { winPercent: 0.4 }),
  ]);
  const nfc = table(7, "NFC", [
    entry("Philadelphia", { winPercent: 0.9 }),
    entry("Dallas", { winPercent: 0.5 }),
  ]);

  it("merges every conference and ranks by win percentage", () => {
    const league = leagueTable([afc, nfc], "nfl");
    expect(league?.name).toBe("NFL");
    expect(league?.entries.map((e) => e.team.school)).toEqual([
      "Philadelphia",
      "Buffalo",
      "Dallas",
      "Miami",
    ]);
  });

  it("refuses to build a table missing one of its conferences", () => {
    // A table calling itself the NFL with the NFC absent is a lie the row
    // can't qualify.
    expect(leagueTable([afc], "nfl")).toBeUndefined();
  });

  it("ranks the NHL on points, which is the only number it keeps", () => {
    // The NHL ships no `winpercent` at all, so ranking on it fell to the
    // source-order tiebreak and the table came back East's seeds then
    // West's — a ranking that ranked nothing.
    const east = table(7, "Eastern", [entry("Boston", { points: 90 })], {}, "nhl");
    const west = table(8, "Western", [entry("Dallas", { points: 113 })], {}, "nhl");
    const league = leagueTable([east, west], "nhl");
    expect(league?.entries.map((e) => e.team.school)).toEqual([
      "Dallas",
      "Boston",
    ]);
  });

  it("has no counterpart in college football", () => {
    // Group 80 is FBS, its root ships no entries, and a 130-team table
    // isn't a thing anyone reads — the poll answers "who's good" there.
    expect(leagueTable([table(8, "SEC", [entry("Georgia")], {}, "cfb")], "cfb"))
      .toBeUndefined();
  });

  it("ignores divisions, which would double every team", () => {
    const withDivisions = [afc, nfc, table(4, "AFC East", [entry("Buffalo")], { parentId: 8 })];
    expect(leagueTable(withDivisions, "nfl")?.entries).toHaveLength(4);
  });
});

describe("divisionsIn", () => {
  it("groups by conference, alphabetical inside it", () => {
    // The mapper sorts by name alone, which interleaves the NBA's six:
    // Northwest lands between Central and Pacific with nothing on screen
    // to explain why.
    const nba: ConferenceStandingsGroup[] = [
      table(11, "Northwest", [], { parentId: 6 }, "nba"),
      table(2, "Central", [], { parentId: 5 }, "nba"),
      table(4, "Pacific", [], { parentId: 6 }, "nba"),
      table(1, "Atlantic", [], { parentId: 5 }, "nba"),
    ];
    expect(divisionsIn(nba, "nba").map((t) => t.name)).toEqual([
      "Atlantic", // Eastern (topLevelIds order)
      "Central",
      "Northwest", // Western
      "Pacific",
    ]);
  });

  it("skips the conferences themselves", () => {
    const tables = [table(8, "AFC", []), table(4, "AFC East", [], { parentId: 8 })];
    expect(divisionsIn(tables, "nfl").map((t) => t.name)).toEqual(["AFC East"]);
  });
});

describe("the leader teaser", () => {
  it("falls back to the overall record where a league keeps no in-group one", () => {
    // The NHL ships no `vsconf`, so every hockey row on the hub sat bare
    // while the NBA rows above it read "Boston · 36-16".
    expect(leaderRecord(entry("Boston", { overallRecord: "53-22-7" }))).toBe(
      "53-22-7"
    );
    expect(
      leaderRecord(entry("Georgia", { conferenceRecord: "7-1", overallRecord: "9-1" }))
    ).toBe("7-1");
  });

  it("hides a preseason 0-0 leader, which is last season's carry-over", () => {
    expect(leaderOf(table(8, "AFC", [entry("Buffalo", { conferenceRecord: "0-0" })]))).toBeUndefined();
    expect(leaderOf(table(7, "Eastern", [entry("Boston", { overallRecord: "0-0-0" })], {}, "nhl"))).toBeUndefined();
  });

  it("shows one once anyone has played", () => {
    expect(
      leaderOf(table(8, "AFC", [entry("Buffalo", { conferenceRecord: "1-0" })]))
        ?.team.school
    ).toBe("Buffalo");
  });

  it("has no leader for an empty table", () => {
    expect(leaderOf(table(8, "AFC", []))).toBeUndefined();
  });
});
