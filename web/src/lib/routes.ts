// Every internal entity URL, built in one place.
//
// The app's routes are league-qualified — `/game/nfl/401`, `/team/cfb/130`,
// `/conference/nba/5` — because ESPN's id spaces collide across leagues:
// event, team and group ids all repeat, so a bare-id URL names two things.
// Searching "Browns" opened UAB on iOS for exactly this reason; both are id
// 5, and the directory publishes college football first.
//
// Bare-id URLs published before the axis still resolve: `next.config.ts`
// redirects them to college football's, which is what every one of them
// meant.

import type { League } from "./leagues";
import type { ConferenceRef, TeamRef } from "./refs";

export function gamePath(game: { league: League; id: string }): string {
  return `/game/${game.league}/${game.id}`;
}

export function teamPath(
  team: TeamRef | { league: League; id: string },
  options?: { year?: number }
): string {
  const id = "teamId" in team ? team.teamId : team.id;
  const query = options?.year !== undefined ? `?year=${options.year}` : "";
  return `/team/${team.league}/${id}${query}`;
}

export function conferencePath(
  ref: ConferenceRef | { league: League; id: string | number },
  options?: { year?: number; team?: string }
): string {
  const params = new URLSearchParams();
  if (options?.year !== undefined) params.set("year", String(options.year));
  if (options?.team !== undefined) params.set("team", options.team);
  const query = params.toString();
  return `/conference/${ref.league}/${ref.id}${query ? `?${query}` : ""}`;
}
