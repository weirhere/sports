// How wide a standings page tables its teams — a port of iOS
// `StandingsScope` (StatSideShared/Models/StandingsScope.swift).
//
// A scope is a **view of one fetch**, not a different set of teams: an NFL
// page shows the same 32 either way, in one table, two, or eight. Which
// scopes a page offers comes from where that page sits in the league's own
// hierarchy, so nothing has to be listed per conference — and college
// football, which nests nothing, offers none at all.

import { conferenceChain, leagueWideId, tier } from "./conferences";
import type { ConferenceRef } from "./refs";

export const STANDINGS_SCOPES = ["league", "conference", "division"] as const;
export type StandingsScope = (typeof STANDINGS_SCOPES)[number];

export function scopeTitle(scope: StandingsScope): string {
  switch (scope) {
    case "league":
      return "League";
    case "conference":
      return "Conference";
    case "division":
      return "Division";
  }
}

/**
 * The scopes a **conference page** can show: its own level and everything
 * under it. The league page offers all three, a conference page the two
 * below it, and anything that nests nothing offers none — which is what
 * hides the control.
 *
 * A rung only counts where there is a table at it. College football's
 * division roots sit at the `league` rung — FBS leads its eleven the way
 * the NFL leads its two — but the sport keeps no 136-team table and nests
 * no divisions under a conference, so a root there offers no choice at all.
 */
export function scopesFor(ref: ConferenceRef): StandingsScope[] {
  if (leagueWideId(ref.league) === undefined) return [];
  switch (tier(ref.id, ref.league)) {
    case "league":
      return ["league", "conference", "division"];
    case "conference":
      return ["conference", "division"];
    default:
      return [];
  }
}

/**
 * The scopes a **team page** can show: every level the team itself belongs
 * to — its division, its conference, and the league it plays in.
 *
 * Where a conference page scopes *downward* into what it contains, a team
 * page scopes *outward* into what contains it, and each step is still one
 * table with the team's own row in it. One level is no choice at all, so
 * college football — whose teams belong to a conference and nothing else —
 * offers none.
 */
export function scopesForTeamIn(ref: ConferenceRef): StandingsScope[] {
  if (leagueWideId(ref.league) === undefined) return [];
  const levels = new Set<StandingsScope>();
  for (const link of conferenceChain(ref)) {
    const scope = scopeAtTier(tier(link.id, link.league));
    if (scope) levels.add(scope);
  }
  if (levels.size <= 1) return [];
  // Widest first, the league page's order.
  return STANDINGS_SCOPES.filter((scope) => levels.has(scope));
}

function scopeAtTier(rung: ReturnType<typeof tier>): StandingsScope | undefined {
  switch (rung) {
    case "league":
      return "league";
    case "conference":
      return "conference";
    case "division":
      return "division";
    default:
      return undefined;
  }
}

/**
 * Where a page opens.
 *
 * A conference page opens at its own widest view of itself. A **team** page
 * opens on its conference's table, which is what the tab has always shown:
 * the league is one step out and the division one step in, so a team sits
 * in the middle of its own hierarchy with no widest-view-of-itself to
 * default to.
 */
export function defaultScope(
  scopes: readonly StandingsScope[],
  kind: "conference" | "team"
): StandingsScope | undefined {
  if (scopes.length === 0) return undefined;
  if (kind === "team") {
    return scopes.includes("conference") ? "conference" : scopes[0];
  }
  return scopes[0];
}

/**
 * Whether a scope is narrower than the page's own default — the chip's ink
 * rule.
 *
 * Scoping *out* from a team page reads as quiet as the default; only a
 * narrowed table wears the fill, so a table of 16 is never mistaken for a
 * table of 32.
 */
export function isNarrower(
  scope: StandingsScope,
  base: StandingsScope
): boolean {
  return STANDINGS_SCOPES.indexOf(scope) > STANDINGS_SCOPES.indexOf(base);
}
