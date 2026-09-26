// Which live games are worth switching to — the Scores page's **Tight**
// filter. A straight port of iOS `GameCloseness`
// (StatSideShared/Models/GameCloseness.swift, Coard Miller 2026-09-24): "if
// it's an upset or a closer game than the spread suggests."
//
// A game is tight when it's live and either:
//
//   1. it's **late and within one score** (football's 4th quarter within 8,
//      basketball's 4th within 6, hockey's 3rd within a goal, overtime always
//      counting as late), or
//   2. **the underdog is leading** in the second half, which needs the
//      pre-game line's favorite. A game with no line still qualifies by the
//      first rule; the second just can't speak for it.
//
// The line is used and never printed, so this works on a web that shows no
// lines on its rows at all. It is a scores question that happens to know the
// favorite.

import { isLiveStatus } from "./game-sections";
import type { League } from "./leagues";
import type { Game } from "./types";

interface ClosenessRule {
  /** The period where a game is late: the last regulation one, and every
   *  overtime after it. */
  latePeriod: number;
  /** The period the second half starts in. Hockey has no half, so its
   *  middle period stands in: the underdog still up after two is news. */
  secondHalfPeriod: number;
  /** One score: a touchdown and two-point conversion, two basketball
   *  possessions (a three and a two, give or take), a single goal. */
  oneScore: number;
}

/** The per-league table — iOS `League.latePeriod`, `secondHalfPeriod` and
 *  `oneScore`, copied as they stand. */
export const CLOSENESS_RULES: Record<League, ClosenessRule> = {
  cfb: { latePeriod: 4, secondHalfPeriod: 3, oneScore: 8 },
  nfl: { latePeriod: 4, secondHalfPeriod: 3, oneScore: 8 },
  nba: { latePeriod: 4, secondHalfPeriod: 3, oneScore: 6 },
  nhl: { latePeriod: 3, secondHalfPeriod: 2, oneScore: 1 },
};

export function isTight(game: Game): boolean {
  if (!isLiveStatus(game.status)) return false;
  const period = game.quarter;
  const home = game.homeTeam.score;
  const away = game.awayTeam.score;
  if (period === undefined || home === null || away === null) return false;

  const rule = CLOSENESS_RULES[game.league];
  if (period >= rule.latePeriod && Math.abs(home - away) <= rule.oneScore) {
    return true;
  }

  // Halftime is the second half's doorstep, and an underdog leading into it
  // is exactly the game the filter is for.
  const secondHalf =
    period >= rule.secondHalfPeriod ||
    (game.status === "halftime" && rule.secondHalfPeriod === period + 1);
  if (!secondHalf || home === away || game.favoriteIsHome === undefined) {
    return false;
  }
  return home > away !== game.favoriteIsHome;
}

/**
 * A game's pre-game favorite, carried past the payload that drops it — iOS
 * `ScoreboardStore.keepingLines`.
 *
 * ESPN takes `odds` off a scoreboard event once it's final, and maybe
 * sooner. A favorite doesn't un-happen at kickoff, and the Tight filter
 * needs to know who it was while the game is being played. So a fresh game
 * without one keeps the one it had. In memory only: a reload mid-game loses
 * it, and the late-and-close rule doesn't need it anyway.
 */
export function keepingFavorites(
  fresh: readonly Game[],
  previous: readonly Game[]
): Game[] {
  const known = new Map<string, boolean>();
  for (const game of previous) {
    if (game.favoriteIsHome !== undefined && !known.has(game.id)) {
      known.set(game.id, game.favoriteIsHome);
    }
  }
  if (known.size === 0) return [...fresh];
  return fresh.map((game) => {
    if (game.favoriteIsHome !== undefined) return game;
    const favoriteIsHome = known.get(game.id);
    return favoriteIsHome === undefined ? game : { ...game, favoriteIsHome };
  });
}
