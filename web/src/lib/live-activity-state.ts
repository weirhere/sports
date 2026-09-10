/**
 * The Live Activity `content-state`, built server-side.
 *
 * This is the other half of a wire contract whose first half is Swift:
 * `GameActivityAttributes.ContentState` in `StatSideShared/`. ActivityKit
 * decodes what we send here directly into that struct, so the two files
 * have to agree key for key — a mismatch does not error anywhere visible,
 * it just silently fails to update a card on somebody's lock screen.
 *
 * Kept in step by hand, the same way `og-card.ts` is kept in step with
 * `GameShareCardView` (2026-09-09). The contract is small on purpose.
 */
import type { Game, GameStatus } from "@/lib/types";
import { gameState } from "@/lib/game-state";

/** Mirrors GameActivityAttributes.Phase. Raw values must match the Swift
 *  enum's, which are its case names. */
export type ActivityPhase = "pre" | "live" | "intermission" | "final";

export interface ActivityContentState {
  awayScore?: number;
  homeScore?: number;
  phase: ActivityPhase;
  headline: string;
  detail?: string;
  /** Epoch **seconds**. Pinned by CodingKeys on the Swift side rather than
   *  left to a default date strategy — Swift's default for `Date` is the
   *  2001 reference date, so an ISO string or a Unix epoch decoded against
   *  the wrong strategy fails the whole update. */
  asOf: number;
}

/**
 * Halftime and end-of-period are the reason the iOS client has `LivePhase`
 * at all: ESPN sends them as a live status with the clock parked at 0:00,
 * and a renderer that joins period + clock says "Q2 0:00" where every other
 * scores app says "Half". The same distinction has to be made here, or a
 * broadcast would write a card the client never would have.
 *
 * The web app's `GameStatus` names both outright, so this reads them rather
 * than sniffing the clock.
 */
export function activityPhase(status: GameStatus): ActivityPhase {
  if (status === "halftime" || status === "end_period") return "intermission";
  switch (gameState(status)) {
    case "pre":
      return "pre";
    case "live":
      return "live";
    default:
      // postponed / cancelled / delayed fold in with complete, exactly as
      // the client folds `.other` into `.final`: the job in all of them is
      // to stop claiming a clock is running.
      return "final";
  }
}

export interface HeadlineOptions {
  /** IANA zone for the kickoff string. The card is read on the device, but
   *  the string is built here, so the zone has to be chosen deliberately —
   *  the OG card made the same call and says so (2026-09-09). */
  timeZone?: string;
  now?: Date;
}

function kickoffHeadline(game: Game, options: HeadlineOptions): string {
  if (game.timeTBD) return "TBD";
  const date = new Date(game.scheduledAt);
  if (Number.isNaN(date.getTime())) return "TBD";
  return new Intl.DateTimeFormat("en-US", {
    weekday: "short",
    hour: "numeric",
    minute: "2-digit",
    timeZone: options.timeZone ?? "America/New_York",
  }).format(date);
}

/** "Q3", "P2" in hockey, "OT" past regulation — mirrors
 *  `GameStatus.periodLabel(_:in:)`. */
export function periodLabel(period: number, league: Game["league"]): string {
  const regulation = league === "nhl" ? 3 : 4;
  const short = league === "nhl" ? "P" : "Q";
  if (period <= regulation) return `${short}${period}`;
  if (period === regulation + 1) return "OT";
  return `${period - regulation}OT`;
}

export function contentState(game: Game, options: HeadlineOptions = {}): ActivityContentState {
  const now = options.now ?? new Date();
  const phase = activityPhase(game.status);
  const showsScores = phase !== "pre";
  // `?? undefined` rather than passing null through: the Swift side uses
  // `encodeIfPresent`, so an absent key is what "no score" looks like on
  // the wire. A literal null would decode as a present-but-null Int?, which
  // happens to work today and is not what the contract says.
  return {
    awayScore: showsScores ? (game.awayTeam.score ?? undefined) : undefined,
    homeScore: showsScores ? (game.homeTeam.score ?? undefined) : undefined,
    phase,
    headline: headline(game, phase, options),
    detail: detail(game, phase),
    asOf: Math.floor(now.getTime() / 1000),
  };
}

function headline(game: Game, phase: ActivityPhase, options: HeadlineOptions): string {
  switch (phase) {
    case "pre":
      return kickoffHeadline(game, options);
    case "intermission":
      // "Half" at the interval, "End Q1" at any other period boundary —
      // `GameStatus.liveStatusText`'s two intermission cases, mirrored.
      if (game.status === "halftime") return "Half";
      return game.quarter
        ? `End ${periodLabel(game.quarter, game.league)}`
        : "Half";
    case "live":
      return [game.quarter ? periodLabel(game.quarter, game.league) : null, game.clock]
        .filter(Boolean)
        .join(" ") || "Live";
    case "final":
      return "Final";
  }
}

function detail(game: Game, phase: ActivityPhase): string | undefined {
  switch (phase) {
    case "pre":
      return game.broadcast;
    case "live":
      // The situation line (down, distance, possession) comes off the
      // summary payload, which the poll loop does not fetch — so the
      // broadcast falls back to the network, exactly as the client does
      // when it has no summary either.
      return game.broadcast;
    default:
      return undefined;
  }
}
