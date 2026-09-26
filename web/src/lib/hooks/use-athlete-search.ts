"use client";

// The athlete half of search, which is the half that costs a request — iOS
// `AthleteSearchStore` (sports/Stores/AthleteSearchStore.swift, 2026-09-21).
//
// Every other corpus the search box reads is already loaded, so results land
// on the keystroke. Athletes come from ESPN's search endpoint (through
// `/api/search/athletes`), and a request per keystroke would be slow and
// rude. So this debounces, and it cancels: a superseded query is aborted
// rather than racing the one after it back.
//
// Athletes arrive **beside** the instant results, never instead of them.

import { useEffect, useState } from "react";
import type { SearchAthlete } from "@/lib/types";

/** Long enough that typing a name doesn't fire per letter, short enough
 *  that the players are there by the time the eye reaches them. */
export const SEARCH_DEBOUNCE_MS = 300;

interface Settled {
  /** The query these athletes answer. */
  query: string;
  athletes: SearchAthlete[];
}

export function useAthleteSearch(text: string): {
  athletes: SearchAthlete[];
  /** True only while the *current* query is unanswered, so a spinner can't
   *  outlive the query that asked for it. */
  isSearching: boolean;
} {
  const query = text.trim();
  const [settled, setSettled] = useState<Settled>({ query: "", athletes: [] });

  useEffect(() => {
    if (query.length === 0) return;
    const controller = new AbortController();
    const timer = window.setTimeout(() => {
      fetch(`/api/search/athletes?q=${encodeURIComponent(query)}`, {
        signal: controller.signal,
      })
        .then(
          (res): Promise<{ athletes?: SearchAthlete[] }> =>
            res.ok ? res.json() : Promise.resolve({})
        )
        .then((data) => {
          setSettled({ query, athletes: data.athletes ?? [] });
        })
        .catch((err: unknown) => {
          if (controller.signal.aborted) return;
          // A failed request says nothing on screen, deliberately: the rest
          // of search still works, and an error banner over a working team
          // list would be the loudest thing on a screen whose job is speed.
          console.warn("Athlete search failed:", err);
          setSettled({ query, athletes: [] });
        });
    }, SEARCH_DEBOUNCE_MS);
    return () => {
      window.clearTimeout(timer);
      controller.abort();
    };
  }, [query]);

  // A cleared field shows no stale people. Otherwise the last answer stays
  // up until the next one lands, as on iOS — the list fills rather than
  // blinking empty on every keystroke.
  if (query.length === 0) return { athletes: [], isSearching: false };
  return { athletes: settled.athletes, isSearching: settled.query !== query };
}
