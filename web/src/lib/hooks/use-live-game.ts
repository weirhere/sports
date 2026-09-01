"use client";

import { useState, useEffect, useRef, useCallback } from "react";
import type { GameDetail, GameStatus } from "@/lib/types";
import { getGameDetail } from "@/lib/api";
import { POLL_INTERVAL_LIVE } from "@/lib/constants";

function isLiveStatus(status: GameStatus): boolean {
  return (
    status === "in_progress" ||
    status === "halftime" ||
    status === "end_period"
  );
}

export function useLiveGame(gameId: string, initialData: GameDetail) {
  const [data, setData] = useState(initialData);
  const timerRef = useRef<ReturnType<typeof setTimeout> | null>(null);
  const visibleRef = useRef(true);

  // poll only fetches and updates state — no self-rescheduling
  const poll = useCallback(async () => {
    if (!visibleRef.current) return;

    try {
      const updated = await getGameDetail(gameId);
      setData(updated);
    } catch {
      // Silently fail
    }
  }, [gameId]);

  // useEffect is the single owner of the timer lifecycle
  useEffect(() => {
    if (!isLiveStatus(data.game.status)) return;

    timerRef.current = setTimeout(poll, POLL_INTERVAL_LIVE);

    return () => {
      if (timerRef.current) {
        clearTimeout(timerRef.current);
        timerRef.current = null;
      }
    };
  }, [poll, data.game.status]);

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

  return data;
}
