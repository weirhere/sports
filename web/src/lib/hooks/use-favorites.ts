"use client";

import { useState, useEffect, useCallback } from "react";
import { migrateFavorites } from "@/lib/favorites-migration";

const TEAM_STORAGE_KEY = "cfb-hub-favorites";
const CONF_STORAGE_KEY = "cfb-hub-fav-conferences";
const VERSION_KEY = "cfb-hub-favorites-version";
const CURRENT_VERSION = "2";

function readStoredIds(key: string): string[] {
  const raw = localStorage.getItem(key);
  if (!raw) return [];
  const parsed: unknown = JSON.parse(raw);
  if (!Array.isArray(parsed)) return [];
  return parsed.filter((id): id is string => typeof id === "string");
}

export function useFavorites() {
  const [favorites, setFavorites] = useState<string[]>([]);
  const [favoriteConferences, setFavoriteConferences] = useState<string[]>([]);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    // localStorage is read post-hydration on purpose: a lazy initializer would
    // diverge from the server-rendered markup. isLoaded gates render instead.
    try {
      let teams = readStoredIds(TEAM_STORAGE_KEY);
      let confs = readStoredIds(CONF_STORAGE_KEY);

      // v2 ids are bare ESPN numeric strings. The migration is pure and
      // idempotent, so it runs on every load — that also normalizes any
      // legacy mock ids written after the version flag flipped (surfaces
      // still on mock data write "t-*" ids until they go live). The version
      // key marks the store migrated; a write-back only happens when
      // something actually changed or the flag is missing.
      const migrated = migrateFavorites(teams, confs);
      const changed =
        migrated.teams.length !== teams.length ||
        migrated.confs.length !== confs.length ||
        migrated.teams.some((id, i) => id !== teams[i]) ||
        migrated.confs.some((id, i) => id !== confs[i]);
      teams = migrated.teams;
      confs = migrated.confs;
      if (changed || localStorage.getItem(VERSION_KEY) !== CURRENT_VERSION) {
        localStorage.setItem(TEAM_STORAGE_KEY, JSON.stringify(teams));
        localStorage.setItem(CONF_STORAGE_KEY, JSON.stringify(confs));
        localStorage.setItem(VERSION_KEY, CURRENT_VERSION);
      }

      // eslint-disable-next-line react-hooks/set-state-in-effect
      setFavorites(teams);
      setFavoriteConferences(confs);
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

  return {
    favorites,
    toggleFavorite,
    isFavorite,
    favoriteConferences,
    toggleFavoriteConference,
    isFavoriteConference,
    isLoaded,
  };
}
