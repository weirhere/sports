"use client";

import { useEffect, useState } from "react";
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

/**
 * A pre-game summary never demotes a live snapshot — kickoff doesn't
 * un-happen. That shape is a stale or flaky payload (seen from ESPN
 * mid-Saturday), and honoring it would demote the header to pre AND stop
 * the poll loop with nothing left to refetch, freezing the page mid-drive.
 * The live snapshot's status and scores win; the next poll's summary takes
 * over again. Final/postponed always win — those are real transitions.
 * (The web port of iOS `GameHeaderState.status`.)
 */
export function mergeLiveSnapshot(
  prev: GameDetail,
  incoming: GameDetail
): GameDetail {
  if (incoming.game.status !== "scheduled" || !isLiveStatus(prev.game.status)) {
    return incoming;
  }
  return {
    ...incoming,
    game: {
      ...incoming.game,
      status: prev.game.status,
      clock: prev.game.clock,
      quarter: prev.game.quarter,
      livePhase: prev.game.livePhase,
      statusDetail: prev.game.statusDetail,
      possession: prev.game.possession,
      homeTeam: {
        ...incoming.game.homeTeam,
        score: prev.game.homeTeam.score,
        linescores: prev.game.homeTeam.linescores,
      },
      awayTeam: {
        ...incoming.game.awayTeam,
        score: prev.game.awayTeam.score,
        linescores: prev.game.awayTeam.linescores,
      },
    },
  };
}

/**
 * 30s polling, only while the game is live AND the tab is visible —
 * mirroring the iOS detail screen's scene-active poll loop. A summary that
 * comes back final stops the loop on its own; returning to a visible tab
 * polls immediately instead of waiting out the interval.
 */
export function useLiveGame(gameId: string, initialData: GameDetail) {
  const [data, setData] = useState(initialData);
  const live = isLiveStatus(data.game.status);

  useEffect(() => {
    if (!live) return;
    let cancelled = false;

    async function poll() {
      if (document.hidden) return;
      try {
        const incoming = await getGameDetail(gameId);
        if (!cancelled) {
          setData((prev) => mergeLiveSnapshot(prev, incoming));
        }
      } catch {
        // A missed poll stays quiet; the next tick retries.
      }
    }

    const timer = setInterval(poll, POLL_INTERVAL_LIVE);
    function handleVisibility() {
      if (!document.hidden) void poll();
    }
    document.addEventListener("visibilitychange", handleVisibility);

    return () => {
      cancelled = true;
      clearInterval(timer);
      document.removeEventListener("visibilitychange", handleVisibility);
    };
  }, [gameId, live]);

  return data;
}
