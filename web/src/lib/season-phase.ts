// Which part of the season a game belongs to — the team page's card split
// (iOS `SeasonPhase`, Features/Teams/TeamScheduleSection.swift).
//
// ESPN's own 1/2/3, named. A game with no season type at all counts as
// regular season: that is where those games have always been shown, and
// guessing anything else would move them for no reason.

import type { Game } from "@/lib/types";

export type SeasonPhase = "preseason" | "regular" | "postseason";

/** Season order, which is also the order the cards stack in. */
const PHASES: SeasonPhase[] = ["preseason", "regular", "postseason"];

/**
 * The card's header. "Regular Season" rather than "Schedule" (iOS,
 * 2026-09-06) — once the preseason has a card of its own, the old name no
 * longer says which games are in this one, and calling a card holding bowl
 * games "Regular Season" would be a new lie.
 */
export function seasonPhaseTitle(phase: SeasonPhase): string {
  switch (phase) {
    case "preseason":
      return "Preseason";
    case "regular":
      return "Regular Season";
    case "postseason":
      return "Postseason";
  }
}

export function seasonPhaseOf(game: Game): SeasonPhase {
  switch (game.seasonType) {
    case 1:
      return "preseason";
    case 3:
      return "postseason";
    default:
      return "regular";
  }
}

/**
 * A team's games split by phase, in season order, dropping any phase it has
 * no games in — a college team with neither a preseason nor a bowl still
 * shows exactly one card, the way it always did.
 *
 * Splitting is what keeps exhibition football from reading as games that
 * counted.
 */
export function bySeasonPhase(
  games: Game[]
): { phase: SeasonPhase; games: Game[] }[] {
  return PHASES.flatMap((phase) => {
    const inPhase = games.filter((game) => seasonPhaseOf(game) === phase);
    return inPhase.length > 0 ? [{ phase, games: inPhase }] : [];
  });
}
