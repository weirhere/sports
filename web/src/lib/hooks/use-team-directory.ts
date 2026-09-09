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

export function useTeamDirectory(league: League): {
  conferences: ConferenceTeams[];
  isLoading: boolean;
  error: string | null;
  retry: () => void;
} {
  const [conferences, setConferences] = useState<ConferenceTeams[]>(
    () => cached.get(league) ?? []
  );
  const [isLoading, setIsLoading] = useState(!cached.has(league));
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    const hit = cached.get(league);
    if (hit !== undefined) {
      setConferences(hit);
      setIsLoading(false);
      return;
    }
    setIsLoading(true);
    setError(null);
    try {
      // Concurrent consumers of the same league share one request.
      let pending = inflight.get(league);
      if (pending === undefined) {
        pending = fetchDirectory(league);
        inflight.set(league, pending);
      }
      const result = await pending;
      cached.set(league, result);
      setConferences(result);
    } catch {
      setError("Couldn't load teams.");
    } finally {
      inflight.delete(league);
      setIsLoading(false);
    }
  }, [league]);

  useEffect(() => {
    void load();
  }, [load]);

  const retry = useCallback(() => {
    void load();
  }, [load]);

  return { conferences, isLoading, error, retry };
}
