// The closed history a trophy case can't derive: the seasons before
// `SEASON_FLOOR`, which ESPN's season axis cannot reach at all. The web twin
// of iOS `TrophyRegistry` (StatSideShared/Models/TrophyRegistry.swift), kept
// as a separate module for the same reason it is a separate file there — the
// mechanism is code, the rows are data, and they are added at different times.
//
// **This ships empty, deliberately, and the reason is the point.** A trophy
// count is a claim about history printed as a fact, and hand-transcribing a
// few hundred rows of it produces a number no one can check. A league with no
// rows here is not broken: its case simply reports what the wire says,
// captioned "since 2014" — correct, and never a wrong number. That gate is
// `registryCoveredKinds`.
//
// ## Populating it
//
// Three definitional calls have to be made first, and they are product
// decisions rather than engineering ones. Each changes what a famous team's
// page claims:
//
// 1. **Which selector is a college football national title?** Alabama's case
//    says 18 under its own claims, 13 under the AP, and 6 under
//    BCS-and-CFP-title-games-only. Whatever is chosen belongs in the coverage
//    caption so the page says it out loud.
// 2. **Do pre-Super-Bowl NFL championships count?** The Packers won nine of
//    them. If they do, they need a trophy kind of their own — a "Super Bowls"
//    row must never absorb a title won before the game existed.
// 3. **Where do a defunct franchise's titles go?** The original Ottawa
//    Senators won eleven Stanley Cups and the current Senators are a 1992
//    expansion team that has won none.
//
// ## Keying
//
// By ESPN team id. An id that matches nothing contributes nothing, so a bad
// row costs a missing trophy rather than a misplaced one.

import type { League } from "@/lib/leagues";
import { trophyKindIdentity } from "@/lib/trophies";
import type { Trophy, TrophyKind } from "@/lib/trophies";

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
}

/** Empty until the three calls above are made and the rows are sourced. */
const LISTS: Partial<Record<League, TitleList[]>> = {};

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
