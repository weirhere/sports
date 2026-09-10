import { describe, expect, it } from "vitest";
import { popularTeams } from "./popular-teams";
import type { ConferenceTeams, Team } from "./types";
import type { League } from "./leagues";

function team(id: string, league: League): Team {
  return {
    id,
    espnId: Number(id),
    league,
    name: `${league}-${id}`,
    school: `${league}-${id}`,
    abbreviation: id,
    conferenceId: "8",
    conferenceName: "",
    logoUrl: "",
  };
}

function directory(entries: [League, string[]][]): ConferenceTeams[] {
  return entries.map(([league, ids], index) => ({
    id: String(index),
    league,
    name: league,
    rowId: `${league}-${index}`,
    teams: ids.map((id) => team(id, league)),
  }));
}

// The real shortlists, so the test moves if the curation does.
const CFB = ["194", "333", "61", "130", "251", "87", "213", "99", "2483", "30", "201", "228", "57", "2633", "158"];
const NFL = ["6", "12", "21", "25", "9", "23", "17", "2", "33", "8"];

describe("the popular shortlist", () => {
  it("interleaves leagues rather than stacking one on the other", () => {
    // A flat concatenation is a grouping whether or not anything says so, and
    // it would put every college program above every franchise — fifteen
    // cards of scrolling before an NFL fan sees a team they recognise.
    const teams = popularTeams(directory([["cfb", CFB], ["nfl", NFL]]));
    const leagues = teams.slice(0, 6).map((entry) => entry.league);
    expect(new Set(leagues).size).toBe(2);
    expect(leagues[0]).toBe("cfb");
    expect(leagues[1]).toBe("nfl");
  });

  it("keeps each league's own curated order within the mix", () => {
    const teams = popularTeams(directory([["cfb", CFB], ["nfl", NFL]]));
    const cfbOrder = teams.filter((t) => t.league === "cfb").map((t) => t.id);
    const nflOrder = teams.filter((t) => t.league === "nfl").map((t) => t.id);
    expect(cfbOrder).toEqual(CFB);
    expect(nflOrder).toEqual(NFL);
  });

  it("draws from a shorter list proportionally, so both finish together", () => {
    // Not round-robin by turn: a 15-team list and a 10-team one would leave
    // the shorter one running out a third of the way down.
    const teams = popularTeams(directory([["cfb", CFB], ["nfl", NFL]]));
    const lastNfl = teams.map((t) => t.league).lastIndexOf("nfl");
    const lastCfb = teams.map((t) => t.league).lastIndexOf("cfb");
    expect(Math.abs(lastNfl - lastCfb)).toBeLessThanOrEqual(2);
  });

  it("skips an id the directory doesn't carry", () => {
    // A realignment or a renamed franchise costs a row, never a crash.
    const teams = popularTeams(directory([["cfb", ["194", "9999999"]]]));
    expect(teams.map((t) => t.id)).toEqual(["194"]);
  });

  it("contributes nothing for a league whose teams haven't landed", () => {
    const teams = popularTeams(directory([["nfl", NFL]]));
    expect(teams.every((t) => t.league === "nfl")).toBe(true);
    expect(teams).toHaveLength(NFL.length);
  });

  it("is empty with an empty directory", () => {
    expect(popularTeams([])).toEqual([]);
  });
});
