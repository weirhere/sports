// The closed history a trophy case can't derive: the seasons before
// `SEASON_FLOOR`, which ESPN's season axis cannot reach at all. The web twin
// of iOS `TrophyRegistry` (StatSideShared/Models/TrophyRegistry.swift), kept
// as a separate module for the same reason it is a separate file there — the
// mechanism is code, the rows are data, and they are added at different times.
//
// A trophy count is a claim about history printed as a fact, so **only a list
// checked against a citable source is ever read** (`verified`), and a league
// with no list here is not broken: its case reports what the wire says,
// captioned "since 2014" — correct, and never a wrong number. That gate is
// `registryCoveredKinds`.
//
// ## What counts (decided 2026-11-04, COR-94)
//
// 1. **College football's national title is the AP poll's champion for
//    1936–1997, then the title game** (BCS 1998–2013, CFP from 2014, which the
//    derived path reads). One winner a season; USC's vacated 2004 has no row.
//    The list carries that choice as `source`, and the card prints it.
// 2. **Pre-Super-Bowl NFL championships count, as their own kind**, 1920–1965.
// 3. **Titles follow the franchise, not the name**; a franchise with no
//    successor contributes nothing.
//
// ## Keying
//
// By ESPN team id. An id that matches nothing contributes nothing, so a bad
// row costs a missing trophy rather than a misplaced one.

import type { League } from "@/lib/leagues";
import { trophyKindIdentity } from "@/lib/trophies";
import type { Trophy, TrophyKind } from "@/lib/trophies";
import { COLLEGE_FOOTBALL_NATIONAL_TITLES } from "@/lib/trophy-registry-college-football";
import { NBA_CHAMPIONSHIPS } from "@/lib/trophy-registry-nba";
import { NFL_CHAMPIONSHIPS, SUPER_BOWLS } from "@/lib/trophy-registry-nfl";

/**
 * One trophy's whole honour roll, as it is published: a list of seasons and
 * who won each. Champion-list shaped rather than team-keyed because that is
 * the form every source prints it in, so an added row can be read straight
 * down against one.
 */
export interface TitleList {
  kind: TrophyKind;
  /** Season year (the year the season *opens*) → the winning team's ESPN id. */
  winners: Record<number, string>;
  /**
   * Whether these rows have been checked against a source that can actually be
   * cited. **Only a verified list is ever read**, so a half-entered honour roll
   * can't reach a team page and print a count that is quietly short.
   */
  verified: boolean;
  /**
   * The selector behind the list, printed in the card's caption when the count
   * depends on which one was chosen. Absent where the trophy is its own source.
   */
  source?: string;
}

const LISTS: Partial<Record<League, TitleList[]>> = {
  cfb: [COLLEGE_FOOTBALL_NATIONAL_TITLES],
  nfl: [SUPER_BOWLS, NFL_CHAMPIONSHIPS],
  nba: [NBA_CHAMPIONSHIPS],
};

/** Every registry trophy this team holds. */
export function registryTrophies(teamId: string, league: League): Trophy[] {
  return (LISTS[league] ?? [])
    .filter((list) => list.verified)
    .flatMap((list) =>
      Object.entries(list.winners)
        .filter(([, winner]) => winner === teamId)
        .map(([year]) => ({ kind: list.kind, year: Number(year) }))
    );
}

/**
 * The trophies whose *whole* history this registry speaks for, by
 * `TrophyKind.singular`.
 *
 * What makes a row's coverage caption honest. A league title in here is
 * all-time; anything else — every conference title, always — is only as old as
 * the derivation, because no registry list carries conference championships
 * and none is planned to. There are eleven college football conferences
 * against sixty years of realignment, and a conference table is the one part
 * of this a season fetch already answers correctly.
 */
export function registryCoveredKinds(league: League): Set<string> {
  return new Set(
    (LISTS[league] ?? [])
      .filter((list) => list.verified)
      .map((list) => trophyKindIdentity(list.kind))
  );
}

/**
 * The selector each covered trophy is counted by, by `trophyKindIdentity`, for
 * the card's caption. Only verified lists, like everything else read here.
 */
export function registrySources(league: League): Map<string, string> {
  const sources = new Map<string, string>();
  for (const list of LISTS[league] ?? []) {
    if (list.verified && list.source) {
      sources.set(trophyKindIdentity(list.kind), list.source);
    }
  }
  return sources;
}
