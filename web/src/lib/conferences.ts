// The conference registry — a port of the iOS app's `Conference`
// (StatSideShared/Models/Team.swift). ESPN group ids, hardcoded per league
// with an "Other" fallback so an unknown id degrades to a bucket, never a
// crash.
//
// Every lookup takes a league because the id spaces overlap: 8 is the SEC in
// college football and the AFC in the NFL; 1 is the ACC and the NFC East;
// 4 is the Big 12 and the AFC East; 12 is Conference USA and the AFC North.

import {
  conferenceLogoBase,
  leagueLogoUrl,
  type League,
} from "./leagues";
import type { ConferenceRef } from "./refs";

/**
 * Browsing rank.
 *
 * `fcs` sits below the FBS rungs rather than crossing them: an FCS
 * conference has no P4/G5 meaning, but it does need a tier that isn't
 * `other`, because `other` is the unknown-id bucket and callers use it to
 * hide affordances. The pro rungs work the same way.
 *
 * `league` is a whole league standing as one table — the NFL's 32-team
 * board, or college football's FBS. It sits above the conference rung so it
 * leads its league's list: the league is what the conferences are parts of.
 */
export type ConferenceTier =
  | "power4"
  | "group5"
  | "independent"
  | "fcs"
  | "league"
  | "conference"
  | "division"
  | "other";

const TIER_RANK: Record<ConferenceTier, number> = {
  power4: 0,
  group5: 1,
  independent: 2,
  fcs: 3,
  league: 4,
  conference: 5,
  division: 6,
  other: 7,
};

export function tierRank(tier: ConferenceTier): number {
  return TIER_RANK[tier];
}

/**
 * College football's `groups=` parameter, which is also the division.
 *
 * Verified live 2026-09-01: group 81 returns 14 conferences / 116 teams and
 * ships the byte-identical week calendar as group 80. The pro leagues have
 * no analogue — their scoreboards take no group filter at all.
 */
export const FBS_GROUP_ID = 80;
export const FCS_GROUP_ID = 81;

export type CollegeDivision = "FBS" | "FCS";

export function divisionGroupId(division: CollegeDivision): number {
  return division === "FBS" ? FBS_GROUP_ID : FCS_GROUP_ID;
}

const FBS_NAMES: Record<number, string> = {
  1: "ACC",
  151: "American",
  4: "Big 12",
  5: "Big Ten",
  12: "Conference USA",
  18: "Independents",
  15: "MAC",
  17: "Mountain West",
  9: "Pac-12",
  8: "SEC",
  37: "Sun Belt",
};

/**
 * The 14 FCS conferences, ids read live from `standings?group=81` on
 * 2026-09-01. Short forms match the FBS list's style, except "FCS
 * Independents", which keeps its qualifier so it can't be read as id 18's
 * FBS "Independents".
 */
const FCS_NAMES: Record<number, string> = {
  20: "Big Sky",
  48: "CAA",
  32: "FCS Independents",
  22: "Ivy League",
  24: "MEAC",
  21: "Missouri Valley",
  25: "Northeast",
  179: "Ohio Valley",
  27: "Patriot League",
  28: "Pioneer",
  29: "Southern",
  30: "Southland",
  31: "SWAC",
  177: "United Athletic",
};

/**
 * College football's two divisions, named as the groups they are. They head
 * their own lists and each has a page. Deliberately *not* in the conference
 * tables above: those are the conference lists, and a division is what a
 * conference list belongs to, not an entry in one.
 */
const DIVISION_ROOT_NAMES: Record<number, string> = {
  [FBS_GROUP_ID]: "FBS",
  [FCS_GROUP_ID]: "FCS",
};

const CFB_NAMES: Record<number, string> = {
  ...FCS_NAMES,
  ...FBS_NAMES,
  ...DIVISION_ROOT_NAMES,
};

const POWER_4 = new Set([1, 4, 5, 8]);

/**
 * ESPN CDN slugs, verified live against the /scoreboard/conferences endpoint
 * (2026-07-20 for FBS, 2026-09-01 for FCS). Hardcoded like the name tables:
 * an unknown id just means no logo, never a broken image.
 *
 * United Athletic (177) has no mark under any plausible slug and is
 * deliberately absent, so it returns nothing rather than a URL that 404s.
 */
const CFB_LOGO_SLUGS: Record<number, string> = {
  1: "acc",
  151: "american",
  4: "big_12",
  5: "big_ten",
  12: "conference_usa",
  18: "fbs_independents",
  15: "mid_american",
  17: "mountain_west",
  9: "pac_12",
  8: "sec",
  37: "sun_belt",
  20: "big_sky",
  48: "caa",
  32: "fcs_independents",
  22: "ivy",
  24: "meac",
  21: "missouri_valley",
  25: "northeast",
  179: "ovc",
  27: "patriot_league",
  28: "pioneer",
  29: "southern",
  30: "southland",
  31: "swac",
};

/**
 * One pro league's group hierarchy, hardcoded because the scoreboard payload
 * carries none of it.
 *
 * ESPN's NFL, NBA and NHL scoreboards all ship team objects with no
 * conference or group id at all, so without this every game of theirs falls
 * into the "Other" bucket and a followed conference matches nothing. These
 * leagues realign about once a decade, an id the table doesn't know still
 * degrades to "Other", and a 30-row constant is the honest fix. College
 * football needs none of it — its scoreboard ships the conference id inline.
 */
interface Registry {
  /** The group that stands for the whole league. */
  leagueWideId: number;
  leagueName: string;
  /**
   * Ordered — this *is* `topLevelIds`. The short form is ESPN's own
   * `abbreviation` for the group ("East", "West", "AFC"), and it is what a
   * division's name is qualified with.
   */
  conferences: { id: number; name: string; short: string }[];
  divisionNames: Record<number, string>;
  /** Division id → its conference id. */
  divisionParents: Record<number, number>;
  /** Team id → its division id. */
  teamDivisions: Record<number, number>;
  /** CDN slugs for the conference marks this league actually publishes. */
  conferenceSlugs: Record<number, string>;
}

/** Ids read live from the NFL standings endpoint at `level=3`, 2026-09-05. */
const NFL_REGISTRY: Registry = {
  leagueWideId: 9,
  leagueName: "NFL",
  conferences: [
    { id: 8, name: "AFC", short: "AFC" },
    { id: 7, name: "NFC", short: "NFC" },
  ],
  divisionNames: {
    4: "AFC East", 12: "AFC North", 13: "AFC South", 6: "AFC West",
    1: "NFC East", 10: "NFC North", 11: "NFC South", 3: "NFC West",
  },
  divisionParents: { 4: 8, 12: 8, 13: 8, 6: 8, 1: 7, 10: 7, 11: 7, 3: 7 },
  teamDivisions: {
    1: 11, 2: 4, 3: 10, 4: 12, 5: 12, 6: 1, 7: 6, 8: 10,
    9: 10, 10: 13, 11: 13, 12: 6, 13: 6, 14: 3, 15: 4, 16: 10,
    17: 4, 18: 11, 19: 1, 20: 4, 21: 1, 22: 3, 23: 12, 24: 6,
    25: 3, 26: 3, 27: 11, 28: 1, 29: 11, 30: 13, 33: 12, 34: 13,
  },
  // `nfl/500/afc.png` and `nfl/500/nfc.png`, both verified 200 on
  // 2026-09-05. Divisions have no mark of their own.
  conferenceSlugs: { 8: "afc", 7: "nfc" },
};

/** Ids read live from the NBA standings endpoint at `level=3`, 2026-09-08. */
const NBA_REGISTRY: Registry = {
  leagueWideId: 7,
  leagueName: "NBA",
  conferences: [
    { id: 5, name: "Eastern", short: "East" },
    { id: 6, name: "Western", short: "West" },
  ],
  divisionNames: {
    1: "Atlantic", 2: "Central", 9: "Southeast",
    11: "Northwest", 4: "Pacific", 10: "Southwest",
  },
  divisionParents: { 1: 5, 2: 5, 9: 5, 11: 6, 4: 6, 10: 6 },
  teamDivisions: {
    1: 9, 2: 1, 3: 10, 4: 2, 5: 2, 6: 10, 7: 11, 8: 2,
    9: 4, 10: 10, 11: 2, 12: 4, 13: 4, 14: 9, 15: 2, 16: 11,
    17: 1, 18: 1, 19: 9, 20: 1, 21: 4, 22: 11, 23: 4, 24: 10,
    25: 11, 26: 11, 27: 9, 28: 1, 29: 10, 30: 9,
  },
  // The Eastern and Western Conference marks, filed beside the team logos
  // rather than in an `nba_conf` bucket — which is where the 2026-09-08
  // probe looked, found nothing, and wrongly concluded they didn't exist.
  // The divisions inherit them by the parent walk, which is what lets a row
  // say which conference it is in.
  conferenceSlugs: { 5: "east", 6: "west" },
};

/**
 * Ids read live from the NHL standings endpoint at `level=3`, 2026-09-08.
 * The two long team ids are real: NHL team ids are not contiguous.
 */
const NHL_REGISTRY: Registry = {
  leagueWideId: 9,
  leagueName: "NHL",
  conferences: [
    { id: 7, name: "Eastern", short: "East" },
    { id: 8, name: "Western", short: "West" },
  ],
  divisionNames: {
    32: "Atlantic", 33: "Metropolitan",
    31: "Central", 30: "Pacific",
  },
  divisionParents: { 32: 7, 33: 7, 31: 8, 30: 8 },
  teamDivisions: {
    1: 32, 2: 32, 3: 30, 4: 31, 5: 32, 6: 30, 7: 33, 8: 30,
    9: 31, 10: 32, 11: 33, 12: 33, 13: 33, 14: 32, 15: 33, 16: 33,
    17: 31, 18: 30, 19: 31, 20: 32, 21: 32, 22: 30, 23: 33, 25: 30,
    26: 32, 27: 31, 28: 31, 29: 33, 30: 31, 37: 30,
    124292: 30, 129764: 31,
  },
  // The NHL publishes no conference marks anywhere — every bucket and
  // spelling probed 2026-09-09. Its divisions wear the league shield, which
  // is the fallback for a league that has none.
  conferenceSlugs: {},
};

/** The pro leagues. College football is absent by design — its hierarchy
 * comes off the wire. */
const REGISTRIES: Partial<Record<League, Registry>> = {
  nfl: NFL_REGISTRY,
  nba: NBA_REGISTRY,
  nhl: NHL_REGISTRY,
};

function registryNames(registry: Registry): Record<number, string> {
  const names: Record<number, string> = { ...registry.divisionNames };
  for (const conference of registry.conferences) names[conference.id] = conference.name;
  names[registry.leagueWideId] = registry.leagueName;
  return names;
}

function names(league: League): Record<number, string> {
  if (league === "cfb") return CFB_NAMES;
  const registry = REGISTRIES[league];
  return registry ? registryNames(registry) : {};
}

function logoSlugs(league: League): Record<number, string> {
  if (league === "cfb") return CFB_LOGO_SLUGS;
  return REGISTRIES[league]?.conferenceSlugs ?? {};
}

/** The group id standing for a whole league, where the league has one.
 *
 * College football has no counterpart: group 80 is FBS, its root ships no
 * entries, and a 130-team table isn't a thing anyone reads — the poll
 * answers "who's good" there. */
export function leagueWideId(league: League): number | undefined {
  return REGISTRIES[league]?.leagueWideId;
}

/** Whether this id is a college-football division's root rather than a
 * conference in it. */
export function isDivisionRoot(
  id: number | null | undefined,
  league: League
): boolean {
  if (league !== "cfb" || id == null) return false;
  return DIVISION_ROOT_NAMES[id] !== undefined;
}

/**
 * The division a pro team plays in, for payloads that carry no group of
 * their own. Undefined for college football, whose scoreboard ships the
 * conference id inline.
 */
export function divisionForTeamId(
  teamId: string | null | undefined,
  league: League
): number | undefined {
  if (teamId == null) return undefined;
  const numeric = Number(teamId);
  if (!Number.isInteger(numeric)) return undefined;
  return REGISTRIES[league]?.teamDivisions[numeric];
}

/** The conference a pro league's division sits under, or undefined for
 * anything else — college football nests nothing. */
export function parentOf(
  id: number | null | undefined,
  league: League
): number | undefined {
  if (id == null) return undefined;
  return REGISTRIES[league]?.divisionParents[id];
}

/**
 * A conference's divisions, alphabetically. Empty for college football,
 * which nests nothing.
 */
export function childrenOf(
  id: number | null | undefined,
  league: League
): number[] {
  const registry = REGISTRIES[league];
  if (id == null || !registry) return [];
  return Object.entries(registry.divisionParents)
    .filter(([, parent]) => parent === id)
    .map(([child]) => Number(child))
    .sort((lhs, rhs) =>
      conferenceName(lhs, league) < conferenceName(rhs, league) ? -1 : 1
    );
}

/**
 * The list this group belongs to, and the page above it: a pro league's
 * whole-league table, or the college-football division a conference plays
 * in. Undefined for the roots themselves and for an id we can't place.
 */
export function rootAbove(ref: ConferenceRef): ConferenceRef | undefined {
  if (isDivisionRoot(ref.id, ref.league)) return undefined;
  const wide = leagueWideId(ref.league);
  if (wide !== undefined) {
    return wide === ref.id ? undefined : { league: ref.league, id: wide };
  }
  const division = collegeDivision(ref.id, ref.league);
  if (!division) return undefined;
  return { league: ref.league, id: divisionGroupId(division) };
}

/**
 * Every group a team in `ref` belongs to, most specific first: its division,
 * that division's conference, and the league itself. College football nests
 * nothing, so its chain is the conference and its division root.
 *
 * This is what makes a conference follow match a game: a pro league's
 * scoreboard gives a team its *division* id, so "I follow the AFC" only
 * means anything if the walk-up happens somewhere.
 */
export function conferenceChain(ref: ConferenceRef): ConferenceRef[] {
  const chain: ConferenceRef[] = [ref];
  const parent = parentOf(ref.id, ref.league);
  if (parent !== undefined) chain.push({ league: ref.league, id: parent });
  const root = rootAbove(chain[chain.length - 1]);
  if (root && root.id !== ref.id) chain.push(root);
  return chain;
}

/**
 * A group's display name, with its conference folded in where the name alone
 * doesn't place it — "Atlantic (Eastern)".
 *
 * A division is the row anyone reads, and half of them are named for a
 * compass point that says nothing about which half of the league they sit
 * in: the NBA's Atlantic and the NHL's are in different conferences of
 * different sports. The NFL needs none of this ("AFC East" already says it),
 * and college football has no divisions to qualify.
 */
export function conferenceName(
  id: number | null | undefined,
  league: League
): string {
  if (id == null) return "Other";
  const name = names(league)[id];
  if (name === undefined) return "Other";
  const parent = parentOf(id, league);
  const registry = REGISTRIES[league];
  if (parent === undefined || !registry) return name;
  const conference = registryNames(registry)[parent];
  if (conference === undefined) return name;
  // "Eastern", not "East" — a compass point breaks the short form:
  // "Southeast" contains "east" and "Northwest" contains "west", so exactly
  // the divisions that need placing would decide they already said it.
  if (name.toLowerCase().includes(conference.toLowerCase())) return name;
  return `${name} (${conference})`;
}

export function conferenceNameFor(
  ref: ConferenceRef | null | undefined
): string {
  return ref ? conferenceName(ref.id, ref.league) : "Other";
}

/**
 * Whether this league knows the id at all. The gate for affordances that
 * only make sense over a real conference — a Standings tab, the standings
 * cut line, conference follows.
 */
export function isKnownConference(
  id: number | null | undefined,
  league: League
): boolean {
  if (id == null) return false;
  return names(league)[id] !== undefined;
}

/**
 * Which college-football division a conference belongs to, or undefined for
 * an id the tables don't know. Always undefined for the pro leagues, which
 * have no division concept in this sense.
 */
export function collegeDivision(
  id: number | null | undefined,
  league: League
): CollegeDivision | undefined {
  if (league !== "cfb" || id == null) return undefined;
  if (DIVISION_ROOT_NAMES[id] !== undefined) {
    return id === FBS_GROUP_ID ? "FBS" : "FCS";
  }
  if (FBS_NAMES[id] !== undefined) return "FBS";
  return FCS_NAMES[id] !== undefined ? "FCS" : undefined;
}

export function tier(
  id: number | null | undefined,
  league: League
): ConferenceTier {
  if (id == null || names(league)[id] === undefined) return "other";
  const registry = REGISTRIES[league];
  if (!registry) {
    // College football: one flat list of conferences, ranked — under a
    // division root, which leads that list exactly as a league leads its
    // conferences.
    if (DIVISION_ROOT_NAMES[id] !== undefined) return "league";
    if (FCS_NAMES[id] !== undefined) return "fcs";
    if (POWER_4.has(id)) return "power4";
    if (id === 18) return "independent";
    return "group5";
  }
  if (id === registry.leagueWideId) return "league";
  return registry.conferences.some((c) => c.id === id) ? "conference" : "division";
}

/**
 * A conference's mark.
 *
 * A league's shield is filed under `leagues/`, not beside the conference
 * marks (`nfl/500/nfl.png` 404s — probed 2026-09-05). A college-football
 * division root wears the same mark: FBS and FCS are the sport, sliced.
 */
export function conferenceLogoUrl(
  id: number | null | undefined,
  league: League
): string | undefined {
  if (id == null) return undefined;
  if (id === leagueWideId(league) || isDivisionRoot(id, league)) {
    return leagueLogoUrl(league);
  }
  const slug = logoSlugs(league)[id];
  if (slug === undefined) {
    // A division wears its conference's mark — an AFC East header showing
    // the AFC shield reads better than a bare glyph.
    const parent = parentOf(id, league);
    if (parent !== undefined) return conferenceLogoUrl(parent, league);
    // A league that publishes *no* conference marks at all lets its
    // conferences wear its own shield: ESPN ships none for the NHL under any
    // bucket (probed 2026-09-09), so an Eastern Conference row would
    // otherwise fall to a bare glyph. A league that does publish them and is
    // simply missing one — FCS's United Athletic — still shows nothing,
    // because there the gap is about that conference, not the league.
    const publishesNone = Object.keys(logoSlugs(league)).length === 0;
    if (!publishesNone || !isKnownConference(id, league)) return undefined;
    return leagueLogoUrl(league);
  }
  return `${conferenceLogoBase(league)}/${slug}.png`;
}

export function conferenceLogoUrlFor(
  ref: ConferenceRef | null | undefined
): string | undefined {
  return ref ? conferenceLogoUrl(ref.id, ref.league) : undefined;
}

/**
 * One college-football division's conferences in browsing order: P4 → G5 →
 * Independents, alphabetical within each tier. FCS has one tier, so its list
 * is plainly alphabetical.
 */
export function orderedCollegeIds(division: CollegeDivision): number[] {
  const table = division === "FBS" ? FBS_NAMES : FCS_NAMES;
  return Object.keys(table)
    .map(Number)
    .sort((lhs, rhs) => {
      const [lt, rt] = [tierRank(tier(lhs, "cfb")), tierRank(tier(rhs, "cfb"))];
      if (lt !== rt) return lt - rt;
      return conferenceName(lhs, "cfb") < conferenceName(rhs, "cfb") ? -1 : 1;
    });
}

/**
 * Every known FBS conference in the app's browsing order. Deliberately still
 * FBS-only — college football's default slate is FBS-shaped, and FCS is
 * opt-in. Callers that want the other division ask for it by name.
 */
export const orderedIds: number[] = orderedCollegeIds("FBS");

/**
 * A league's top-level groups in browsing order. College football's are its
 * FBS conferences; a pro league's are its conferences, in ESPN's own order —
 * the divisions hang beneath them rather than sitting in the same list.
 */
export function topLevelIds(league: League): number[] {
  const registry = REGISTRIES[league];
  if (!registry) return orderedIds;
  return registry.conferences.map((c) => c.id);
}

/**
 * Whether this conference's championship game takes the standings' top two
 * that season — the gate for the standings cut line, which must never claim
 * top-two about a divisional-era pairing.
 *
 * FBS only. Every FBS conference has been one-table since 2024 except the
 * Sun Belt (one-table from 2026); Independents have no title game at all.
 * FCS settles its title in a 24-team playoff and holds no conference
 * championship games, and the pro postseasons are brackets.
 */
export function titleGameIsTopTwo(
  id: number | null | undefined,
  year: number,
  league: League
): boolean {
  if (league !== "cfb" || id == null) return false;
  if (collegeDivision(id, league) !== "FBS" || id === 18) return false;
  return year >= (id === 37 ? 2026 : 2024);
}

/**
 * CFBD identifies conferences by name, not id. Maps their names onto our
 * ESPN group ids. FBS-only, deliberately — CFBD is a college-football
 * backend and asks every endpoint for `classification=fbs`.
 */
const CFBD_NAMES: Record<string, number> = {
  "ACC": 1,
  "American Athletic": 151,
  "Big 12": 4,
  "Big Ten": 5,
  "Conference USA": 12,
  "FBS Independents": 18,
  "Mid-American": 15,
  "Mountain West": 17,
  "Pac-12": 9,
  "SEC": 8,
  "Sun Belt": 37,
};

export function conferenceIdForCfbdName(
  name: string | null | undefined
): number | undefined {
  if (name == null) return undefined;
  return CFBD_NAMES[name];
}
