"use client";

// One league's universe — every conference and its member teams — fetched
// once per page load and shared by Teams browse, onboarding, and app-wide
// search (the web twin of the iOS `TeamDirectoryStore`).
//
// The cache is keyed **per league**, not global: ESPN's conference group ids
// repeat across leagues (8 is the SEC and the AFC), so one shared bucket
// would hand the NFL college football's rosters.

import { useCallback, useEffect, useState } from "react";
import type { ConferenceTeams } from "@/lib/types";
import type { League } from "@/lib/leagues";

const cached = new Map<League, ConferenceTeams[]>();
const inflight = new Map<League, Promise<ConferenceTeams[]>>();

async function fetchDirectory(league: League): Promise<ConferenceTeams[]> {
  const res = await fetch(`/api/teams?league=${league}`);
  if (!res.ok) throw new Error(`Teams request failed: ${res.status}`);
  const data = (await res.json()) as { conferences?: ConferenceTeams[] };
  return data.conferences ?? [];
}

/**
 * One or more leagues' directories, merged.
 *
 * A list rather than a single league because the Scores slate spans all
 * four now: a rail scoped to college football would silently drop a
 * followed NFL team rather than name it. Each league is still fetched and
 * cached separately — a college-football-only follow set costs exactly one
 * request, as it always did.
 */
export function useTeamDirectory(leagues: League | readonly League[]): {
  conferences: ConferenceTeams[];
  isLoading: boolean;
  error: string | null;
  retry: () => void;
} {
  // A stable key so a fresh array literal per render doesn't re-fetch.
  const wanted = Array.isArray(leagues) ? leagues : [leagues as League];
  const key = wanted.join(",");

  const [conferences, setConferences] = useState<ConferenceTeams[]>(() =>
    wanted.every((l) => cached.has(l))
      ? wanted.flatMap((l) => cached.get(l) ?? [])
      : []
  );
  const [isLoading, setIsLoading] = useState(
    () => !wanted.every((l) => cached.has(l))
  );
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const list = key.length > 0 ? (key.split(",") as League[]) : [];
    if (list.every((l) => cached.has(l))) {
      setConferences(list.flatMap((l) => cached.get(l) ?? []));
      setIsLoading(false);
      return;
    }
    setIsLoading(true);
    setError(null);
    try {
      const results = await Promise.all(
        list.map(async (l) => {
          const hit = cached.get(l);
          if (hit !== undefined) return hit;
          // Concurrent consumers of the same league share one request.
          let pending = inflight.get(l);
          if (pending === undefined) {
            pending = fetchDirectory(l);
            inflight.set(l, pending);
          }
          try {
            const result = await pending;
            cached.set(l, result);
            return result;
          } finally {
            inflight.delete(l);
          }
        })
      );
      setConferences(results.flat());
    } catch {
      setError("Couldn't load teams.");
    } finally {
      setIsLoading(false);
    }
  }, [key]);

  useEffect(() => {
    void load();
  }, [load]);

  const retry = useCallback(() => {
    void load();
  }, [load]);

  return { conferences, isLoading, error, retry };
}
