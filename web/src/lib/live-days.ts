// The live poll's narrow ask — iOS `ScoreboardStore.liveDays` / `patching`
// (sports/Stores/ScoreboardStore.swift, 2026-09-26).
//
// A 1s poll that re-asks for the whole five-day window is five requests a
// second per league, four of them for days where nothing is happening, and
// every one a full slate. Between window refreshes, a tick asks only for the
// Eastern days that hold a game in play — one request on almost any night —
// and patches those games into the buckets by id.

import { keepingFavorites } from "@/lib/game-closeness";
import { isLiveStatus } from "@/lib/game-sections";
import { KICKOFF_GRACE_MS } from "@/lib/poll-schedule";
import type { Game } from "@/lib/types";

/**
 * How often a live poll re-asks for the whole window rather than just the
 * days in play. Kickoff times, a game added or dropped, a neighbouring
 * day's slate: none of it moves on a one-second clock.
 */
export const WINDOW_REFRESH_MS = 30_000;

/**
 * The most Eastern days one live ask may name. Games in play span one day,
 * two across midnight; past this the tick asks for the whole window
 * instead, and the route refuses more.
 */
export const MAX_LIVE_DAY_TOKENS = 3;

const easternDay = new Intl.DateTimeFormat("en-CA", {
  timeZone: "America/New_York",
  year: "numeric",
  month: "2-digit",
  day: "2-digit",
});

/**
 * ESPN's `dates=` token for the Eastern day a moment falls on: `20260925`.
 *
 * Eastern, and computed here rather than on the server, because that's the
 * day ESPN's token names, and the server's own day helpers read its host's
 * clock (UTC on Vercel). The five-day window's margin absorbs that; a
 * one-day ask has no margin to spend.
 */
export function easternDayToken(date: Date): string {
  return easternDay.format(date).replaceAll("-", "");
}

/**
 * One token per Eastern day that holds a game in play, or one past its
 * kickoff that ESPN hasn't flipped to live yet. Sorted; empty when nothing
 * is happening, which sends the tick back to the whole window.
 *
 * "Past kickoff" stops at the poll schedule's own grace
 * (`KICKOFF_GRACE_MS`): a cached game ESPN never flipped out of
 * `scheduled` would otherwise name its day on every tick, forever.
 */
export function liveDayTokens(games: readonly Game[], now: number): string[] {
  const tokens = new Set<string>();
  for (const game of games) {
    const time = Date.parse(game.scheduledAt);
    if (!Number.isFinite(time)) continue;
    const started =
      isLiveStatus(game.status) ||
      ((game.status === "scheduled" || game.status === "delayed") &&
        time <= now &&
        now - time < KICKOFF_GRACE_MS);
    if (started) tokens.add(easternDayToken(new Date(time)));
  }
  return [...tokens].sort();
}

/**
 * Held games replaced by their fresh copies, by id, keeping a favorite the
 * fresh copy dropped (`keepingFavorites`). Adds and removes nothing: a
 * partial answer can't say what isn't on a day, which is the window
 * refresh's job.
 */
export function patchGames(
  held: readonly Game[],
  fresh: ReadonlyMap<string, Game>
): Game[] {
  return held.map((old) => {
    const latest = fresh.get(old.id);
    if (latest === undefined) return old;
    return keepingFavorites([latest], [old])[0] ?? latest;
  });
}
