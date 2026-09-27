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
  options?: { year?: number; tab?: "news" }
): string {
  const id = "teamId" in team ? team.teamId : team.id;
  const params = new URLSearchParams();
  if (options?.year !== undefined) params.set("year", String(options.year));
  if (options?.tab) params.set("tab", options.tab);
  const query = params.toString();
  return `/team/${team.league}/${id}${query ? `?${query}` : ""}`;
}

export function conferencePath(
  ref: ConferenceRef | { league: League; id: string | number },
  options?: { year?: number; team?: string; tab?: "news" }
): string {
  const params = new URLSearchParams();
  if (options?.year !== undefined) params.set("year", String(options.year));
  if (options?.team !== undefined) params.set("team", options.team);
  if (options?.tab) params.set("tab", options.tab);
  const query = params.toString();
  return `/conference/${ref.league}/${ref.id}${query ? `?${query}` : ""}`;
}

/** College football's league page, the Top 25, opened on a tab — a News
 *  page's "See more" (2026-09-27). */
export function pollPath(options?: { tab?: "news" }): string {
  return options?.tab ? `/rankings/poll?tab=${options.tab}` : "/rankings/poll";
}

/** Whether a page's `tab` query asks for News. */
export function opensNews(tab: string | string[] | undefined): boolean {
  return (Array.isArray(tab) ? tab[0] : tab) === "news";
}

/**
 * A story in the reader (iOS E25, docs/news.md N4). The league rides the URL
 * for the game and team ids inside the story, which collide across leagues;
 * the story id itself is ESPN's, and global.
 */
export function storyPath(story: { league: League; id: string }): string {
  return `/story/${story.league}/${story.id}`;
}
