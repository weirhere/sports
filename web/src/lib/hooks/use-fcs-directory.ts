"use client";

// College football's FCS conferences and their teams — what search's athlete
// filter needs beside the FBS directory `useTeamDirectory` loads.
//
// iOS's directory is division-complete for the sport (FBS and FCS), and its
// athlete filter asks that directory which clubs are real pages: Harvard
// stays, Mars Hill (Division II) goes. The web's shared directory is FBS
// only, because every browse surface that reads it lists FBS only — so
// search asks for FCS on its own rather than widening every consumer's list.
// Fetched once per page load and shared, like the directory it complements.

import { useEffect, useState } from "react";
import type { ConferenceTeams } from "@/lib/types";

let cached: ConferenceTeams[] | undefined;
let inflight: Promise<ConferenceTeams[]> | undefined;

async function fetchFcs(): Promise<ConferenceTeams[]> {
  const res = await fetch("/api/teams?league=cfb&division=fcs");
  if (!res.ok) throw new Error(`FCS teams request failed: ${res.status}`);
  const data = (await res.json()) as { conferences?: ConferenceTeams[] };
  return data.conferences ?? [];
}

/** Empty until loaded, and empty on failure: FCS players then drop out of
 *  search's results, and nothing else on the page depends on this. */
export function useFcsDirectory(): ConferenceTeams[] {
  const [conferences, setConferences] = useState<ConferenceTeams[]>(
    () => cached ?? []
  );

  useEffect(() => {
    if (cached) return;
    let cancelled = false;
    inflight ??= fetchFcs();
    inflight
      .then((result) => {
        cached = result;
        if (!cancelled) setConferences(result);
      })
      .catch(() => {
        // Retried on the next mount, not remembered as a failure.
        inflight = undefined;
      });
    return () => {
      cancelled = true;
    };
  }, []);

  return conferences;
}
