"use client";

import { useState, useEffect, useCallback } from "react";

const STORAGE_KEY = "cfb-hub-favorites";

export function useFavorites() {
  const [favorites, setFavorites] = useState<string[]>([]);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    try {
      const stored = localStorage.getItem(STORAGE_KEY);
      if (stored) {
        setFavorites(JSON.parse(stored));
      }
    } catch {
      // Ignore localStorage errors
    }
    setIsLoaded(true);
  }, []);

  const toggleFavorite = useCallback((teamId: string) => {
    setFavorites((prev) => {
      const next = prev.includes(teamId)
        ? prev.filter((id) => id !== teamId)
        : [...prev, teamId];
      try {
        localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
      } catch {
        // Ignore localStorage errors
      }
      return next;
    });
  }, []);

  const isFavorite = useCallback(
    (teamId: string) => favorites.includes(teamId),
    [favorites]
  );

  return { favorites, toggleFavorite, isFavorite, isLoaded };
}
