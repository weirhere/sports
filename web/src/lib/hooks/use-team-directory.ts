"use client";

// The FBS universe — every conference and its member teams — fetched once
// per page load and shared by Teams browse, onboarding, and app-wide search
// (the web twin of the iOS `TeamDirectoryStore`). The module-level cache
// means the second consumer mounts with data already in hand.

import { useCallback, useEffect, useState } from "react";
import type { ConferenceTeams } from "@/lib/types";

let cached: ConferenceTeams[] | null = null;
let inflight: Promise<ConferenceTeams[]> | null = null;

async function fetchDirectory(): Promise<ConferenceTeams[]> {
  const res = await fetch("/api/teams");
  if (!res.ok) throw new Error(`Teams request failed: ${res.status}`);
  const data = (await res.json()) as { conferences?: ConferenceTeams[] };
  return data.conferences ?? [];
}

export function useTeamDirectory(): {
  conferences: ConferenceTeams[];
  isLoading: boolean;
  error: string | null;
  retry: () => void;
} {
  const [conferences, setConferences] = useState<ConferenceTeams[]>(
    () => cached ?? []
  );
  const [isLoading, setIsLoading] = useState(cached === null);
  const [error, setError] = useState<string | null>(null);

  const load = useCallback(async () => {
    if (cached !== null) {
      setConferences(cached);
      setIsLoading(false);
      return;
    }
    setIsLoading(true);
    setError(null);
    try {
      // Concurrent consumers share one request.
      inflight ??= fetchDirectory();
      const result = await inflight;
      cached = result;
      setConferences(result);
    } catch {
      setError("Couldn't load teams.");
    } finally {
      inflight = null;
      setIsLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
  }, [load]);

  const retry = useCallback(() => {
    void load();
  }, [load]);

  return { conferences, isLoading, error, retry };
}
