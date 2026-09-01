"use client";

import { useState, useEffect, useCallback } from "react";

const TEAM_STORAGE_KEY = "cfb-hub-favorites";
const CONF_STORAGE_KEY = "cfb-hub-fav-conferences";

export function useFavorites() {
  const [favorites, setFavorites] = useState<string[]>([]);
  const [favoriteConferences, setFavoriteConferences] = useState<string[]>([]);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    try {
      const storedTeams = localStorage.getItem(TEAM_STORAGE_KEY);
      if (storedTeams) {
        setFavorites(JSON.parse(storedTeams));
      }
      const storedConfs = localStorage.getItem(CONF_STORAGE_KEY);
      if (storedConfs) {
        setFavoriteConferences(JSON.parse(storedConfs));
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
        localStorage.setItem(TEAM_STORAGE_KEY, JSON.stringify(next));
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

  const toggleFavoriteConference = useCallback((conferenceId: string) => {
    setFavoriteConferences((prev) => {
      const next = prev.includes(conferenceId)
        ? prev.filter((id) => id !== conferenceId)
        : [...prev, conferenceId];
      try {
        localStorage.setItem(CONF_STORAGE_KEY, JSON.stringify(next));
      } catch {
        // Ignore localStorage errors
      }
      return next;
    });
  }, []);

  const isFavoriteConference = useCallback(
    (conferenceId: string) => favoriteConferences.includes(conferenceId),
    [favoriteConferences]
  );

  const reorderFavorites = useCallback((reordered: string[]) => {
    setFavorites(reordered);
    try {
      localStorage.setItem(TEAM_STORAGE_KEY, JSON.stringify(reordered));
    } catch {
      // Ignore localStorage errors
    }
  }, []);

  const reorderFavoriteConferences = useCallback((reordered: string[]) => {
    setFavoriteConferences(reordered);
    try {
      localStorage.setItem(CONF_STORAGE_KEY, JSON.stringify(reordered));
    } catch {
      // Ignore localStorage errors
    }
  }, []);

  return {
    favorites,
    toggleFavorite,
    isFavorite,
    reorderFavorites,
    favoriteConferences,
    toggleFavoriteConference,
    isFavoriteConference,
    reorderFavoriteConferences,
    isLoaded,
  };
}
