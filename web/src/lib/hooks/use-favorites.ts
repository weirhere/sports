"use client";

import { useState, useEffect, useCallback } from "react";
import { migrateFavorites } from "@/lib/favorites-migration";
import { isLeague, type League } from "@/lib/leagues";
import type { ConferenceToken, FollowKey } from "@/lib/refs";

const TEAM_STORAGE_KEY = "cfb-hub-favorites";
const CONF_STORAGE_KEY = "cfb-hub-fav-conferences";
/**
 * Followed polls, stored as bare **league** tokens (`"cfb"`).
 *
 * Keyed by league rather than a flag because the NFL has no poll today and
 * a league that grows one must need no migration. Deliberately outside the
 * migration and the version key: the set is new, so there is nothing to
 * migrate, and a value that isn't a league is dropped on read.
 */
const POLL_STORAGE_KEY = "cfb-hub-fav-polls";
const VERSION_KEY = "cfb-hub-favorites-version";
// v3 league-qualifies both sets ("cfb:130", "cfb:8") — ESPN ids collide
// across leagues, so a bare id follows two teams at once.
const CURRENT_VERSION = "3";

function readStoredIds(key: string): string[] {
  const raw = localStorage.getItem(key);
  if (!raw) return [];
  const parsed: unknown = JSON.parse(raw);
  if (!Array.isArray(parsed)) return [];
  return parsed.filter((id): id is string => typeof id === "string");
}

/**
 * The follow sets, stored as **league-qualified keys** — `"cfb:130"` for a
 * team, `"cfb:8"` for a conference. Never bare ids: ESPN id 5 is UAB and
 * the Browns, and group 8 is the SEC and the AFC, so a bare-id set follows
 * two things at once. Build a key with `followKey` / `conferenceToken` from
 * `@/lib/refs` — the branded `FollowKey`/`ConferenceToken` types make those
 * the only way in, so a bare id won't compile.
 */
export function useFavorites() {
  const [favorites, setFavorites] = useState<string[]>([]);
  const [favoriteConferences, setFavoriteConferences] = useState<string[]>([]);
  const [favoritePolls, setFavoritePolls] = useState<League[]>([]);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    // localStorage is read post-hydration on purpose: a lazy initializer would
    // diverge from the server-rendered markup. isLoaded gates render instead.
    try {
      let teams = readStoredIds(TEAM_STORAGE_KEY);
      let confs = readStoredIds(CONF_STORAGE_KEY);

      // v3 values are league-qualified keys ("cfb:130"). The migration is
      // pure and idempotent, so it runs on every load — that also
      // normalizes anything a stale tab wrote in an older spelling. The
      // version key marks the store migrated; a write-back only happens
      // when something actually changed or the flag is missing.
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
      setFavoritePolls(readStoredIds(POLL_STORAGE_KEY).filter(isLeague));
    } catch {
      // Ignore localStorage errors
    }
    setIsLoaded(true);
  }, []);

  const toggleFavorite = useCallback((key: FollowKey) => {
    setFavorites((prev) => {
      const next = prev.includes(key)
        ? prev.filter((id) => id !== key)
        : [...prev, key];
      try {
        localStorage.setItem(TEAM_STORAGE_KEY, JSON.stringify(next));
      } catch {
        // Ignore localStorage errors
      }
      return next;
    });
  }, []);

  const isFavorite = useCallback(
    (key: FollowKey) => favorites.includes(key),
    [favorites]
  );

  const toggleFavoriteConference = useCallback((token: ConferenceToken) => {
    setFavoriteConferences((prev) => {
      const next = prev.includes(token)
        ? prev.filter((id) => id !== token)
        : [...prev, token];
      try {
        localStorage.setItem(CONF_STORAGE_KEY, JSON.stringify(next));
      } catch {
        // Ignore localStorage errors
      }
      return next;
    });
  }, []);

  const isFavoriteConference = useCallback(
    (token: ConferenceToken) => favoriteConferences.includes(token),
    [favoriteConferences]
  );

  const toggleFavoritePoll = useCallback((league: League) => {
    setFavoritePolls((prev) => {
      const next = prev.includes(league)
        ? prev.filter((id) => id !== league)
        : [...prev, league];
      try {
        localStorage.setItem(POLL_STORAGE_KEY, JSON.stringify(next));
      } catch {
        // Ignore localStorage errors
      }
      return next;
    });
  }, []);

  const isFavoritePoll = useCallback(
    (league: League) => favoritePolls.includes(league),
    [favoritePolls]
  );

  return {
    favorites,
    toggleFavorite,
    isFavorite,
    favoriteConferences,
    toggleFavoriteConference,
    isFavoriteConference,
    favoritePolls,
    toggleFavoritePoll,
    isFavoritePoll,
    isLoaded,
  };
}
