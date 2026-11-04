// The game page's Standings tab — a port of iOS `GameStandingsModel`
// (sports/Features/GameDetail/GameStandingsModel.swift, 2026-10-24).
//
// Every table either side of a matchup sits in, at one scope: the league's
// one table, or each side's conference or division — away's first, the
// header's order, and a shared table once. Tables are found by
// **membership**, not by the teams' `conferenceId`: the table that lists a
// team is the one it is in, whatever the scoreboard did or didn't send.

import { hasDivisions, leagueWideId } from "./conferences";
import type { League } from "./leagues";
import type { StandingsScope } from "./standings-scope";
import { isLeagueWide, tablesAtScope } from "./standings-tables";
import type { ConferenceStandingsGroup } from "./types";

/**
 * The scopes a matchup's tab offers — the team page's rule, by league. The
 * NFL, NBA, NHL and MLB nest conferences and their divisions under one
 * league table, so all three; the WNBA has conferences alone, so League
 * and Conference; college football and basketball keep no league-wide
 * table, so none, and the chip hides.
 */
export function gameStandingsScopes(league: League): StandingsScope[] {
  if (leagueWideId(league) === undefined) return [];
  return hasDivisions(league)
    ? ["league", "conference", "division"]
    : ["league", "conference"];
}

/** The tables a matchup shows at a scope (undefined where the league has none). */
export function gameStandingsTables(
  groups: readonly ConferenceStandingsGroup[],
  league: League,
  awayId: string,
  homeId: string,
  scope: StandingsScope | undefined
): ConferenceStandingsGroup[] {
  const wide = leagueWideId(league);
  let pool: ConferenceStandingsGroup[];
  if (wide === undefined || scope === undefined) {
    // College: a conference's own table beats one of its divisions where a
    // response carries both, so the tab never quietly shows a division.
    const own = groups.filter((group) => group.league === league);
    pool = [
      ...own.filter((group) => group.parentId === undefined),
      ...own.filter((group) => group.parentId !== undefined),
    ];
  } else {
    const anchor = { league, id: wide };
    if (scope === "league") return tablesAtScope(groups, anchor, "league");
    pool = tablesAtScope(groups, anchor, scope).filter(
      (table) => !isLeagueWide(table)
    );
  }
  const shown: ConferenceStandingsGroup[] = [];
  for (const id of [awayId, homeId]) {
    if (id === "") continue;
    const table = pool.find((group) =>
      group.entries.some((entry) => entry.team.id === id)
    );
    if (table && !shown.includes(table)) shown.push(table);
  }
  return shown;
}
