"use client";

import { useState, useEffect, useMemo, useRef, useCallback } from "react";
import { createPortal } from "react-dom";
import type { Game, DayGames, ConferenceGameGroup, Conference } from "@/lib/types";
import type { WeekSlot } from "@/lib/season";
import { cfbSeasonYear, defaultWeekSelection } from "@/lib/season";
import { WeekSelector } from "@/components/week-selector";
import { DayGroup } from "@/components/day-group";
import { ConferenceGroupSkeleton } from "@/components/game-card-skeleton";
import { EmptyState } from "@/components/empty-state";
import { getScoreboard } from "@/lib/api";
import { FBS_CONFERENCES } from "@/config/conferences";
import { MyTeamsSection } from "@/components/my-teams-section";
import { OnboardingModal } from "@/components/onboarding-modal";
import { useLiveScores } from "@/lib/hooks/use-live-scores";
import { useSwipe } from "@/lib/hooks/use-swipe";
import { SeasonSelector } from "@/components/season-selector";

interface ScoresViewProps {
  initialGames: Game[];
  /** Calendar-derived week slots for the current season. */
  initialWeeks: WeekSlot[];
  /** ESPN's current week number, from the scoreboard payload. */
  initialCurrentWeekNumber?: number;
  /** ESPN's current season type (2 regular, 3 postseason). */
  initialSeasonType?: number;
  initialSeasonYear?: number;
}

function groupGamesByDay(games: Game[]): DayGames[] {
  const dayMap = new Map<string, Game[]>();

  for (const game of games) {
    const date = new Date(game.scheduledAt);
    const dateKey = date.toISOString().split("T")[0];
    if (!dayMap.has(dateKey)) dayMap.set(dateKey, []);
    dayMap.get(dateKey)!.push(game);
  }

  const days: DayGames[] = [];
  const sortedDates = [...dayMap.keys()].sort();

  for (const dateKey of sortedDates) {
    const dayGames = dayMap.get(dateKey)!;
    const date = new Date(dateKey + "T12:00:00Z");
    const label = date.toLocaleDateString("en-US", {
      weekday: "long",
      month: "long",
      day: "numeric",
    });

    // Group by conference within this day
    const confMap = new Map<string, Game[]>();
    for (const game of dayGames) {
      // Use home team's conference as the grouping key
      const confId = game.homeTeam.team.conferenceId;
      if (!confMap.has(confId)) confMap.set(confId, []);
      confMap.get(confId)!.push(game);
    }

    const conferenceGroups: ConferenceGameGroup[] = [];
    for (const [confId, confGames] of confMap) {
      const conference = FBS_CONFERENCES.find((c) => c.id === confId) || {
        id: confId,
        name: confGames[0]?.homeTeam.team.conferenceName || "Unknown",
        shortName: confGames[0]?.homeTeam.team.conferenceName || "Unknown",
        division: confGames[0]?.homeTeam.team.division || "FBS" as const,
      };
      conferenceGroups.push({ conference: conference as Conference, games: confGames });
    }

    // Sort: Power 4 conferences first, then Group of 5, then others
    conferenceGroups.sort((a, b) => {
      const power4 = ["8", "5", "1", "4"]; // SEC, Big Ten, ACC, Big 12
      const aIsPower4 = power4.includes(a.conference.id);
      const bIsPower4 = power4.includes(b.conference.id);
      if (aIsPower4 && !bIsPower4) return -1;
      if (!aIsPower4 && bIsPower4) return 1;
      return a.conference.name.localeCompare(b.conference.name);
    });

    days.push({ date: dateKey, label, conferenceGroups });
  }

  return days;
}

export function ScoresView({
  initialGames,
  initialWeeks,
  initialCurrentWeekNumber,
  initialSeasonType,
  initialSeasonYear,
}: ScoresViewProps) {
  // The season the world is in right now — the anchor for "is the selected
  // year a past season". ESPN's payload year wins; the clock is the
  // fallback for a failed server fetch.
  const [currentSeasonYear] = useState(
    () => initialSeasonYear ?? cfbSeasonYear()
  );

  const [weeks, setWeeks] = useState(initialWeeks);
  const [selectedSlot, setSelectedSlot] = useState<WeekSlot | undefined>(() =>
    // Server-rendered selection is ESPN's current week — clock-free, so the
    // hydration markup matches. The viewer-clock Sunday rule runs in an
    // effect below.
    initialWeeks.find(
      (slot) =>
        slot.seasonType === initialSeasonType &&
        slot.value === initialCurrentWeekNumber
    ) ?? initialWeeks[0]
  );
  const [selectedYear, setSelectedYear] = useState(currentSeasonYear);
  const [games, setGames] = useState(initialGames);
  const [loading, setLoading] = useState(false);

  // The current season's requests omit `year` so they share the server
  // page's cache entries; past seasons must pin it.
  const yearParam = selectedYear === currentSeasonYear ? undefined : selectedYear;

  // Per-week client cache, seeded with the server payload. Cleared on
  // season change. Lazy ref init keeps the seed out of every render.
  const cacheRef = useRef<Map<string, Game[]> | null>(null);
  if (cacheRef.current === null) {
    cacheRef.current = new Map();
    if (selectedSlot !== undefined) {
      cacheRef.current.set(selectedSlot.id, initialGames);
    }
  }
  const cache = cacheRef.current;

  // Monotonic fetch counter: a settled fetch only writes the visible slate
  // if nothing newer superseded it (the cache always keeps the result).
  const fetchSeqRef = useRef(0);
  const prefetchedRef = useRef(new Set<string>());

  const selectedSlotRef = useRef(selectedSlot);
  useEffect(() => {
    selectedSlotRef.current = selectedSlot;
  });

  /** Show a slot: cached slate instantly (if any), then a fresh fetch. */
  const loadSlot = useCallback(
    async (slot: WeekSlot, year: number | undefined) => {
      const seq = ++fetchSeqRef.current;
      const cached = cache.get(slot.id);
      if (cached !== undefined) {
        setGames(cached);
      } else {
        setLoading(true);
      }
      try {
        const board = await getScoreboard(
          { value: slot.value, seasonType: slot.seasonType },
          year
        );
        cache.set(slot.id, board.games);
        if (seq === fetchSeqRef.current) setGames(board.games);
      } catch {
        // Keep the cached/previous slate on error.
      } finally {
        if (seq === fetchSeqRef.current) setLoading(false);
      }
    },
    [cache]
  );

  const handleWeekChange = useCallback(
    (slot: WeekSlot) => {
      setSelectedSlot(slot);
      loadSlot(slot, yearParam);
    },
    [loadSlot, yearParam]
  );

  // Post-hydration, re-run the Sunday-rollover rule with the VIEWER's
  // clock — the server's UTC clock must never decide "is it Sunday here".
  // Differs from ESPN's current week only on Sundays.
  const didDefaultRef = useRef(false);
  useEffect(() => {
    if (didDefaultRef.current) return;
    didDefaultRef.current = true;
    const preferred = defaultWeekSelection(
      initialWeeks,
      initialCurrentWeekNumber,
      initialSeasonType,
      new Date()
    );
    if (preferred !== undefined && preferred.id !== selectedSlotRef.current?.id) {
      setSelectedSlot(preferred);
      loadSlot(preferred, undefined);
    }
  }, [initialWeeks, initialCurrentWeekNumber, initialSeasonType, loadSlot]);

  const handleYearChange = useCallback(
    async (year: number) => {
      if (year === selectedYear) return;
      const previousYear = selectedYear;
      setSelectedYear(year);
      cache.clear();
      prefetchedRef.current.clear();
      setLoading(true);
      const seq = ++fetchSeqRef.current;
      const isCurrent = year === currentSeasonYear;
      try {
        // One request carries both the season's calendar and a slate: the
        // current season lands on ESPN's current week, a past season on its
        // opening regular-season week.
        const board = isCurrent
          ? await getScoreboard()
          : await getScoreboard({ value: 1, seasonType: 2 }, year);
        if (seq !== fetchSeqRef.current) return;

        setWeeks(board.weeks);
        const slot = isCurrent
          ? defaultWeekSelection(
              board.weeks,
              board.currentWeekNumber,
              board.seasonType,
              new Date()
            )
          : (board.weeks.find((s) => !s.isPostseason) ?? board.weeks[0]);
        setSelectedSlot(slot);
        if (slot === undefined) {
          setGames([]);
          setLoading(false);
          return;
        }

        const fetchedId = isCurrent
          ? `${board.seasonType}-${board.currentWeekNumber}`
          : "2-1";
        if (slot.id === fetchedId) {
          cache.set(slot.id, board.games);
          setGames(board.games);
          setLoading(false);
        } else {
          // The chosen slot isn't the one this payload carries (Sunday
          // rollover, or a season whose strip opens on Week 0).
          loadSlot(slot, isCurrent ? undefined : year);
        }
      } catch {
        if (seq !== fetchSeqRef.current) return;
        // Failed season switch: stay where we were.
        setSelectedYear(previousYear);
        const current = selectedSlotRef.current;
        if (current !== undefined) cache.set(current.id, games);
        setLoading(false);
      }
    },
    [selectedYear, currentSeasonYear, cache, loadSlot, games]
  );

  // Live score polling — selected week only, never the prefetch cache.
  const handleLiveUpdate = useCallback(
    (updatedGames: Game[]) => {
      const slot = selectedSlotRef.current;
      if (slot !== undefined) cache.set(slot.id, updatedGames);
      setGames(updatedGames);
    },
    [cache]
  );

  useLiveScores(selectedSlot, yearParam, games, handleLiveUpdate);

  // ±1 neighbor prefetch once the selected week settles — fetched once
  // into the cache, never polled.
  useEffect(() => {
    if (selectedSlot === undefined || loading) return;
    const index = weeks.findIndex((slot) => slot.id === selectedSlot.id);
    if (index === -1) return;
    for (const neighbor of [weeks[index - 1], weeks[index + 1]]) {
      if (neighbor === undefined) continue;
      if (cache.has(neighbor.id) || prefetchedRef.current.has(neighbor.id)) {
        continue;
      }
      prefetchedRef.current.add(neighbor.id);
      getScoreboard(
        { value: neighbor.value, seasonType: neighbor.seasonType },
        yearParam
      )
        .then((board) => {
          cache.set(neighbor.id, board.games);
        })
        .catch(() => {
          // Allow a retry on the next settle.
          prefetchedRef.current.delete(neighbor.id);
        });
    }
  }, [selectedSlot, weeks, loading, yearParam, cache]);

  const days = useMemo(() => groupGamesByDay(games), [games]);

  // Swipe left/right walks to the adjacent week slot.
  const selectedIndex =
    selectedSlot !== undefined
      ? weeks.findIndex((slot) => slot.id === selectedSlot.id)
      : -1;
  const { ref: swipeRef } = useSwipe({
    onSwipeLeft: () => {
      if (selectedIndex !== -1 && selectedIndex < weeks.length - 1) {
        handleWeekChange(weeks[selectedIndex + 1]);
      }
    },
    onSwipeRight: () => {
      if (selectedIndex > 0) {
        handleWeekChange(weeks[selectedIndex - 1]);
      }
    },
    enabled: !loading,
  });

  // ESPN's current slot gets the week strip's "today" emphasis — current
  // season only; a past season has no current week.
  const currentSlotId =
    selectedYear === currentSeasonYear &&
    initialSeasonType !== undefined &&
    initialCurrentWeekNumber !== undefined
      ? `${initialSeasonType}-${initialCurrentWeekNumber}`
      : undefined;

  // Portal the season selector into the navbar right slot
  const [portalTarget, setPortalTarget] = useState<HTMLElement | null>(null);
  useEffect(() => {
    setPortalTarget(document.getElementById("navbar-right-slot"));
    return () => setPortalTarget(null);
  }, []);

  return (
    <div>
      {portalTarget &&
        createPortal(
          <SeasonSelector
            selectedYear={selectedYear}
            onYearChange={handleYearChange}
          />,
          portalTarget
        )}

      <WeekSelector
        weeks={weeks}
        selectedId={selectedSlot?.id ?? ""}
        onSelect={handleWeekChange}
        currentId={currentSlotId}
      />

      <OnboardingModal />

      <div ref={swipeRef} className="mt-8 space-y-6">
        {loading ? (
          <div className="space-y-3">
            {Array.from({ length: 4 }).map((_, i) => (
              <ConferenceGroupSkeleton key={i} rows={i === 0 ? 4 : 3} />
            ))}
          </div>
        ) : games.length === 0 ? (
          <EmptyState
            title="No games this week"
            description="Check back later or select a different week."
          />
        ) : (
          <>
            {/* My Teams */}
            <MyTeamsSection games={games} />

            {days.map((day) => (
              <DayGroup key={day.date} dayGames={day} />
            ))}
          </>
        )}
      </div>
    </div>
  );
}
