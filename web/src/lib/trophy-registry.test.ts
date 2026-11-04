import { describe, expect, it } from "vitest";
import { trophyFootnote } from "@/components/team-trophies-card";
import { LEAGUES } from "./leagues";
import { assembleTrophyCase, type TrophyKind } from "./trophies";
import { registryCoveredKinds, registrySources, registryTrophies } from "./trophy-registry";
import { COLLEGE_FOOTBALL_NATIONAL_TITLES } from "./trophy-registry-college-football";

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
    for (const league of LEAGUES.filter((l) => l !== "cfb")) {
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
