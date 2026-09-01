"use client";

import { useState, useEffect, useCallback } from "react";

const STORAGE_KEY = "cfb-hub-visited";

export function useFirstVisit() {
  const [isFirstVisit, setIsFirstVisit] = useState(false);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    // localStorage is read post-hydration on purpose: a lazy initializer would
    // diverge from the server-rendered markup. isLoaded gates render instead.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setIsFirstVisit(!localStorage.getItem(STORAGE_KEY));
    setIsLoaded(true);
  }, []);

  const markVisited = useCallback(() => {
    localStorage.setItem(STORAGE_KEY, "true");
    setIsFirstVisit(false);
  }, []);

  return { isFirstVisit, isLoaded, markVisited };
}
