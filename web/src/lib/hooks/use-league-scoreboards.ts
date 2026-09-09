"use client";

// The Scores screen's model: one day, every league. The web twin of iOS
// `LeagueScoreboards` (sports/Stores/LeagueScoreboards.swift).
//
// Each league's games are held a day at a time, keyed by local calendar day.
// A day change is one request per league for a **five-day window** centred on
// the shown day — ESPN reads `dates=` on the Eastern clock, and the two-day
// margin either side absorbs the ET-to-local offset for every time zone. Only
// the inner three days are recorded as loaded, so a half-slate can't pass for
// a whole one.

import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import { getScoreboardDays } from "@/lib/api";
import { POLL_INTERVAL_LIVE } from "@/lib/constants";
import {
  addDays,
  clampDay,
  dayId,
  daysBetween,
  daysInRange,
  isSameDay,
  startOfDay,
} from "@/lib/day";
import { isLiveStatus } from "@/lib/game-sections";
import {
  LEAGUES,
  SEASON_FLOOR,
  seasonSpan,
  seasonYearContaining,
  unionSeasonSpan,
  type League,
} from "@/lib/leagues";
import type { Game } from "@/lib/types";

/** How far either side of the shown day each request reaches. */
const WINDOW_RADIUS = 2;
/** Days recorded as fully loaded — the inner window. */
const RECORDED_RADIUS = 1;
/** Days kept in memory either side of the centre. */
const CACHE_RADIUS = 10;

/**
 * How long a day sits still before we ask for it.
 *
 * The move itself is synchronous — the strip, the header and the Today
 * button follow the thumb on the frame it lifts — so only the *fetch* waits,
 * and a flick across a fortnight stops asking for every day it passed
 * through. It matters more at four leagues than two: each day change is one
 * request per league, and browsers cap concurrent connections per host, so an
 * undebounced flick queues behind its own earlier requests.
 */
const SETTLE_BEFORE_FETCH_MS = 250;

/** How far the strip can drift with today's chip still on screen. */
const TODAY_CHIP_REACH = 2;

type DayBuckets = Record<string, Game[] | undefined>;

export interface LeagueScoreboards {
  /** Every day of the selected season — the strip's contents. */
  days: Date[];
  selectedDay: Date;
  seasonYear: number;
  currentSeasonYear: number;
  availableSeasons: number[];
  /** The selected day's games, every league, chronological within a league. */
  games: Game[];
  /** True once every league has answered for the selected day. */
  isLoaded: boolean;
  isLoading: boolean;
  /** The refresh banner's copy — never a request we abandoned on purpose. */
  error: string | null;
  hasLiveGames: boolean;
  /** Whether the floating Today button has anywhere to go, and is needed. */
  showsTodayJump: boolean;
  selectDay: (day: Date) => void;
  selectSeason: (year: number) => void;
  selectToday: () => void;
  /** The day `offset` steps away, or undefined past either end of the season. */
  adjacentDay: (offset: number, from?: Date) => Date | undefined;
  refresh: () => void;
}

export interface LeagueScoreboardsSeed {
  /** The day the server rendered, as `"2026-09-05"`. */
  dayId: string;
  /** That day's games across every league. */
  games: Game[];
  /** Which leagues the seed actually covers — the rest stay unloaded. */
  leagues: readonly League[];
}

export function useLeagueScoreboards(
  seed?: LeagueScoreboardsSeed
): LeagueScoreboards {
  const today = useMemo(() => startOfDay(new Date()), []);
  const currentSeasonYear = useMemo(
    () => seasonYearContaining(today),
    [today]
  );

  const [seasonYear, setSeasonYear] = useState(currentSeasonYear);
  const [selectedDay, setSelectedDay] = useState<Date>(() => {
    const seeded = seed?.dayId;
    if (seeded) {
      const parsed = new Date(`${seeded}T00:00:00`);
      if (!Number.isNaN(parsed.getTime())) return startOfDay(parsed);
    }
    // Today, unless today is outside the season entirely — the deep
    // offseason opens on the season's nominal start and then snaps forward
    // to the first day anyone plays.
    const span = unionSeasonSpan(currentSeasonYear);
    return clampDay(today, span.start, span.end);
  });

  const [buckets, setBuckets] = useState<Record<League, DayBuckets>>(() => {
    const initial = Object.fromEntries(
      LEAGUES.map((league) => [league, {} as DayBuckets])
    ) as Record<League, DayBuckets>;
    if (seed) {
      for (const league of seed.leagues) {
        initial[league] = {
          [seed.dayId]: seed.games.filter((game) => game.league === league),
        };
      }
    }
    return initial;
  });

  const [isLoading, setIsLoading] = useState(false);
  const [error, setError] = useState<string | null>(null);

  // Windows already in flight, so a re-render mid-swipe can't stack
  // duplicate requests on the same days.
  const inFlight = useRef(new Set<string>());
  // Bumped on every day change; a fetch whose sequence is stale drops its
  // result rather than writing a day nobody is looking at.
  const sequence = useRef(0);
  const snapAttempted = useRef(new Set<string>());

  const span = useMemo(() => unionSeasonSpan(seasonYear), [seasonYear]);
  const days = useMemo(
    () => daysInRange(span.start, span.end),
    [span.start, span.end]
  );

  const availableSeasons = useMemo(() => {
    const years: number[] = [];
    for (let year = currentSeasonYear; year >= SEASON_FLOOR; year -= 1) {
      years.push(year);
    }
    return years;
  }, [currentSeasonYear]);

  const selectedId = dayId(selectedDay);

  const games = useMemo(
    () => LEAGUES.flatMap((league) => buckets[league][selectedId] ?? []),
    [buckets, selectedId]
  );

  const isLoaded = useMemo(
    () => LEAGUES.every((league) => buckets[league][selectedId] !== undefined),
    [buckets, selectedId]
  );

  const hasLiveGames = useMemo(
    () => games.some((game) => isLiveStatus(game.status)),
    [games]
  );

  // --- Fetching --------------------------------------------------------

  const fetchWindow = useCallback(
    async (centre: Date, options?: { force?: boolean }) => {
      const key = dayId(centre);
      if (!options?.force && inFlight.current.has(key)) return;
      inFlight.current.add(key);
      const seq = ++sequence.current;
      setIsLoading(true);

      const from = addDays(centre, -WINDOW_RADIUS);
      const to = addDays(centre, WINDOW_RADIUS);
      const recorded = daysInRange(
        addDays(centre, -RECORDED_RADIUS),
        addDays(centre, RECORDED_RADIUS)
      ).map(dayId);

      const results = await Promise.all(
        LEAGUES.map(async (league) => {
          try {
            const board = await getScoreboardDays(league, from, to);
            return { league, games: board.games, failed: false };
          } catch {
            return { league, games: [] as Game[], failed: true };
          }
        })
      );

      inFlight.current.delete(key);
      // The day moved out from under this fetch. Abandoned on purpose, so
      // it is never the banner's copy and never writes a stale slate.
      if (seq !== sequence.current) return;

      setBuckets((previous) => {
        const next = { ...previous };
        for (const result of results) {
          if (result.failed) continue;
          const bucketed: DayBuckets = {};
          for (const id of recorded) bucketed[id] = [];
          for (const game of result.games) {
            const time = Date.parse(game.scheduledAt);
            if (!Number.isFinite(time)) continue;
            const id = dayId(new Date(time));
            // Only the inner days are complete: the outermost day on each
            // end is whatever fell inside ESPN's Eastern window, which is a
            // partial answer for most time zones.
            if (bucketed[id] === undefined) continue;
            bucketed[id]!.push(game);
          }
          const merged: DayBuckets = { ...next[result.league], ...bucketed };
          // Evict days far from the centre, so browsing a season day by day
          // doesn't accumulate every day it touched.
          const keep = new Set(
            daysInRange(
              addDays(centre, -CACHE_RADIUS),
              addDays(centre, CACHE_RADIUS)
            ).map(dayId)
          );
          next[result.league] = Object.fromEntries(
            Object.entries(merged).filter(([id]) => keep.has(id))
          );
        }
        return next;
      });

      setError(
        results.every((result) => result.failed)
          ? "Couldn't reach the scoreboard."
          : null
      );
      setIsLoading(false);
    },
    []
  );

  // Whether every day the shown window promises is already in hand.
  const covers = useCallback(
    (centre: Date) =>
      LEAGUES.every((league) =>
        daysInRange(
          addDays(centre, -RECORDED_RADIUS),
          addDays(centre, RECORDED_RADIUS)
        ).every((day) => buckets[league][dayId(day)] !== undefined)
      ),
    [buckets]
  );

  // The debounced fetch for whatever day is selected.
  useEffect(() => {
    if (covers(selectedDay)) return;
    const handle = setTimeout(() => {
      void fetchWindow(selectedDay);
    }, SETTLE_BEFORE_FETCH_MS);
    return () => clearTimeout(handle);
    // `covers` changes identity with every bucket write; depending on the
    // day alone keeps this to one timer per day change.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId, fetchWindow]);

  // --- Never open on a dead screen -------------------------------------
  //
  // Only ever fires on a day the *app* chose — the first load and a season
  // switch. A day the user picked stays picked, empty or not: an app that
  // slides out from under a deliberate tap is a worse bug than an empty
  // Tuesday. `snapAttempted` is what draws that line, since a user can
  // navigate back to a day the probe already moved away from.
  const snapFrom = useRef<string | null>(null);
  useEffect(() => {
    if (snapFrom.current !== selectedId) return;
    if (!isLoaded || games.length > 0) return;
    if (snapAttempted.current.has(selectedId)) return;
    snapAttempted.current.add(selectedId);

    let cancelled = false;
    void (async () => {
      const found = await firstDayWithGames(selectedDay, span.end);
      if (cancelled || !found) return;
      // The user may have moved while the probe was out; their choice wins.
      if (dayId(selectedDay) !== selectedId) return;
      snapFrom.current = dayId(found);
      setSelectedDay(found);
    })();
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [selectedId, isLoaded, games.length]);

  // Arm the snap for the first day the app chose itself.
  useEffect(() => {
    snapFrom.current = selectedId;
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  // --- Polling ---------------------------------------------------------
  //
  // Polite-guest: a 30s cadence only while the document is visible AND at
  // least one loaded game is live. Nothing live means no interval at all.
  useEffect(() => {
    if (!hasLiveGames) return;
    const tick = () => {
      if (document.visibilityState !== "visible") return;
      void fetchWindow(selectedDay, { force: true });
    };
    const handle = setInterval(tick, POLL_INTERVAL_LIVE);
    return () => clearInterval(handle);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [hasLiveGames, selectedId, fetchWindow]);

  // --- Navigation ------------------------------------------------------

  const adjacentDay = useCallback(
    (offset: number, from?: Date): Date | undefined => {
      const day = addDays(from ?? selectedDay, offset);
      if (day < startOfDay(span.start) || day > startOfDay(span.end)) {
        return undefined;
      }
      return day;
    },
    [selectedDay, span.start, span.end]
  );

  const selectDay = useCallback((day: Date) => {
    // Synchronous: the strip, the header and the Today button move on the
    // frame the thumb lifts. The fetch catches up.
    setSelectedDay((previous) =>
      isSameDay(previous, day) ? previous : startOfDay(day)
    );
  }, []);

  const selectSeason = useCallback(
    (year: number) => {
      if (year === seasonYear) return;
      setSeasonYear(year);
      const next = unionSeasonSpan(year);
      const landing =
        year === currentSeasonYear
          ? clampDay(today, next.start, next.end)
          : next.start;
      snapFrom.current = dayId(landing);
      setSelectedDay(landing);
    },
    [seasonYear, currentSeasonYear, today]
  );

  const selectToday = useCallback(() => {
    if (seasonYear !== currentSeasonYear) {
      setSeasonYear(currentSeasonYear);
      const next = unionSeasonSpan(currentSeasonYear);
      setSelectedDay(clampDay(today, next.start, next.end));
      return;
    }
    setSelectedDay(today);
  }, [seasonYear, currentSeasonYear, today]);

  const refresh = useCallback(() => {
    void fetchWindow(selectedDay, { force: true });
  }, [fetchWindow, selectedDay]);

  /**
   * The floating Today button's whole condition: somewhere to go, and
   * today's chip out of view (iOS, 2026-09-07). One day out, the chip is
   * still a thumb's reach away in the strip, so the button would be a second
   * Today saying the same thing louder.
   *
   * A past season has no Today chip at all, however close the dates look —
   * the strip is bounded to the season it shows.
   */
  const showsTodayJump = useMemo(() => {
    const onToday = seasonYear === currentSeasonYear && isSameDay(selectedDay, today);
    if (onToday) return false;
    const current = unionSeasonSpan(currentSeasonYear);
    const todayIsInSeason =
      today >= startOfDay(current.start) && today <= startOfDay(current.end);
    if (!todayIsInSeason) return false;
    const chipOnStrip =
      seasonYear === currentSeasonYear &&
      Math.abs(daysBetween(today, selectedDay)) <= TODAY_CHIP_REACH;
    return !chipOnStrip;
  }, [seasonYear, currentSeasonYear, selectedDay, today]);

  return {
    days,
    selectedDay,
    seasonYear,
    currentSeasonYear,
    availableSeasons,
    games,
    isLoaded,
    isLoading,
    error,
    hasLiveGames,
    showsTodayJump,
    selectDay,
    selectSeason,
    selectToday,
    adjacentDay,
    refresh,
  };
}

/**
 * The first day from `start` onward with at least one game, searched in
 * fortnight-sized windows across every league.
 *
 * This is how the app avoids opening on a dead screen: an August Tuesday, or
 * the day a past season is selected (which lands on the season's nominal
 * start, weeks before anyone plays). Undefined when the search runs out — a
 * genuinely empty stretch, which the empty state then says plainly.
 */
async function firstDayWithGames(
  start: Date,
  seasonEnd: Date,
  searchingDays = 42
): Promise<Date | undefined> {
  const step = 14;
  let cursor = startOfDay(start);
  let searched = 0;
  while (searched < searchingDays && cursor <= seasonEnd) {
    const end = addDays(cursor, step - 1);
    const found = await Promise.all(
      LEAGUES.map(async (league) => {
        // A league whose season hasn't opened can't answer for this window;
        // skipping it keeps the probe from spending four requests to learn
        // what the calendar already says.
        const leagueSpan = seasonSpan(league, seasonYearContaining(cursor));
        if (end < leagueSpan.start || cursor > leagueSpan.end) return undefined;
        try {
          const board = await getScoreboardDays(league, cursor, end);
          const times = board.games
            .map((game) => Date.parse(game.scheduledAt))
            .filter((time) => Number.isFinite(time));
          return times.length > 0
            ? startOfDay(new Date(Math.min(...times)))
            : undefined;
        } catch {
          return undefined;
        }
      })
    );
    const earliest = found.filter((day): day is Date => day !== undefined);
    if (earliest.length > 0) {
      return new Date(Math.min(...earliest.map((day) => day.getTime())));
    }
    cursor = addDays(cursor, step);
    searched += step;
  }
  return undefined;
}
