import { describe, expect, it } from "vitest";
import type { ConferenceStanding, ConferenceStandingsGroup } from "./types";
import type { League } from "./leagues";
import {
  divisionsIn,
  foldingDivisions,
  leaderOf,
  leaderRecord,
  leagueTable,
  tablesAtScope,
  divisionShortName,
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

describe("tablesAtScope", () => {
  // What `level=3` actually returns: divisions only, each parented. The
  // conferences are containers with no entries and are dropped at the
  // mapping boundary, so every scope has to derive them.
  const divisions: ConferenceStandingsGroup[] = [
    table(4, "AFC East", [entry("Buffalo", { winPercent: 0.8 })], { parentId: 8 }),
    table(12, "AFC North", [entry("Baltimore", { winPercent: 0.6 })], { parentId: 8 }),
    table(13, "AFC South", [entry("Houston", { winPercent: 0.5 })], { parentId: 8 }),
    table(6, "AFC West", [entry("Kansas City", { winPercent: 0.9 })], { parentId: 8 }),
    table(1, "NFC East", [entry("Philadelphia", { winPercent: 0.7 })], { parentId: 7 }),
    table(10, "NFC North", [entry("Detroit", { winPercent: 0.4 })], { parentId: 7 }),
    table(11, "NFC South", [entry("Tampa Bay", { winPercent: 0.3 })], { parentId: 7 }),
    table(3, "NFC West", [entry("San Francisco", { winPercent: 0.2 })], { parentId: 7 }),
  ];
  // What the provider actually hands a page: the shipped response's
  // conference tables (ESPN's own ranking) plus the divisional one.
  const conferences = [
    table(8, "AFC", [
      entry("Kansas City", { winPercent: 0.9 }),
      entry("Buffalo", { winPercent: 0.8 }),
    ]),
    table(7, "NFC", [
      entry("Philadelphia", { winPercent: 0.7 }),
      entry("Detroit", { winPercent: 0.4 }),
    ]),
  ];
  const full = [...conferences, ...divisions];
  const nfl = { league: "nfl" as const, id: 9 };
  const afc = { league: "nfl" as const, id: 8 };

  it("builds the league table from a divisions-only response", () => {
    // The bug this closes: `leagueTable` needs conferences, and a
    // `level=3` response has none — so the league page said "Standings
    // TBA" over a payload holding all 32 teams.
    const [league] = tablesAtScope(divisions, nfl, "league");
    expect(league.name).toBe("NFL");
    expect(league.entries).toHaveLength(8);
    expect(league.entries[0].team.school).toBe("Kansas City");
  });

  it("gives a league page both conferences and a conference page its own", () => {
    expect(tablesAtScope(full, nfl, "conference").map((t) => t.name)).toEqual([
      "AFC",
      "NFC",
    ]);
    expect(tablesAtScope(full, afc, "conference").map((t) => t.name)).toEqual([
      "AFC",
    ]);
  });

  it("splits a conference ESPN did NOT rank into its divisions", () => {
    // Divisions only, no real conference table: a merged AFC would number
    // 16 teams across four divisions nobody ranked against each other.
    expect(tablesAtScope(divisions, afc, "conference").map((t) => t.name)).toEqual([
      "AFC East",
      "AFC North",
      "AFC South",
      "AFC West",
    ]);
  });

  it("gives a league page every division and a conference page its own four", () => {
    expect(tablesAtScope(divisions, nfl, "division")).toHaveLength(8);
    expect(tablesAtScope(divisions, afc, "division").map((t) => t.name)).toEqual([
      "AFC East",
      "AFC North",
      "AFC South",
      "AFC West",
    ]);
  });

  it("shows a division's own page itself, not its children", () => {
    // Asking a division for its children finds nothing, which is how
    // every division page said "Standings TBA" while the row that pushed
    // it was teasing that division's leader.
    const east = { league: "nfl" as const, id: 4 };
    expect(tablesAtScope(divisions, east, "division").map((t) => t.name)).toEqual([
      "AFC East",
    ]);
  });
});

describe("divisionShortName", () => {
  it("strips the conference ESPN writes into every division's name", () => {
    expect(
      divisionShortName(table(163, "Sun Belt - East", [], {}, "cfb"), "Sun Belt")
    ).toBe("East");
    expect(divisionShortName(table(4, "AFC East", []), "AFC")).toBe("East");
  });

  it("cuts on the separator, not the parent's name", () => {
    // ESPN's conference half is often longer than our registry's name for
    // the same group — stripping "American " off "American Athletic - East"
    // left "Athletic - East".
    expect(
      divisionShortName(
        table(163, "American Athletic - East", [], {}, "cfb"),
        "American"
      )
    ).toBe("East");
  });

  it("leaves a name it can't strip alone", () => {
    expect(divisionShortName(table(4, "Atlantic", []), "Eastern")).toBe("Atlantic");
  });
});

describe("a real conference table is never rebuilt from its divisions", () => {
  // ESPN's own order for a conference encodes tiebreakers. A merge is each
  // division's list in turn and ranks nothing across them — printing a
  // place column over that is the guesswork the standings contract forbids.
  const real = table(7, "Eastern", [
    entry("Carolina", { points: 113 }),
    entry("Buffalo", { points: 109 }),
  ], {}, "nhl");
  const divisions = [
    table(32, "Atlantic", [entry("Buffalo", { points: 109 })], { parentId: 7 }, "nhl"),
    table(33, "Metropolitan", [entry("Carolina", { points: 113 })], { parentId: 7 }, "nhl"),
  ];

  it("keeps the fetched table and drops the merge", () => {
    const folded = foldingDivisions([real, ...divisions]);
    const eastern = folded.filter((t) => t.id === "7");
    expect(eastern).toHaveLength(1);
    expect(eastern[0].spansDivisions).toBeUndefined();
    expect(eastern[0].entries.map((e) => e.team.school)).toEqual([
      "Carolina",
      "Buffalo",
    ]);
  });

  it("still merges a conference that arrived only as divisions", () => {
    const folded = foldingDivisions(divisions);
    expect(folded).toHaveLength(1);
    expect(folded[0].spansDivisions).toBe(true);
  });

  it("ignores an empty container table", () => {
    // `level=3` ships the conferences with zero entries; those must not
    // stand in for the real thing.
    const empty = table(7, "Eastern", [], {}, "nhl");
    const folded = foldingDivisions([empty, ...divisions]);
    expect(folded.find((t) => t.id === "7")?.entries).toHaveLength(2);
  });
});

describe("a divisional conference keeps its divisions apart", () => {
  // 2019's American nests East and West under group 151, whose own entry
  // list is empty. Merging them numbers 12 teams across two divisions ESPN
  // never ranked against each other.
  const divisional = [
    table(163, "American Athletic - East", [entry("Cincinnati"), entry("Temple")], { parentId: 151 }, "cfb"),
    table(164, "American Athletic - West", [entry("Memphis"), entry("Navy")], { parentId: 151 }, "cfb"),
  ];
  const american = { league: "cfb" as const, id: 151 };

  it("shows one card per division rather than one merged ranking", () => {
    const shown = tablesAtScope(divisional, american, "conference");
    expect(shown.map((t) => t.name)).toEqual([
      "American Athletic - East",
      "American Athletic - West",
    ]);
    // Each ranked from 1, which is what ESPN actually ranked.
    expect(shown.every((t) => t.entries.length === 2)).toBe(true);
  });

  it("keeps a conference ESPN does rank as one table", () => {
    const real = table(7, "Eastern", [entry("Carolina"), entry("Buffalo")], {}, "nhl");
    const nhlDivisions = [
      table(32, "Atlantic", [entry("Buffalo")], { parentId: 7 }, "nhl"),
      table(33, "Metropolitan", [entry("Carolina")], { parentId: 7 }, "nhl"),
    ];
    const shown = tablesAtScope(
      [real, ...nhlDivisions],
      { league: "nhl", id: 7 },
      "conference"
    );
    expect(shown.map((t) => t.name)).toEqual(["Eastern"]);
  });
});
