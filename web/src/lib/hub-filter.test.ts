import { describe, expect, it } from "vitest";
import {
  filterFollowed,
  filterHubGroups,
  hubQuery,
  matchesQuery,
} from "./hub-filter";

interface Group {
  id: string;
  title: string;
  rows: string[];
}

const GROUPS: Group[] = [
  {
    id: "cfb",
    title: "College Football",
    rows: ["College Football Poll", "FBS", "SEC", "Big Ten", "FCS", "Big Sky"],
  },
  { id: "nfl", title: "NFL", rows: ["NFL", "AFC East", "NFC North"] },
  { id: "nba", title: "NBA", rows: ["NBA", "Atlantic", "Southeast"] },
  { id: "nhl", title: "NHL", rows: ["NHL", "Atlantic", "Metropolitan"] },
];

const identity = (row: string) => row;
const ids = (groups: Group[]) => groups.map((group) => group.id);

describe("hubQuery / matchesQuery", () => {
  it("ignores surrounding whitespace", () => {
    expect(hubQuery("  sec \t")).toBe("sec");
    expect(matchesQuery("SEC", "  sec  ")).toBe(true);
  });

  it("is case-insensitive containment", () => {
    expect(matchesQuery("Big Ten", "big t")).toBe(true);
    expect(matchesQuery("Big Ten", "TEN")).toBe(true);
    expect(matchesQuery("Big Ten", "big12")).toBe(false);
  });

  it("matches everything on an empty or blank query", () => {
    expect(matchesQuery("anything", "")).toBe(true);
    expect(matchesQuery("anything", "   ")).toBe(true);
  });
});

describe("filterHubGroups", () => {
  it("returns every group untouched when the query is blank", () => {
    const result = filterHubGroups(GROUPS, " ", identity);
    expect(result).toEqual(GROUPS);
    // A copy: the caller's array is never the one handed back to mutate.
    expect(result).not.toBe(GROUPS);
  });

  it("keeps a whole league when its own title matches", () => {
    const [nfl] = filterHubGroups(GROUPS, "nfl", identity);
    expect(nfl.id).toBe("nfl");
    // All three rows, not just the one also named "NFL" — you asked for
    // the league.
    expect(nfl.rows).toEqual(["NFL", "AFC East", "NFC North"]);
  });

  it("keeps only the matching rows when a table inside matches", () => {
    const result = filterHubGroups(GROUPS, "big", identity);
    expect(ids(result)).toEqual(["cfb"]);
    expect(result[0].rows).toEqual(["Big Ten", "Big Sky"]);
  });

  it("narrows several leagues at once, each to its own matches", () => {
    const result = filterHubGroups(GROUPS, "atlantic", identity);
    expect(ids(result)).toEqual(["nba", "nhl"]);
    expect(result.map((group) => group.rows)).toEqual([
      ["Atlantic"],
      ["Atlantic"],
    ]);
  });

  it("drops a league with no match in its title or rows", () => {
    expect(ids(filterHubGroups(GROUPS, "metro", identity))).toEqual(["nhl"]);
    expect(filterHubGroups(GROUPS, "premier league", identity)).toEqual([]);
  });

  it("keeps the group's other fields on a narrowed copy", () => {
    const [cfb] = filterHubGroups(GROUPS, "sec", identity);
    expect(cfb).toMatchObject({ id: "cfb", title: "College Football" });
    // The source group is not narrowed in place.
    expect(GROUPS[0].rows).toHaveLength(6);
  });

  it("matches rows by the title the caller supplies", () => {
    const groups = [
      { title: "College Football", rows: [{ kind: "poll" }, { kind: "sec" }] },
    ];
    const title = (row: { kind: string }) =>
      row.kind === "poll" ? "College Football Poll" : "SEC";
    const [cfb] = filterHubGroups(groups, "poll", title);
    expect(cfb.rows).toEqual([{ kind: "poll" }]);
  });
});

describe("filterFollowed", () => {
  const followed = ["SEC", "College Football Poll", "AFC East"];

  it("returns everything on a blank query", () => {
    expect(filterFollowed(followed, "", identity)).toEqual(followed);
  });

  it("narrows by the same rule as the accordions' rows", () => {
    expect(filterFollowed(followed, "east", identity)).toEqual(["AFC East"]);
    expect(filterFollowed(followed, "POLL", identity)).toEqual([
      "College Football Poll",
    ]);
    expect(filterFollowed(followed, "nhl", identity)).toEqual([]);
  });
});
