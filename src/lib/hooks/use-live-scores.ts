"use client";

import { useEffect, useRef, useCallback } from "react";
import type { Game, GameStatus } from "@/lib/types";
import { getSchedule } from "@/lib/api";
import { POLL_INTERVAL_LIVE, POLL_INTERVAL_IDLE } from "@/lib/constants";

function hasLiveGames(games: Game[]): boolean {
  const liveStatuses: GameStatus[] = ["in_progress", "halftime", "end_period"];
  return games.some((g) => liveStatuses.includes(g.status));
}

export function useLiveScores(
  week: number,
  year: number,
  games: Game[],
  onUpdate: (games: Game[]) => void
) {
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const visibleRef = useRef(true);

  // poll only fetches and calls onUpdate — no self-rescheduling
  const poll = useCallback(async () => {
    if (!visibleRef.current) return;

    try {
      const data = await getSchedule(week, year);
      onUpdate(data.games);
    } catch {
      // Silently fail, will retry on next interval
    }
  }, [week, year, onUpdate]);

  // useEffect is the single owner of the timer lifecycle
  useEffect(() => {
    const shouldPoll = games.some(
      (g) =>
        g.status === "in_progress" ||
        g.status === "halftime" ||
        g.status === "end_period" ||
        g.status === "scheduled"
    );

    if (!shouldPoll) return;

    const interval = hasLiveGames(games)
      ? POLL_INTERVAL_LIVE
      : POLL_INTERVAL_IDLE;

    timerRef.current = setTimeout(poll, interval);

    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
    };
  }, [poll, games]);

  // Pause polling when tab is hidden
  useEffect(() => {
    function handleVisibility() {
      visibleRef.current = !document.hidden;
      if (!document.hidden && timerRef.current === null) {
        poll();
      }
    }

    document.addEventListener("visibilitychange", handleVisibility);
    return () => {
      document.removeEventListener("visibilitychange", handleVisibility);
    };
  }, [poll]);
}
