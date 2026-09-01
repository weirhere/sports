// Status derivations for the game-detail header — the web port of the iOS
// `GameHeaderState` (sports/Features/Share/GameShareCard.swift) and the
// per-state status lines in GameDetailScreen. Pure functions so the header
// and the polling hook provably agree on what "live" means.

import type { Game, GameStatus } from "@/lib/types";
import { liveStatusText } from "@/lib/format";

export function isLiveStatus(status: GameStatus): boolean {
  return (
    status === "in_progress" ||
    status === "halftime" ||
    status === "end_period"
  );
}

/** Pre-game shows no scores — no 0–0, no dashes. Everything after does. */
export function showsScores(game: Game): boolean {
  return game.status !== "scheduled";
}

/** "Sat, Aug 29" — absolute weekday + date; the header never says "Today". */
export function kickoffDayText(scheduledAt: string): string {
  return new Date(scheduledAt).toLocaleDateString("en-US", {
    weekday: "short",
    month: "short",
    day: "numeric",
  });
}

/** "3:30 PM" in the viewer's timezone. */
export function kickoffTimeText(scheduledAt: string): string {
  return new Date(scheduledAt).toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
  });
}

/**
 * The header's status line — one string per state:
 * - pre: "Sat, Aug 29 · 3:30 PM" ("· TBD" for unannounced kickoffs)
 * - live: "Q3 5:24" / "Half" / "End Q1" via the shared live formatter
 * - final: ESPN's detail ("Final", "Final/OT") with "Final" as fallback
 * - postponed/cancelled/delayed: ESPN's detail, or a plain word
 */
export function statusLine(game: Game): string {
  switch (game.status) {
    case "scheduled": {
      const day = kickoffDayText(game.scheduledAt);
      return game.timeTBD
        ? `${day} · TBD`
        : `${day} · ${kickoffTimeText(game.scheduledAt)}`;
    }
    case "in_progress":
    case "halftime":
    case "end_period":
      return (
        liveStatusText({
          livePhase: game.livePhase,
          quarter: game.quarter,
          clock: game.clock,
          detail: game.statusDetail,
        }) ?? "Live"
      );
    case "complete":
      return game.statusDetail ?? "Final";
    case "postponed":
      return game.statusDetail ?? "Postponed";
    case "cancelled":
      return game.statusDetail ?? "Cancelled";
    case "delayed":
      return game.statusDetail ?? "Delayed";
  }
}

/**
 * The quiet second line under the status: the network pre-game and live
 * (the widget's pre+live rule), the kickoff date on finals — nothing left
 * to tune into, but "when was this" still earns its row.
 */
export function statusSubline(game: Game): string | undefined {
  if (game.status === "scheduled" || isLiveStatus(game.status)) {
    return game.broadcast;
  }
  if (game.status === "complete" && game.scheduledAt) {
    return kickoffDayText(game.scheduledAt);
  }
  return undefined;
}

/** "1ST QUARTER", "OVERTIME", "2OT" — the scoring/drive section markers. */
export function quarterMarkerLabel(period: number | undefined): string {
  if (period === undefined) return "—";
  switch (period) {
    case 1:
      return "1ST QUARTER";
    case 2:
      return "2ND QUARTER";
    case 3:
      return "3RD QUARTER";
    case 4:
      return "4TH QUARTER";
    case 5:
      return "OVERTIME";
    default:
      return `${period - 4}OT`;
  }
}
