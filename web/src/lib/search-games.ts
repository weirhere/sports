// Games search past the loaded window — the platform-free half of iOS
// `TeamScheduleSearchStore` (sports/Stores/TeamScheduleSearchStore.swift,
// 2026-09-21): how the matched teams' schedules fold into the slate, and
// what order the result reads in.

import type { Game } from "./types";

/**
 * How many matched teams a query fetches schedules for.
 *
 * **Three, the iOS number — kept on purpose, for a different reason.** iOS
 * chose it as a phone's answer to "how many requests is a keystroke worth",
 * and the web's parity note invited reconsidering it: here each team is one
 * request to our own route, whose fetch cache is shared across every visitor
 * for an hour, so the request argument is weaker. The list-length argument
 * is not. Every team adds a whole season of rows — an NBA team is 82 — and
 * "New York" matches six teams across four leagues, so a higher cap buries
 * the next kickoff the list exists to answer under more seasons nobody
 * asked for. The caption says the scope out loud, so a six-team query
 * answered with three is labelled rather than silent.
 */
export const SCHEDULE_SEARCH_MAX_TEAMS = 3;

function gameKey(game: Pick<Game, "league" | "id">): string {
  // League-qualified: event ids are per league, like every other id here.
  return `${game.league}:${game.id}`;
}

/**
 * The slate's copy of a game wins over a schedule's (iOS `Game.union`).
 *
 * A schedule is fetched once and never polled, so its score is frozen at
 * fetch time — exactly how a conference page came to show a live game stuck
 * at halftime (2026-09-01). The loaded slate is polled, so its copy is the
 * one to trust whenever both have the game.
 *
 * Deduped on **both** sides: "new york" matches the Islanders and the
 * Rangers, and the game they play each other arrives in both schedules. Two
 * rows with one key is a React key collision, not a harmless duplicate.
 */
export function unionGames(
  schedule: readonly Game[],
  loaded: readonly Game[]
): Game[] {
  const seen = new Set<string>();
  const out: Game[] = [];
  for (const game of [...loaded, ...schedule]) {
    const key = gameKey(game);
    if (seen.has(key)) continue;
    seen.add(key);
    out.push(game);
  }
  return out;
}

/**
 * Next kickoff first, then forward; the most recent completed game above it
 * (iOS `Game.orderedAroundNow`).
 *
 * Not plain chronological. The question behind "when do they play next" is
 * answered by one game, and a season sorted by date buries it under three
 * months of finals. So: one past game for context, everything still to
 * come, then the rest of the past, newest first.
 *
 * A game with no parseable kickoff is dropped, as iOS drops a nil date —
 * it has no place on either side of now.
 */
export function orderedAroundNow(
  games: readonly Game[],
  now: Date = new Date()
): Game[] {
  const cutoff = now.getTime();
  const dated = games.flatMap((game) => {
    const time = Date.parse(game.scheduledAt);
    return Number.isNaN(time) ? [] : [{ game, time }];
  });
  const upcoming = dated
    .filter((entry) => entry.time >= cutoff)
    .sort((a, b) => a.time - b.time);
  const past = dated
    .filter((entry) => entry.time < cutoff)
    .sort((a, b) => b.time - a.time);
  return [...past.slice(0, 1), ...upcoming, ...past.slice(1)].map(
    (entry) => entry.game
  );
}
