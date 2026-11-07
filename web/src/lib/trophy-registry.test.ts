import { describe, expect, it } from "vitest";
import { trophyFootnote } from "@/components/team-trophies-card";
import { LEAGUES } from "./leagues";
import { assembleTrophyCase, type TrophyKind } from "./trophies";
import { registryCoveredKinds, registrySources, registryTrophies } from "./trophy-registry";
import { COLLEGE_FOOTBALL_NATIONAL_TITLES } from "./trophy-registry-college-football";
import { NBA_CHAMPIONSHIPS } from "./trophy-registry-nba";

const SOURCE = "AP poll 1936–97 · title game since 1998";
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

/**
 * Per-school totals, derived independently of the rows: the AP National
 * Championship Trophy's by-team table cut at 2013, adjusted for 2003 (AP USC,
 * BCS LSU) and 2004 (vacated). Keyed by ESPN id; iOS's twin of this test
 * resolves the same ids from school names in the captured FBS standings.
 */
const TOTALS: [string, string, number][] = [
  ["Alabama", "333", 9], ["Notre Dame", "87", 8], ["Oklahoma", "201", 7],
  ["Miami", "2390", 5], ["Ohio State", "194", 4], ["Minnesota", "135", 4],
  ["Nebraska", "158", 4], ["USC", "30", 3], ["LSU", "99", 3], ["Texas", "251", 3],
  ["Florida", "57", 3], ["Florida State", "52", 3], ["Michigan", "130", 2],
  ["Tennessee", "2633", 2], ["Auburn", "2", 2], ["Army", "349", 2],
  ["Penn State", "213", 2], ["Pittsburgh", "221", 2], ["Georgia", "61", 1],
  ["Clemson", "228", 1], ["BYU", "252", 1], ["Colorado", "38", 1],
  ["Maryland", "120", 1], ["Michigan State", "127", 1], ["Syracuse", "183", 1],
  ["TCU", "2628", 1], ["Texas A&M", "245", 1],
];

const years = Object.keys(COLLEGE_FOOTBALL_NATIONAL_TITLES.winners).map(Number);

describe("college football's honour roll", () => {
  it("has one champion every season 1936–2013, bar vacated 2004", () => {
    const expected = [];
    for (let year = 1936; year <= 2013; year++) if (year !== 2004) expected.push(year);
    expect(years.sort((a, b) => a - b)).toEqual(expected);
  });

  it.each(TOTALS)("%s (%s) holds %i", (_, id, titles) => {
    expect(registryTrophies(id, "cfb")).toHaveLength(titles);
  });

  it("accounts for every row through the programs listed", () => {
    expect(TOTALS.reduce((sum, [, , n]) => sum + n, 0)).toBe(years.length);
  });

  it("covers the national title, names its source, and nothing else", () => {
    expect(registryCoveredKinds("cfb")).toEqual(new Set(["national championship"]));
    expect(registrySources("cfb").get("national championship")).toBe(SOURCE);
    for (const league of LEAGUES.filter((l) => l !== "cfb" && l !== "nba")) {
      expect(registryCoveredKinds(league).size).toBe(0);
      expect(registrySources(league).size).toBe(0);
    }
  });

  it("puts a registry title and a derived one on one row, captioned with its source", () => {
    const shelf = assembleTrophyCase({
      derived: [
        { kind: national, year: 2015 },
        { kind: national, year: 2017 },
        { kind: sec, year: 2023 },
      ],
      registry: registryTrophies("333", "cfb"),
      allTimeKinds: registryCoveredKinds("cfb"),
      derivedFloor: 2014,
      sources: registrySources("cfb"),
    });
    const [titles, conference] = shelf.groups;
    expect(titles.years).toHaveLength(11);
    expect(titles.coverage).toEqual({ kind: "allTime" });
    expect(titles.source).toBe(SOURCE);
    expect(conference.source).toBeUndefined();
    expect(trophyFootnote(shelf)).toBe(
      `National Championships: ${SOURCE}\nSEC Championship since 2014`
    );
  });
});

const nbaFinals: TrophyKind = { singular: "NBA Finals", plural: "NBA Finals", tier: "league" };

/**
 * Each franchise's titles through 2013–14, from the NBA's champions table with
 * relocations carried. iOS's twin resolves the same ids from abbreviations in
 * the captured NBA standings.
 */
const NBA_TOTALS: [string, string, number][] = [
  ["BOS", "2", 17], ["LAL", "13", 16], ["CHI", "4", 6], ["SA", "24", 5],
  ["GS", "9", 3], ["PHI", "20", 3], ["DET", "8", 3], ["MIA", "14", 3],
  ["NY", "18", 2], ["HOU", "10", 2], ["ATL", "1", 1], ["SAC", "23", 1],
  ["MIL", "15", 1], ["POR", "22", 1], ["WSH", "27", 1], ["OKC", "25", 1],
  ["DAL", "6", 1],
];

const nbaYears = Object.keys(NBA_CHAMPIONSHIPS.winners).map(Number);

describe("the NBA's honour roll", () => {
  it("has one champion every season 1946–47 to 2013–14, bar 1947–48", () => {
    const expected = [];
    for (let year = 1946; year <= 2013; year++) if (year !== 1947) expected.push(year);
    expect(nbaYears.sort((a, b) => a - b)).toEqual(expected);
  });

  it.each(NBA_TOTALS)("%s (%s) holds %i", (_, id, titles) => {
    expect(registryTrophies(id, "nba")).toHaveLength(titles);
  });

  it("accounts for every row through the franchises listed", () => {
    expect(NBA_TOTALS.reduce((sum, [, , n]) => sum + n, 0)).toBe(nbaYears.length);
  });

  it("covers the NBA Finals with no source", () => {
    expect(registryCoveredKinds("nba")).toEqual(new Set(["nba finals"]));
    expect(registrySources("nba").size).toBe(0);
  });

  it("reads the Celtics at 18, all-time", () => {
    const shelf = assembleTrophyCase({
      derived: [{ kind: nbaFinals, year: 2023 }],
      registry: registryTrophies("2", "nba"),
      allTimeKinds: registryCoveredKinds("nba"),
      derivedFloor: 2014,
      sources: registrySources("nba"),
    });
    const [titles] = shelf.groups;
    expect(titles.years).toHaveLength(18);
    expect(titles.coverage).toEqual({ kind: "allTime" });
    expect(titles.source).toBeUndefined();
  });
});
