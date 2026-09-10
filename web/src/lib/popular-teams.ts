// The shortlist the Add teams sheet offers before anyone types — the web twin
// of iOS `PopularTeams`.
//
// **Curated, not measured, and deliberately so**: the app has no analytics
// and ESPN publishes no popularity figure, so there is nothing to derive this
// from. It is a hand-picked set of the programs and franchises with the
// largest national followings, in roughly that order — a starting point for
// someone who just installed the app, not a ranking claiming to be one.
// Search is one keystroke away for everyone else.
//
// Ids are ESPN team ids. An id the directory doesn't carry is silently
// skipped, so a realignment or a renamed franchise costs a row, never a
// crash — and the failure mode is an invisibly short sheet.

import { LEAGUES, type League } from "@/lib/leagues";
import type { ConferenceTeams, Team } from "@/lib/types";

const IDS: Record<League, string[]> = {
  cfb: [
    "194", // Ohio State
    "333", // Alabama
    "61", // Georgia
    "130", // Michigan
    "251", // Texas
    "87", // Notre Dame
    "213", // Penn State
    "99", // LSU
    "2483", // Oregon
    "30", // USC
    "201", // Oklahoma
    "228", // Clemson
    "57", // Florida
    "2633", // Tennessee
    "158", // Nebraska
  ],
  nfl: [
    "6", // Dallas Cowboys
    "12", // Kansas City Chiefs
    "21", // Philadelphia Eagles
    "25", // San Francisco 49ers
    "9", // Green Bay Packers
    "23", // Pittsburgh Steelers
    "17", // New England Patriots
    "2", // Buffalo Bills
    "33", // Baltimore Ravens
    "8", // Detroit Lions
  ],
  nba: [
    "13", // Los Angeles Lakers
    "2", // Boston Celtics
    "9", // Golden State Warriors
    "18", // New York Knicks
    "4", // Chicago Bulls
    "14", // Miami Heat
    "20", // Philadelphia 76ers
    "7", // Denver Nuggets
    "6", // Dallas Mavericks
    "21", // Phoenix Suns
  ],
  nhl: [
    "21", // Toronto Maple Leafs
    "13", // New York Rangers
    "1", // Boston Bruins
    "10", // Montreal Canadiens
    "4", // Chicago Blackhawks
    "5", // Detroit Red Wings
    "16", // Pittsburgh Penguins
    "6", // Edmonton Oilers
    "15", // Philadelphia Flyers
    "37", // Vegas Golden Knights
  ],
};

/**
 * The shortlist as one list, resolved against the loaded directory.
 *
 * **Interleaved rather than league after league** (iOS, 2026-09-06, when the
 * sheet dropped its league headings): a flat concatenation is a grouping
 * whether or not anything says so, and it would put every college program
 * above every franchise — fifteen cards of scrolling before an NFL fan sees a
 * team they recognise. Round-robin by position instead, so the top of the
 * sheet is every league's biggest names and each league keeps its own curated
 * order within the mix.
 *
 * A league whose teams haven't landed yet simply contributes nothing.
 */
export function popularTeams(conferences: ConferenceTeams[]): Team[] {
  const perLeague = LEAGUES.map((league) => {
    const byId = new Map<string, Team>();
    for (const conference of conferences) {
      if (conference.league !== league) continue;
      for (const team of conference.teams) {
        if (!byId.has(team.id)) byId.set(team.id, team);
      }
    }
    return (IDS[league] ?? [])
      .map((id) => byId.get(id))
      .filter((team): team is Team => team !== undefined);
  });

  // Proportional round-robin: each league is drawn from at a rate set by its
  // own length, so a 15-team list and a 10-team one finish together instead
  // of the shorter one running out a third of the way down.
  const longest = Math.max(0, ...perLeague.map((list) => list.length));
  if (longest === 0) return [];
  const merged: Team[] = [];
  for (let step = 0; step < longest; step += 1) {
    for (const list of perLeague) {
      if (list.length === 0) continue;
      const position = Math.floor((step * list.length) / longest);
      const previous =
        step === 0 ? -1 : Math.floor(((step - 1) * list.length) / longest);
      if (position !== previous) merged.push(list[position]);
    }
  }
  return merged;
}
