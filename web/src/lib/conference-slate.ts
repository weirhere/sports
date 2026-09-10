// How a Games tab groups its slate, narrows it, and decides where it opens
// — the web twin of iOS `ConferenceSlate` (Features/Conference/SlateFilters.swift
// and ConferenceGamesList.swift). Pure, so the cards' shape is testable
// without a component in sight.
//
// Week and date are the two ways a season reads, and they're a *view*
// choice, not a filter: every game is in the list either way, under one
// heading or the other (iOS, 2026-09-05 — "Weeks" and "Date" are toggles,
// "Team" is the dropdown). The team pick is the narrowing one, and an
// undefined selection there is the absence of a filter, never a value
// callers have to special-case.

import type { Game } from "@/lib/types";
import type { League } from "@/lib/leagues";
import { dayId } from "@/lib/day";

/** What the cards are headed by. */
export type SlateGrouping =
  /** "Week 1", the postseason last — a football season's own clock. */
  | "week"
  /** "Saturday, September 5" — the way a fan says which games. */
  | "day"
  /** One card, chronological: both toggles off, so nothing heads it. */
  | "none";

export interface SlateGroup {
  id: string;
  /** Empty on the ungrouped card — nothing is being grouped, so nothing
   *  labels it. */
  title: string;
  games: Game[];
}

/** A result holds its slot for the day it was played in; six hours of grace
 *  outlast any game that runs past midnight. */
const OVERNIGHT_GRACE_MS = 6 * 60 * 60 * 1000;

function kickoff(game: Game): Date | undefined {
  const parsed = Date.parse(game.scheduledAt);
  return Number.isNaN(parsed) ? undefined : new Date(parsed);
}

function chronological(games: Game[]): Game[] {
  return [...games].sort((a, b) => {
    const at = kickoff(a)?.getTime() ?? Number.POSITIVE_INFINITY;
    const bt = kickoff(b)?.getTime() ?? Number.POSITIVE_INFINITY;
    return at - bt;
  });
}

/**
 * Which card a game files under by week: its preseason week, its
 * regular-season week, the postseason (whose week numbers restart and must
 * never land a title game in "Week 1"), or the dateless bucket.
 *
 * The preseason's numbers restart the same way, so it gets a namespace of
 * its own rather than sharing the regular season's — which is what had the
 * NFL's Hall of Fame Game and its opening Thursday on one card headed
 * "Week 1" (iOS, 2026-09-06).
 */
export function slateWeekId(game: Game): string {
  if (game.seasonType === 3) return "week-postseason";
  if (game.seasonType === 1) {
    return game.week !== undefined ? `preseason-${game.week}` : "preseason-other";
  }
  return game.week !== undefined ? `week-${game.week}` : "week-other";
}

/**
 * What a preseason card is headed by.
 *
 * ESPN numbers the preseason from the Hall of Fame Game: that game is week
 * 1 and the three preseason weekends are 2, 3 and 4, which is why the label
 * is the week number minus its opener. A league that numbers its preseason
 * from 1 keeps its own numbers — only the NFL plays a Hall of Fame Game.
 */
export function preseasonTitle(
  week: number | undefined,
  league: League
): string {
  if (week === undefined) return "Preseason";
  if (league !== "nfl") return `Preseason Week ${week}`;
  return week <= 1 ? "Hall of Fame Game" : `Preseason Week ${week - 1}`;
}

/**
 * "Saturday, September 5" — and "Saturday, September 5, 2019" once the date
 * is in a different year from the one we're standing in.
 *
 * A weekday and a date are enough while the year is obvious. On a past
 * season it isn't: the whole point of the pane is that these games are not
 * from now, and a card headed "Thursday, October 2" says nothing about
 * which October.
 */
export function slateDayTitle(date: Date, now: Date = new Date()): string {
  return date.toLocaleDateString("en-US", {
    weekday: "long",
    month: "long",
    day: "numeric",
    ...(date.getFullYear() !== now.getFullYear() ? { year: "numeric" } : {}),
  });
}

/**
 * The preseason first, then regular-season weeks ascending, then a dateless
 * bucket, then the postseason. Games sort chronologically within a card.
 */
export function slateWeekGroups(games: Game[]): SlateGroup[] {
  const sorted = chronological(games);
  const preseason = new Map<number, Game[]>();
  const preseasonUndated: Game[] = [];
  const regular = new Map<number, Game[]>();
  const postseason: Game[] = [];
  const undated: Game[] = [];

  for (const game of sorted) {
    if (game.seasonType === 3) {
      postseason.push(game);
    } else if (game.seasonType === 1) {
      if (game.week !== undefined) push(preseason, game.week, game);
      else preseasonUndated.push(game);
    } else if (game.week !== undefined && game.week >= 1) {
      push(regular, game.week, game);
    } else {
      // A league with no weeks at all (the NBA and NHL ship `week: null` on
      // every event) files its whole slate here rather than under a Week 1
      // that doesn't exist.
      undated.push(game);
    }
  }

  const groups: SlateGroup[] = [];
  for (const week of [...preseason.keys()].sort((a, b) => a - b)) {
    const weekGames = preseason.get(week) ?? [];
    groups.push({
      id: `preseason-${week}`,
      title: preseasonTitle(week, leagueOf(weekGames)),
      games: weekGames,
    });
  }
  if (preseasonUndated.length > 0) {
    groups.push({
      id: "preseason-other",
      title: "Preseason",
      games: preseasonUndated,
    });
  }
  for (const week of [...regular.keys()].sort((a, b) => a - b)) {
    groups.push({
      id: `week-${week}`,
      title: `Week ${week}`,
      games: regular.get(week) ?? [],
    });
  }
  if (undated.length > 0) {
    groups.push({ id: "week-other", title: "More games", games: undated });
  }
  if (postseason.length > 0) {
    groups.push({ id: "week-postseason", title: "Postseason", games: postseason });
  }
  return groups;
}

/**
 * One card per day the slate touches, chronological. Undated games (a TBD
 * bowl slot) get a bucket of their own at the end rather than a day they
 * aren't on.
 */
export function slateDayGroups(
  games: Game[],
  now: Date = new Date()
): SlateGroup[] {
  const byDay = new Map<string, Game[]>();
  const undated: Game[] = [];
  for (const game of chronological(games)) {
    const date = kickoff(game);
    if (!date) {
      undated.push(game);
      continue;
    }
    push(byDay, dayId(date), game);
  }
  const groups: SlateGroup[] = [];
  for (const [id, dayGames] of byDay) {
    const date = kickoff(dayGames[0]);
    if (!date) continue;
    groups.push({
      id: `day-${id}`,
      title: slateDayTitle(date, now),
      games: dayGames,
    });
  }
  if (undated.length > 0) {
    groups.push({ id: "day-tbd", title: "Date TBA", games: undated });
  }
  return groups;
}

/** The whole slate as one chronological card, unheaded. */
export function slateFlatGroup(games: Game[]): SlateGroup[] {
  const sorted = chronological(games);
  return sorted.length === 0 ? [] : [{ id: "all", title: "", games: sorted }];
}

export function slateGroups(
  games: Game[],
  grouping: SlateGrouping,
  now: Date = new Date()
): SlateGroup[] {
  switch (grouping) {
    case "week":
      return slateWeekGroups(games);
    case "day":
      return slateDayGroups(games, now);
    case "none":
      return slateFlatGroup(games);
  }
}

/**
 * The slate narrowed to one team's games, home or away. An undefined id is
 * the whole slate — "All teams" is the absence of a filter, not a value the
 * caller has to special-case.
 */
export function gamesForTeam(games: Game[], teamId?: string): Game[] {
  if (!teamId) return games;
  return games.filter(
    (game) =>
      game.homeTeam.team.id === teamId || game.awayTeam.team.id === teamId
  );
}

/**
 * Whether a game has stopped being the one to look at. A result is worth a
 * slot for the day it was played in, and once tomorrow arrives the question
 * becomes when they play next.
 *
 * The rule is the iOS widget's `GameSelection.isSpent`, borrowed whole: six
 * hours of grace past midnight, so a game that finishes at 12:40am doesn't
 * vanish on the whistle; live games are exempt, because no clock heuristic
 * should be able to suppress a live score; and a game ESPN never dated is
 * never spent, so a TBD bowl slot can't fold away on a guess.
 */
export function isGameSpent(game: Game, now: Date = new Date()): boolean {
  if (game.status === "in_progress" || game.status === "halftime" ||
      game.status === "end_period") {
    return false;
  }
  const start = kickoff(game);
  if (!start) return false;
  if (
    start.getFullYear() === now.getFullYear() &&
    start.getMonth() === now.getMonth() &&
    start.getDate() === now.getDate()
  ) {
    return false;
  }
  return now.getTime() >= start.getTime() + OVERNIGHT_GRACE_MS;
}

/** A card with nothing live in it and nothing left to kick off. */
export function isGroupSpent(group: SlateGroup, now: Date = new Date()): boolean {
  return group.games.every((game) => isGameSpent(game, now));
}

export interface SlateFold {
  /** The spent cards, oldest first — everything before the split. */
  earlier: SlateGroup[];
  /** The card the season is on, and everything after it. */
  upcoming: SlateGroup[];
}

/**
 * Splits the cards at the first one that isn't spent, so a Games tab opens
 * on the card holding the next game rather than on Week 1 (iOS, 2026-09-08).
 *
 * Deliberately *not* a scroll: scrolling the pane to the current week takes
 * the hero and the page's identity off screen with it. Folding leaves the
 * page at its true top, full header and all, and the season's history one
 * tap up rather than one scroll up.
 *
 * A **prefix**, never a scan: a card that reads as spent in the middle of a
 * live season (a postponed game rescheduled forward leaves its old week
 * short) stays exactly where the calendar put it. The fold can only ever
 * hide a run of cards off the front, which is the one thing it can do
 * without rearranging a season.
 *
 * A season with nothing left — every past season, and this one from the
 * last whistle to next July — folds nothing at all. There is no "next game"
 * to open on, and a page whose whole slate hid behind a row would be
 * answering a question nobody asked.
 */
export function foldSlate(
  groups: SlateGroup[],
  now: Date = new Date()
): SlateFold {
  const split = groups.findIndex((group) => !isGroupSpent(group, now));
  if (split <= 0) return { earlier: [], upcoming: groups };
  return { earlier: groups.slice(0, split), upcoming: groups.slice(split) };
}

/** Whose preseason a card belongs to. Read off the games themselves — a
 *  conference page's slate is one league's by construction. */
function leagueOf(games: Game[]): League {
  return games[0]?.league ?? "cfb";
}

function push<K>(map: Map<K, Game[]>, key: K, game: Game): void {
  const bucket = map.get(key);
  if (bucket) bucket.push(game);
  else map.set(key, [game]);
}
