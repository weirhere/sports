import { describe, it, expect } from "vitest";
import {
  searchTeams,
  searchConferences,
  searchGames,
  teamMatchTier,
  fold,
} from "./search-ranking";
import type { ConferenceTeams, Game, GameTeam, Team } from "./types";

function makeTeam(overrides: Partial<Team> & { id: string }): Team {
  return {
    espnId: Number(overrides.id),
    name: "Tigers",
    school: "Somewhere",
    abbreviation: "SMW",
    conferenceId: "8",
    conferenceName: "SEC",
    division: "FBS",
    logoUrl: "",
    ...overrides,
  };
}

const georgia = makeTeam({
  id: "61",
  school: "Georgia",
  name: "Bulldogs",
  abbreviation: "UGA",
});
const georgiaTech = makeTeam({
  id: "59",
  school: "Georgia Tech",
  name: "Yellow Jackets",
  abbreviation: "GT",
  conferenceId: "1",
  conferenceName: "ACC",
});
const georgiaSouthern = makeTeam({
  id: "290",
  school: "Georgia Southern",
  name: "Eagles",
  abbreviation: "GASO",
  conferenceId: "37",
  conferenceName: "Sun Belt",
});
const sanJoseState = makeTeam({
  id: "23",
  school: "San José State",
  name: "Spartans",
  abbreviation: "SJSU",
  conferenceId: "17",
  conferenceName: "Mountain West",
});
const kansas = makeTeam({
  id: "2305",
  school: "Kansas",
  name: "Jayhawks",
  abbreviation: "KU",
  conferenceId: "4",
  conferenceName: "Big 12",
});
const arkansas = makeTeam({
  id: "8",
  school: "Arkansas",
  name: "Razorbacks",
  abbreviation: "ARK",
});

const directory: ConferenceTeams[] = [
  { id: "1", name: "ACC", teams: [georgiaTech] },
  { id: "4", name: "Big 12", teams: [kansas] },
  { id: "8", name: "SEC", teams: [arkansas, georgia] },
  { id: "17", name: "Mountain West", teams: [sanJoseState] },
  { id: "37", name: "Sun Belt", teams: [georgiaSouthern] },
];

function makeGame(
  id: string,
  away: Team,
  home: Team,
  scheduledAt: string
): Game {
  const side = (team: Team): GameTeam => ({ team, score: null });
  return {
    id,
    status: "scheduled",
    scheduledAt,
    venue: { name: "", city: "", state: "" },
    homeTeam: side(home),
    awayTeam: side(away),
    week: 1,
    seasonYear: 2026,
    conferenceGame: false,
  };
}

describe("fold", () => {
  it("is case- and diacritic-insensitive", () => {
    expect(fold("San José State")).toBe("san jose state");
    expect(fold("JOSÉ")).toBe("jose");
  });
});

describe("teamMatchTier", () => {
  it("tiers exact abbreviation, word prefix, and substring", () => {
    expect(teamMatchTier("uga", georgia)).toBe(0);
    expect(teamMatchTier("geor", georgia)).toBe(1);
    expect(teamMatchTier("eorgi", georgia)).toBe(2);
    expect(teamMatchTier("zzz", georgia)).toBeNull();
  });
});

describe("searchTeams", () => {
  it("returns nothing for an empty or whitespace query", () => {
    expect(searchTeams("", directory)).toEqual([]);
    expect(searchTeams("   ", directory)).toEqual([]);
  });

  it("puts an exact abbreviation match ahead of everything else", () => {
    // "UGA" is Georgia's abbreviation (tier 0). Even a team whose school
    // word-prefixes the query would rank behind it.
    const results = searchTeams("UGA", directory);
    expect(results[0]).toEqual(georgia);
  });

  it("ranks word-prefix matches above substring-anywhere matches", () => {
    // "kan": word prefix on "Kansas" (tier 1) beats the mid-word substring
    // in "Arkansas" (tier 2).
    const results = searchTeams("kan", directory);
    expect(results.map((t) => t.school)).toEqual(["Kansas", "Arkansas"]);
  });

  it("folds diacritics — 'jose' finds San José State", () => {
    const results = searchTeams("jose", directory);
    expect(results).toEqual([sanJoseState]);
  });

  it("sorts same-tier matches alphabetically by school", () => {
    const results = searchTeams("georgia", directory);
    expect(results.map((t) => t.school)).toEqual([
      "Georgia",
      "Georgia Southern",
      "Georgia Tech",
    ]);
  });

  it("boosts followed teams first when a follow set is passed", () => {
    const results = searchTeams("georgia", directory, new Set(["59"]));
    expect(results.map((t) => t.school)).toEqual([
      "Georgia Tech",
      "Georgia",
      "Georgia Southern",
    ]);
  });

  it("skips the follow boost when no follow set is passed", () => {
    // The onboarding/Teams inline filters: rows toggle follows, so the
    // order must not change under the user's finger.
    const before = searchTeams("georgia", directory);
    const after = searchTeams("georgia", directory);
    expect(after).toEqual(before);
    expect(after.map((t) => t.school)).toEqual([
      "Georgia",
      "Georgia Southern",
      "Georgia Tech",
    ]);
  });

  it("dedupes a team appearing in more than one group", () => {
    const doubled: ConferenceTeams[] = [
      ...directory,
      { id: "99", name: "Duplicates", teams: [georgia] },
    ];
    const results = searchTeams("georgia", doubled);
    expect(results.filter((t) => t.id === "61")).toHaveLength(1);
  });
});

describe("searchConferences", () => {
  const refs = [
    { id: 8, name: "SEC" },
    { id: 37, name: "Sun Belt" },
    { id: 1, name: "ACC" },
    { id: 12, name: "Conference USA" },
  ];

  it("puts prefix matches before substring matches, alphabetical within", () => {
    const results = searchConferences("s", refs);
    expect(results.map((c) => c.name)).toEqual([
      "SEC",
      "Sun Belt",
      "Conference USA",
    ]);
  });

  it("matches case-insensitively", () => {
    expect(searchConferences("sec", refs).map((c) => c.name)).toEqual(["SEC"]);
  });
});

describe("searchGames", () => {
  const late = makeGame("2", georgia, georgiaTech, "2026-09-05T23:30:00Z");
  const early = makeGame("1", sanJoseState, kansas, "2026-09-05T16:00:00Z");

  it("matches by either side and sorts chronologically", () => {
    const results = searchGames("georgia", [late, early]);
    expect(results).toEqual([late]);
    // Both games match "s" (Spartans/State; Bulldogs as a substring) —
    // the earlier kickoff sorts first.
    const all = searchGames("s", [late, early]);
    expect(all.map((g) => g.id)).toEqual(["1", "2"]);
  });

  it("matches the matchup name as a substring", () => {
    const results = searchGames("bulldogs at georgia tech", [late, early]);
    expect(results).toEqual([late]);
  });

  it("orders same-time games by id", () => {
    const a = makeGame("10", georgia, kansas, "2026-09-05T16:00:00Z");
    const b = makeGame("11", georgiaTech, arkansas, "2026-09-05T16:00:00Z");
    const results = searchGames("a", [b, a]);
    expect(results.map((g) => g.id)).toEqual(["10", "11"]);
  });
});
