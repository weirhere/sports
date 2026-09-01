"use client";

import { useEffect, useRef, useState, useCallback } from "react";
import type { Game, GameStatus } from "@/lib/types";
import type { WeekSlot } from "@/lib/season";
import { getScoreboard } from "@/lib/api";
import { POLL_INTERVAL_LIVE } from "@/lib/constants";

// setTimeout's delay is a signed 32-bit int; anything larger fires
// immediately, which would turn a far-future kickoff into a busy loop.
const MAX_TIMEOUT_MS = 2 ** 31 - 1;

// A game whose kickoff has passed but which ESPN still calls "scheduled" is
// about to flip live (or is delayed). Recheck at the live cadence, but only
// inside this window — an abandoned fixture stops costing requests.
const DUE_KICKOFF_WINDOW_MS = 3 * 60 * 60 * 1000;

const LIVE_STATUSES: GameStatus[] = ["in_progress", "halftime", "end_period"];

function hasLiveGames(games: Game[]): boolean {
  return games.some((g) => LIVE_STATUSES.includes(g.status));
}

/**
 * Milliseconds until the next moment a scheduled game could go live, or
 * undefined when nothing on the slate can. Future kickoffs wake at kickoff;
 * a recently-due kickoff that hasn't flipped yet rechecks at the live
 * cadence.
 */
function delayUntilNextKickoff(games: Game[], now: number): number | undefined {
  let delay: number | undefined;
  for (const game of games) {
    if (game.status !== "scheduled" && game.status !== "delayed") continue;
    const kickoff = Date.parse(game.scheduledAt);
    if (!Number.isFinite(kickoff)) continue;
    const candidate =
      kickoff > now
        ? kickoff - now
        : now - kickoff < DUE_KICKOFF_WINDOW_MS
          ? POLL_INTERVAL_LIVE
          : undefined;
    if (candidate === undefined) continue;
    if (delay === undefined || candidate < delay) delay = candidate;
  }
  return delay;
}

/**
 * Polite-guest polling, mirroring the iOS `ScoreboardStore` discipline:
 * a 30s cadence ONLY while the document is visible AND at least one loaded
 * game is live. With nothing live there is no interval — just one timeout
 * to the earliest future kickoff, so a scheduled→live flip wakes polling.
 * Hidden tabs run no timers at all; becoming visible re-arms (and polls
 * immediately when games are live). Only the SELECTED week's games should
 * be passed in — the prefetch cache is never polled.
 */
export function useLiveScores(
  slot: WeekSlot | undefined,
  year: number | undefined,
  games: Game[],
  onUpdate: (games: Game[]) => void
) {
  const [visible, setVisible] = useState(true);

  useEffect(() => {
    function handleVisibility() {
      setVisible(document.visibilityState === "visible");
    }
    handleVisibility();
    document.addEventListener("visibilitychange", handleVisibility);
    return () =>
      document.removeEventListener("visibilitychange", handleVisibility);
  }, []);

  const onUpdateRef = useRef(onUpdate);
  useEffect(() => {
    onUpdateRef.current = onUpdate;
  });

  const poll = useCallback(async () => {
    if (slot === undefined) return;
    if (document.visibilityState !== "visible") return;
    try {
      const board = await getScoreboard(
        { value: slot.value, seasonType: slot.seasonType },
        year
      );
      onUpdateRef.current(board.games);
    } catch {
      // Silently fail; the next scheduled tick retries.
    }
  }, [slot, year]);

  useEffect(() => {
    if (!visible || slot === undefined) return;

    // Every poll result produces a new `games` array, so this effect re-runs
    // after each tick and schedules the next one — a chain, not an interval.
    const delay = hasLiveGames(games)
      ? POLL_INTERVAL_LIVE
      : delayUntilNextKickoff(games, Date.now());
    if (delay === undefined) return;

    const timer = setTimeout(poll, Math.min(delay, MAX_TIMEOUT_MS));
    return () => clearTimeout(timer);
  }, [visible, games, slot, poll]);

  // Coming back to a visible tab with live games shouldn't wait a full tick
  // for fresh scores.
  const wasVisibleRef = useRef(true);
  useEffect(() => {
    const cameBack = visible && !wasVisibleRef.current;
    wasVisibleRef.current = visible;
    if (cameBack && hasLiveGames(games)) {
      poll();
    }
    // `games` deliberately unlisted: this effect reacts to visibility edges
    // only, not data changes.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [visible, poll]);
}
