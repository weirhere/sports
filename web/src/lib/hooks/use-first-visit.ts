"use client";

import { useState, useEffect, useCallback } from "react";

const STORAGE_KEY = "cfb-hub-visited";

export function useFirstVisit() {
  const [isFirstVisit, setIsFirstVisit] = useState(false);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    const visited = localStorage.getItem(STORAGE_KEY);
    setIsFirstVisit(!visited);
    setIsLoaded(true);
  }, []);

  const markVisited = useCallback(() => {
    localStorage.setItem(STORAGE_KEY, "true");
    setIsFirstVisit(false);
  }, []);

  return { isFirstVisit, isLoaded, markVisited };
}
