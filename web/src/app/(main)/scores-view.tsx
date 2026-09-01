"use client";

import { useState, useEffect, useMemo, useRef, useCallback } from "react";
import type { Game } from "@/lib/types";
import type { WeekSlot } from "@/lib/season";
import { cfbSeasonYear, defaultWeekSelection } from "@/lib/season";
import {
  buildSections,
  scoreFilterChipLabel,
  scoreFilterLabel,
} from "@/lib/game-sections";
import { useUIState } from "@/lib/hooks/use-ui-state";
import { WeekStrip } from "@/components/week-strip";
import { SectionAccordion } from "@/components/section-accordion";
import { ScoresHeader } from "@/components/scores-header";
import { ScoreFilterSheet } from "@/components/score-filter-sheet";
import { FollowPromptCard } from "@/components/follow-prompt-card";
import { ConferenceGroupSkeleton } from "@/components/game-card-skeleton";
import { OnboardingModal } from "@/components/onboarding-modal";
import { getScoreboard } from "@/lib/api";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { useLiveScores } from "@/lib/hooks/use-live-scores";
import { useSwipe } from "@/lib/hooks/use-swipe";

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
  // A failed fetch with data still on screen shows the quiet banner; with
  // nothing to show it becomes the full-screen retry state.
  const [fetchFailed, setFetchFailed] = useState(false);
  const [sheetOpen, setSheetOpen] = useState(false);

  const uiState = useUIState();
  const { favorites, favoriteConferences, isLoaded: favoritesLoaded } =
    useFavoritesContext();

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
        if (seq === fetchSeqRef.current) {
          setGames(board.games);
          setFetchFailed(false);
        }
      } catch {
        // Keep the cached/previous slate; the banner/retry state says so.
        if (seq === fetchSeqRef.current) setFetchFailed(true);
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
        setFetchFailed(false);
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
        setFetchFailed(true);
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
      setFetchFailed(false);
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

  // --- Sections (the game-sections engine) ---

  const followedConferenceIds = useMemo(
    () =>
      favoriteConferences
        .map(Number)
        .filter((id) => Number.isFinite(id)),
    [favoriteConferences]
  );

  const sections = useMemo(
    () =>
      buildSections(games, {
        grouping: uiState.grouping,
        followedTeamIds: favorites,
        followedConferenceIds,
        liveOnly: uiState.liveOnly,
        scoreFilter: uiState.scoreFilter,
      }),
    [
      games,
      uiState.grouping,
      uiState.liveOnly,
      uiState.scoreFilter,
      favorites,
      followedConferenceIds,
    ]
  );

  // ESPN's current slot for the current season — where the Live toggle
  // jumps, and the strip's "today".
  const currentSlot =
    initialSeasonType !== undefined && initialCurrentWeekNumber !== undefined
      ? weeks.find(
          (slot) =>
            slot.id === `${initialSeasonType}-${initialCurrentWeekNumber}`
        )
      : undefined;

  /**
   * Turning the Live filter on goes to where live games are — the current
   * week (iOS 2026-08-29): filtering a future week to nothing answers the
   * wrong question. A past season jumps back to the current one. Turning
   * it off stays put.
   */
  const handleToggleLive = () => {
    const turningOn = !uiState.liveOnly;
    uiState.setLiveOnly(turningOn);
    if (!turningOn) return;
    if (selectedYear !== currentSeasonYear) {
      handleYearChange(currentSeasonYear);
    } else if (
      currentSlot !== undefined &&
      currentSlot.id !== selectedSlot?.id
    ) {
      handleWeekChange(currentSlot);
    }
  };

  const clearFilters = () => {
    uiState.setLiveOnly(false);
    uiState.setScoreFilter(null);
  };

  // The funnel chip's label: filter + past season ("SEC · 2019") — grouping
  // stays unlabeled, the section headers on screen already say it.
  const filterLabel =
    [
      uiState.scoreFilter !== null
        ? scoreFilterChipLabel(uiState.scoreFilter)
        : undefined,
      selectedYear !== currentSeasonYear ? String(selectedYear) : undefined,
    ]
      .filter(Boolean)
      .join(" · ") || null;

  // Swipe left/right walks to the adjacent week slot. Cached targets render
  // instantly (loadSlot seeds from the cache); un-prefetched ones skeleton.
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

  const retry = () => {
    if (selectedSlot !== undefined) loadSlot(selectedSlot, yearParam);
  };

  // --- Empty-state derivations ---

  const filtersActive = uiState.liveOnly || uiState.scoreFilter !== null;
  const narrowedEmptyMessage = (() => {
    const label =
      uiState.scoreFilter !== null
        ? scoreFilterLabel(uiState.scoreFilter)
        : undefined;
    if (uiState.liveOnly && label) return `No live ${label} games right now`;
    if (uiState.liveOnly) return "No live games right now";
    if (label) return `No ${label} games this week`;
    return "";
  })();

  /** The next week-slot start still in the future — the offseason countdown. */
  const nextKickoff = useMemo(() => {
    const now = Date.now();
    const starts = weeks
      .map((slot) => Date.parse(slot.startDate ?? ""))
      .filter((time) => Number.isFinite(time) && time > now);
    return starts.length > 0 ? new Date(Math.min(...starts)) : undefined;
  }, [weeks]);

  const showFollowPrompt =
    uiState.isLoaded &&
    favoritesLoaded &&
    favorites.length === 0 &&
    favoriteConferences.length === 0 &&
    !uiState.followPromptDismissed;

  const sectionIds = sections.map((section) => section.id);
  const allCollapsed =
    sectionIds.length > 0 && sectionIds.every(uiState.isCollapsed);

  return (
    <div>
      <ScoresHeader
        liveOnly={uiState.liveOnly}
        onToggleLive={handleToggleLive}
        filterLabel={filterLabel}
        onOpenFilter={() => setSheetOpen(true)}
      />
      <ScoreFilterSheet
        open={sheetOpen}
        onOpenChange={setSheetOpen}
        current={uiState.scoreFilter}
        onSelect={uiState.setScoreFilter}
        grouping={uiState.grouping}
        onSetGrouping={uiState.setGrouping}
        selectedYear={selectedYear}
        onYearChange={handleYearChange}
      />

      <WeekStrip
        weeks={weeks}
        selectedId={selectedSlot?.id ?? ""}
        onSelect={handleWeekChange}
      />

      <OnboardingModal />

      <div ref={swipeRef} className="mt-12">
        {fetchFailed && games.length > 0 && (
          <div className="mb-3 flex items-center justify-center gap-3 rounded-[10px] bg-bg-elevated px-4 py-2">
            <span className="type-meta text-text-secondary">
              Couldn&apos;t refresh
            </span>
            <button
              type="button"
              onClick={retry}
              className="type-meta-em text-text-primary"
            >
              Retry
            </button>
          </div>
        )}

        {loading ? (
          <div className="space-y-3">
            {Array.from({ length: 4 }).map((_, i) => (
              <ConferenceGroupSkeleton key={i} rows={i === 0 ? 4 : 3} />
            ))}
          </div>
        ) : fetchFailed && games.length === 0 ? (
          <EmptySlate message="Couldn't load games">
            <button
              type="button"
              onClick={retry}
              className="type-team-name-em text-text-primary"
            >
              Retry
            </button>
          </EmptySlate>
        ) : sections.length === 0 ? (
          filtersActive ? (
            // The narrowed-slate empty state: name what's hiding the games,
            // and offer the whole slate back with one button.
            <EmptySlate message={narrowedEmptyMessage}>
              <button
                type="button"
                onClick={clearFilters}
                className="type-team-name-em text-text-primary"
              >
                Show all games
              </button>
            </EmptySlate>
          ) : (
            <EmptySlate message="No games this week">
              {nextKickoff !== undefined && (
                <p className="type-meta-em text-text-primary">
                  Season kicks off{" "}
                  {nextKickoff.toLocaleDateString("en-US", {
                    weekday: "long",
                    month: "long",
                    day: "numeric",
                  })}
                </p>
              )}
            </EmptySlate>
          )
        ) : (
          <>
            <div className="mb-2 flex min-h-5 justify-end">
              {/* The iOS pinch analog, scoped to on-screen sections. */}
              <button
                type="button"
                onClick={() =>
                  allCollapsed
                    ? uiState.expandAll(sectionIds)
                    : uiState.collapseAll(sectionIds)
                }
                className="type-meta text-text-secondary transition-colors hover:text-text-primary"
              >
                {allCollapsed ? "Expand all" : "Collapse all"}
              </button>
            </div>
            <div className="space-y-3">
              {showFollowPrompt && (
                <FollowPromptCard onDismiss={uiState.dismissFollowPrompt} />
              )}
              {sections.map((section) => (
                <SectionAccordion
                  key={section.id}
                  section={section}
                  isExpanded={!uiState.isCollapsed(section.id)}
                  onToggle={() => uiState.toggleSection(section.id)}
                  pinsHeader={section.kind === "day"}
                />
              ))}
            </div>
          </>
        )}
      </div>
    </div>
  );
}

function EmptySlate({
  message,
  children,
}: {
  message: string;
  children?: React.ReactNode;
}) {
  return (
    <div className="flex flex-col items-center gap-3 py-16 text-center">
      <p className="type-team-name text-text-secondary">{message}</p>
      {children}
    </div>
  );
}
