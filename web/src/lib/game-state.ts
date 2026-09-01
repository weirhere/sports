// The four render states every game surface branches on — the web twin of
// the iOS `GameStatus` enum's pre/live/final/other cases. Domain
// `GameStatus` strings are finer-grained (halftime and end_period are live;
// postponed/cancelled/delayed are "other" with a detail line).

import type { Game, GameStatus } from "@/lib/types";

export type GameState = "pre" | "live" | "final" | "other";

export function gameState(status: GameStatus): GameState {
  switch (status) {
    case "scheduled":
      return "pre";
    case "in_progress":
    case "halftime":
    case "end_period":
      return "live";
    case "complete":
      return "final";
    case "postponed":
    case "cancelled":
    case "delayed":
      return "other";
  }
}

/** The degrade line for postponed/cancelled/delayed games. */
export function otherStatusText(game: Game): string {
  if (game.statusDetail) return game.statusDetail;
  switch (game.status) {
    case "postponed":
      return "Postponed";
    case "cancelled":
      return "Cancelled";
    case "delayed":
      return "Delayed";
    default:
      return "—";
  }
}
