"use client";

import { useCallback, useEffect, useState } from "react";
import { readHiddenTeams, writeHiddenTeams } from "@/lib/news-filter";

/**
 * The For you sheet's unchecked teams (2026-10-19), read from `localStorage`
 * after hydration like the follows are, so the server markup and the first
 * client render agree; `isLoaded` gates the page the same way.
 */
export function useNewsHiddenTeams() {
  const [hidden, setHidden] = useState<Set<string>>(() => new Set());
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setHidden(readHiddenTeams(typeof localStorage === "undefined" ? undefined : localStorage));
    setIsLoaded(true);
  }, []);

  const isShown = useCallback((key: string) => !hidden.has(key), [hidden]);

  const setShown = useCallback((key: string, shown: boolean) => {
    setHidden((prev) => {
      if (shown === !prev.has(key)) return prev;
      const next = new Set(prev);
      if (shown) next.delete(key);
      else next.add(key);
      writeHiddenTeams(typeof localStorage === "undefined" ? undefined : localStorage, next);
      return next;
    });
  }, []);

  return { hidden, isLoaded, isShown, setShown };
}
