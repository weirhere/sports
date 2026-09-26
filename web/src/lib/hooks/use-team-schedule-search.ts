"use client";

// The games a search finds beyond the days already loaded — iOS
// `TeamScheduleSearchStore` (sports/Stores/TeamScheduleSearchStore.swift,
// 2026-09-21).
//
// Search's game corpus is the slate the page fetched on mount: yesterday
// through five days out. A team that played yesterday showed that final and
// nothing of next week, because nothing had asked for next week. ESPN's
// search endpoint can't fill it — it returns broadcast listings, not
// scoreboard events (probed live 2026-09-21) — but `/teams/{id}/schedule`
// returns a whole season in one request.
//
// **Driven by the matched teams rather than the raw string**, so a request
// only follows a search that already found something. Same 300ms clock as
// the athlete search, so a query costs at most one round however fast it is
// typed.

import { useEffect, useMemo, useState } from "react";
import type { Game, Team } from "@/lib/types";
import { followKey } from "@/lib/refs";
import { SCHEDULE_SEARCH_MAX_TEAMS } from "@/lib/search-games";
import { SEARCH_DEBOUNCE_MS } from "./use-athlete-search";

/**
 * Keyed by team, for the life of the page. A schedule is a season and does
 * not churn; the route's own hour-long cache sits behind this one.
 */
const cache = new Map<string, Game[]>();

async function loadSchedule(team: Team, signal: AbortSignal): Promise<Game[]> {
  const key = followKey({ league: team.league, teamId: team.id });
  const hit = cache.get(key);
  if (hit) return hit;
  const res = await fetch(
    `/api/team/${team.id}/schedule?league=${team.league}`,
    { signal }
  );
  // One team's miss costs its own games, not the section.
  if (!res.ok) return [];
  const data = (await res.json()) as { games?: Game[] };
  const games = data.games ?? [];
  cache.set(key, games);
  return games;
}

interface Settled {
  key: string;
  games: Game[];
}

/** Pass whatever teams the query matched, best first. */
export function useTeamScheduleSearch(teams: readonly Team[]): Game[] {
  const wanted = useMemo(
    () => teams.slice(0, SCHEDULE_SEARCH_MAX_TEAMS),
    [teams]
  );
  const key = wanted
    .map((team) => followKey({ league: team.league, teamId: team.id }))
    .join(",");
  const [settled, setSettled] = useState<Settled>({ key: "", games: [] });

  useEffect(() => {
    if (key.length === 0) return;
    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      Promise.all(
        wanted.map((team) =>
          loadSchedule(team, controller.signal).catch(() => [] as Game[])
        )
      ).then((schedules) => {
        if (controller.signal.aborted) return;
        setSettled({ key, games: schedules.flat() });
      });
    }, SEARCH_DEBOUNCE_MS);
    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
    // `wanted` is fully described by `key`; depending on the array would
    // refetch on every render that rebuilds an equal list.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [key]);

  // Only the schedules of the teams matched *now*. iOS holds the previous
  // set until the next lands; here a narrowed query ("georgia" → "georgia
  // tech") would briefly list the other Georgia's games under a caption
  // that says they match, so the section waits instead.
  return settled.key === key ? settled.games : [];
}
