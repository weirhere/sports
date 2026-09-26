// When the Scores slate asks ESPN again — a port of iOS
// `ScoreboardStore.nextPollDelay` (sports/Stores/ScoreboardStore.swift,
// 2026-09-25).
//
// The poll used to run only while a loaded game was already live, so a
// slate opened before kickoff never refetched: rows sat at their kickoff
// times until someone reloaded. Now a pre-game game keeps the poll alive
// from one tick before its kickoff to `KICKOFF_GRACE_MS` after it, and a
// later kickoff is a sleep until then — which makes no request.

import { isLiveStatus } from "./game-sections";
import type { Game } from "./types";

/**
 * How long past its kickoff a game still showing pre-game keeps the poll
 * alive. ESPN takes a minute or two to flip a game to `in`, and a weather
 * delay can hold one at pre-game for an hour or more; three hours covers
 * both. The cap is for the postponement ESPN never marks, which would
 * otherwise poll all night.
 */
export const KICKOFF_GRACE_MS = 3 * 60 * 60 * 1000;

/**
 * Milliseconds until the next scoreboard fetch is due, or null when nothing
 * on the slate needs one.
 *
 * A live game polls at `interval`. So does a pre-game game within `interval`
 * of kickoff or up to `KICKOFF_GRACE_MS` past it — the game is about to go
 * live, or already has and ESPN hasn't said so. A later kickoff is a sleep
 * until then. A `timeTBD` kickoff is a placeholder time, so it schedules
 * nothing.
 */
export function nextPollDelay(
  games: readonly Game[],
  now: number,
  interval: number
): number | null {
  if (games.some((game) => isLiveStatus(game.status))) return interval;
  const kickoffs: number[] = [];
  for (const game of games) {
    if (game.status !== "scheduled" || game.timeTBD) continue;
    const time = Date.parse(game.scheduledAt);
    if (Number.isFinite(time)) kickoffs.push(time);
  }
  if (
    kickoffs.some(
      (time) => time >= now - KICKOFF_GRACE_MS && time <= now + interval
    )
  ) {
    return interval;
  }
  const later = kickoffs.filter((time) => time > now);
  if (later.length === 0) return null;
  return Math.max(Math.min(...later) - now, interval);
}
