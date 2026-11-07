import { describe, expect, it } from "vitest";
import { trophyFootnote } from "@/components/team-trophies-card";
import { LEAGUES } from "./leagues";
import { assembleTrophyCase, type TrophyKind } from "./trophies";
import { registryCoveredKinds, registrySources, registryTrophies } from "./trophy-registry";
import { COLLEGE_FOOTBALL_NATIONAL_TITLES } from "./trophy-registry-college-football";
import { NFL_CHAMPIONSHIPS, SUPER_BOWLS } from "./trophy-registry-nfl";

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
    for (const league of LEAGUES.filter((l) => l !== "cfb" && l !== "nfl")) {
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

/**
 * Per-franchise totals, counted from Wikipedia's year-by-year lists rather than
 * from the rows. Keyed by ESPN id; iOS's twin resolves the same ids from
 * abbreviations in the captured `nfl/teams` payload.
 */
const NFL_CHAMPIONSHIP_TOTALS: [string, string, number][] = [
  ["GB", "9", 9], ["CHI", "3", 8], ["NYG", "19", 4], ["DET", "8", 4], ["CLE", "5", 4],
  ["PHI", "21", 3], ["IND", "11", 2], ["ARI", "22", 2], ["LAR", "14", 2], ["WSH", "28", 2],
];
const SUPER_BOWL_TOTALS: [string, string, number][] = [
  ["PIT", "23", 6], ["SF", "25", 5], ["DAL", "6", 5], ["GB", "9", 4], ["NYG", "19", 4],
  ["NE", "17", 3], ["WSH", "28", 3], ["LV", "13", 3], ["DEN", "7", 2], ["MIA", "15", 2],
  ["BAL", "33", 2], ["IND", "11", 2], ["NYJ", "20", 1], ["KC", "12", 1], ["CHI", "3", 1],
  ["TB", "27", 1], ["NO", "18", 1], ["SEA", "26", 1], ["LAR", "14", 1],
];
const superBowl: TrophyKind = { singular: "Super Bowl", plural: "Super Bowls", tier: "league" };
const afc: TrophyKind = {
  singular: "AFC Championship",
  plural: "AFC Championships",
  tier: "conference",
};
const count = (winners: Record<number, string>, id: string) =>
  Object.values(winners).filter((winner) => winner === id).length;
const seasons = (winners: Record<number, string>) =>
  Object.keys(winners).map(Number).sort((a, b) => a - b);

describe("the NFL's honour rolls", () => {
  it("has NFL Championships 1920–65, less the six defunct champions", () => {
    const defunct = [1920, 1922, 1923, 1924, 1926, 1928];
    const expected = [];
    for (let year = 1920; year <= 1965; year++) if (!defunct.includes(year)) expected.push(year);
    expect(seasons(NFL_CHAMPIONSHIPS.winners)).toEqual(expected);
  });

  it("has a Super Bowl every season 1966–2013", () => {
    const expected = [];
    for (let year = 1966; year <= 2013; year++) expected.push(year);
    expect(seasons(SUPER_BOWLS.winners)).toEqual(expected);
  });

  it.each(NFL_CHAMPIONSHIP_TOTALS)("%s (%s) holds %i NFL Championships", (_, id, titles) => {
    expect(count(NFL_CHAMPIONSHIPS.winners, id)).toBe(titles);
  });

  it.each(SUPER_BOWL_TOTALS)("%s (%s) holds %i Super Bowls", (_, id, titles) => {
    expect(count(SUPER_BOWLS.winners, id)).toBe(titles);
  });

  it("accounts for every row through the franchises listed", () => {
    const sum = (rows: [string, string, number][]) => rows.reduce((total, [, , n]) => total + n, 0);
    expect(sum(NFL_CHAMPIONSHIP_TOTALS)).toBe(40);
    expect(sum(SUPER_BOWL_TOTALS)).toBe(48);
  });

  it("covers both league titles and names no source", () => {
    expect(registryCoveredKinds("nfl")).toEqual(new Set(["super bowl", "nfl championship"]));
    expect(registrySources("nfl").size).toBe(0);
  });

  it("gives the Packers nine and four", () => {
    const shelf = assembleTrophyCase({
      derived: [],
      registry: registryTrophies("9", "nfl"),
      allTimeKinds: registryCoveredKinds("nfl"),
      derivedFloor: 2014,
      sources: registrySources("nfl"),
    });
    expect(shelf.groups.map((group) => group.years.length)).toEqual([9, 4]);
    expect(shelf.groups.every((group) => group.coverage.kind === "allTime")).toBe(true);
  });

  it("puts the Patriots' registry and derived Super Bowls on one row", () => {
    const shelf = assembleTrophyCase({
      derived: [
        { kind: superBowl, year: 2014 },
        { kind: superBowl, year: 2016 },
        { kind: superBowl, year: 2018 },
        { kind: afc, year: 2017 },
      ],
      registry: registryTrophies("17", "nfl"),
      allTimeKinds: registryCoveredKinds("nfl"),
      derivedFloor: 2014,
      sources: registrySources("nfl"),
    });
    const [titles, conference] = shelf.groups;
    expect(titles.years).toEqual([2018, 2016, 2014, 2004, 2003, 2001]);
    expect(titles.coverage).toEqual({ kind: "allTime" });
    expect(conference.coverage).toEqual({ kind: "since", year: 2014 });
  });
});
