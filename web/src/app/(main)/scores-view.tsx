"use client";

// The Scores screen — one day, every league (iOS `ScoresScreen`, 2026-09-05).
//
// The day is the axis. A week strip could only ever be honest about one
// league — college football's Week 2 and the NFL's are different date
// ranges, and its single "Bowls" slot swallows four NFL playoff rounds whole
// — so the leagues stack as accordions under one shared calendar instead of
// taking turns behind a selector: Following first, then the tables you
// follow, then college football's conferences and each other league's whole
// slate.

import { useCallback, useEffect, useMemo, useState } from "react";
import { AnimatePresence, motion, useReducedMotion } from "framer-motion";
import {
  buildSections,
  scoreFilterChipLabel,
  scoreFilterLabel,
  splitAtHideAll,
  type GameSection,
} from "@/lib/game-sections";
import { orderedTables } from "@/lib/followed-tables";
import { daySectionTitle, isSameDay, startOfDay } from "@/lib/day";
import { seasonLabel } from "@/lib/leagues";
import { ACCORDION_TRANSITION, INSTANT_TRANSITION } from "@/lib/motion";
import { SCORES_HOME_EVENT } from "@/lib/scores-home";
import { narrowsOn, useUIState } from "@/lib/hooks/use-ui-state";
import {
  useLeagueScoreboards,
  type LeagueScoreboardsSeed,
} from "@/lib/hooks/use-league-scoreboards";
import { ChromePortal } from "@/components/chrome-portal";
import { DayCalendarSheet } from "@/components/day-calendar-sheet";
import { TodayButton } from "@/components/today-button";
import { SectionAccordion } from "@/components/section-accordion";
import { HideAllControl } from "@/components/hide-all-control";
import { ScoresControlCard } from "@/components/scores-control-card";
import { ScoreFilterSheet } from "@/components/score-filter-sheet";
import { FollowPromptCard } from "@/components/follow-prompt-card";
import { FollowingSidebar } from "@/components/following-sidebar";
import { ConferenceGroupSkeleton } from "@/components/game-card-skeleton";
import { OnboardingModal } from "@/components/onboarding-modal";
import { PageHeader } from "@/components/page-header";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { useSwipe } from "@/lib/hooks/use-swipe";

interface ScoresViewProps {
  /** The day the server rendered, and its slate across every league. */
  seed: LeagueScoreboardsSeed;
}

export function ScoresView({ seed }: ScoresViewProps) {
  const {
    days,
    selectedDay,
    seasonYear,
    currentSeasonYear,
    availableSeasons,
    games,
    isLoaded,
    isStalled,
    error,
    canJumpToToday,
    showsTodayJump,
    selectDay,
    selectSeason,
    selectToday,
    adjacentDay,
    refresh,
  } = useLeagueScoreboards(seed);

  const uiState = useUIState();
  const {
    favorites,
    favoriteConferences,
    favoritePolls,
    isLoaded: favoritesLoaded,
  } = useFavoritesContext();

  const [filterSheetOpen, setFilterSheetOpen] = useState(false);
  const [calendarOpen, setCalendarOpen] = useState(false);
  const reducedMotion = useReducedMotion();

  // --- The "now" filters -----------------------------------------------
  //
  // Live and Tight are stored as intent and apply to today alone (iOS,
  // 2026-09-12): off today they are suspended — the pills turn off with the
  // day and the slate shows the whole of it — and coming back turns them on
  // again. Everything that narrows or labels *this day* reads these two;
  // only the "Ongoing" rename reads the intent.
  const liveOnly = narrowsOn(uiState.liveOnly, selectedDay);
  const tightOnly = narrowsOn(uiState.tightOnly, selectedDay);

  // --- Sections --------------------------------------------------------

  // Both follow sets are league-qualified keys as stored, so no id is ever
  // read against the wrong league's table.
  const followedTables = useMemo(
    () =>
      orderedTables({
        followedConferenceTokens: favoriteConferences,
        followedPollLeagues: favoritePolls,
        order: uiState.tableOrder,
      }),
    [favoriteConferences, favoritePolls, uiState.tableOrder]
  );

  const sections = useMemo(
    () =>
      buildSections(games, {
        followedTeamKeys: favorites,
        followedTables,
        liveOnly,
        tightOnly,
        scoreFilter: uiState.scoreFilter,
      }),
    [games, favorites, followedTables, liveOnly, tightOnly, uiState.scoreFilter]
  );

  // --- Header controls -------------------------------------------------

  const isOnToday =
    seasonYear === currentSeasonYear &&
    isSameDay(selectedDay, startOfDay(new Date()));

  /**
   * Turning the Live filter on navigates to where live games are — today
   * (iOS 2026-08-29, re-pointed at the day axis). Filtering a future day to
   * an empty screen answers the wrong question. Turning it off stays put.
   *
   * The pill reads the effective filter, so a click while it is off is
   * always a request to turn it on — including off today, where the filter
   * is suspended rather than forgotten (2026-09-12). That click may change
   * no stored state at all: the trip home is the whole action.
   */
  const handleToggleLive = () => {
    if (liveOnly) {
      uiState.setLiveOnly(false);
      return;
    }
    uiState.setLiveOnly(true);
    if (!isOnToday) selectToday();
  };

  /** `handleToggleLive`'s twin: on goes to today, off stays put. Turning
   *  one on turns the other off — Tight is already a narrower Live. */
  const handleToggleTight = () => {
    if (tightOnly) {
      uiState.setTightOnly(false);
      return;
    }
    uiState.setTightOnly(true);
    if (!isOnToday) selectToday();
  };

  const clearFilters = () => {
    uiState.setLiveOnly(false);
    uiState.setTightOnly(false);
    uiState.setScoreFilter(null);
  };

  // --- Going home ------------------------------------------------------

  /**
   * The Today button's own move (iOS `jumpToToday`, 2026-09-12). It goes
   * through `selectToday`, so a strip bounded to a past season re-bounds to
   * this one rather than selecting a date the strip has no chip for — and
   * it takes the slate back to its top with it. A day you left scrolled to
   * the bottom shouldn't hand today back the same way, and a client-side
   * day change never resets the window's scroll on its own.
   *
   * Instant, not smooth: the day under the scroll is being replaced in the
   * same frame, so there is nothing worth watching travel.
   */
  const jumpToToday = useCallback(() => {
    selectToday();
    window.scrollTo({ top: 0, behavior: "instant" });
  }, [selectToday]);

  /**
   * The Games tab clicked while Games is already on screen: the top of this
   * page, and today (iOS `goHome`, 2026-09-20 and 2026-09-21). The filters
   * and the accordions are left exactly as they were — the day is the one
   * piece of page state home resets. `canJumpToToday` is the whole gate:
   * false on today, and false in the offseason, where today sits outside
   * every league's span — so a June re-tap still only scrolls to the top.
   */
  useEffect(() => {
    const goHome = () => {
      if (canJumpToToday) {
        jumpToToday();
        return;
      }
      window.scrollTo({ top: 0, behavior: reducedMotion ? "instant" : "smooth" });
    };
    window.addEventListener(SCORES_HOME_EVENT, goHome);
    return () => window.removeEventListener(SCORES_HOME_EVENT, goHome);
  }, [canJumpToToday, jumpToToday, reducedMotion]);

  // The funnel chip's label: filter + past season ("SEC · 2019").
  const filterLabel =
    [
      uiState.scoreFilter !== null
        ? scoreFilterChipLabel(uiState.scoreFilter)
        : undefined,
      seasonYear !== currentSeasonYear
        ? seasonLabel("cfb", seasonYear)
        : undefined,
    ]
      .filter(Boolean)
      .join(" · ") || null;

  // --- The day swipe ---------------------------------------------------
  //
  // Left walks forward, right walks back; season ends are a quiet no-op.
  // The hook swallows the click a drag would otherwise leave behind, so a
  // swipe that starts on a full-width game row can't also open the game.
  const { ref: swipeRef } = useSwipe({
    onSwipeLeft: () => {
      const next = adjacentDay(1);
      if (next) selectDay(next);
    },
    onSwipeRight: () => {
      const previous = adjacentDay(-1);
      if (previous) selectDay(previous);
    },
  });

  // --- Empty states ----------------------------------------------------

  const filtersActive = liveOnly || tightOnly || uiState.scoreFilter !== null;
  const narrowedEmptyMessage = (() => {
    const label =
      uiState.scoreFilter !== null
        ? scoreFilterLabel(uiState.scoreFilter)
        : undefined;
    const now = liveOnly ? "live" : tightOnly ? "tight" : undefined;
    if (now && label) return `No ${now} ${label} games right now`;
    if (now) return `No ${now} games right now`;
    if (label) return `No ${label} games on this day`;
    return "";
  })();

  const showFollowPrompt =
    uiState.isLoaded &&
    favoritesLoaded &&
    favorites.length === 0 &&
    favoriteConferences.length === 0 &&
    !uiState.followPromptDismissed;

  const sectionIds = sections.map((section) => section.id);
  const allCollapsed =
    sectionIds.length > 0 && sectionIds.every(uiState.isCollapsed);

  // What's yours above the Hide all/Show all line, everything else below.
  const { mine, others, hasBoundary } = splitAtHideAll(sections);
  const othersHidden = hasBoundary && uiState.hideOtherSections;

  const accordion = (section: GameSection) => (
    <SectionAccordion
      key={section.id}
      section={section}
      isExpanded={!uiState.isCollapsed(section.id)}
      onToggle={() => uiState.toggleSection(section.id)}
    />
  );

  return (
    <div>
      {/* The root tabs' one masthead (iOS `PageHeader`, 2026-09-21). */}
      <PageHeader title="Games" />
      <ScoreFilterSheet
        open={filterSheetOpen}
        onOpenChange={setFilterSheetOpen}
        current={uiState.scoreFilter}
        onSelect={uiState.setScoreFilter}
        selectedYear={seasonYear}
        availableSeasons={availableSeasons}
        onYearChange={selectSeason}
      />

      <DayCalendarSheet
        open={calendarOpen}
        onOpenChange={setCalendarOpen}
        days={days}
        selectedDay={selectedDay}
        onSelect={selectDay}
        onToday={isOnToday ? undefined : selectToday}
      />

      <OnboardingModal />

      {/* Two columns on desktop: the follow rail, then the slate. The slate
          column is what the page's max width is sized around — a game row
          wider than this puts a score a hand's width from the team it
          belongs to (#112). Both columns start at the same top edge, which
          is the control card's — the day strip used to be fixed chrome
          above them, and the grid had to clear its height. */}
      <div className="grid gap-[var(--sidebar-gap)] lg:grid-cols-[var(--sidebar-w)_minmax(0,1fr)] lg:items-start">
        <FollowingSidebar />

        <div className="min-w-0">
          {/* The card is the column's top edge, which is what the rail
              beside it aligns to. Outside the swipe ref on purpose: the day
              strip scrolls horizontally under the same finger, and a drag
              that scrolled the strip must not also step the day. */}
          <ScoresControlCard
            days={days}
            selectedDay={selectedDay}
            onSelectDay={selectDay}
            onOpenCalendar={() => setCalendarOpen(true)}
            narrowsToNow={uiState.narrowsToNow}
            liveOnly={liveOnly}
            onToggleLive={handleToggleLive}
            tightOnly={tightOnly}
            onToggleTight={handleToggleTight}
            filterLabel={filterLabel}
            onOpenFilter={() => setFilterSheetOpen(true)}
            allCollapsed={allCollapsed}
            onToggleCollapseAll={
              sectionIds.length > 0
                ? () =>
                    allCollapsed
                      ? uiState.expandAll(sectionIds)
                      : uiState.collapseAll(sectionIds)
                : null
            }
          />

          <div ref={swipeRef} className="mt-3">
            {error !== null && games.length > 0 && (
              <div className="mb-3 flex items-center justify-center gap-3 rounded-[10px] bg-bg-elevated px-4 py-2">
                <span className="type-meta text-text-secondary">
                  Couldn&apos;t refresh
                </span>
                <button
                  type="button"
                  onClick={refresh}
                  className="type-meta-em text-text-primary"
                >
                  Retry
                </button>
              </div>
            )}

            {/* The skeleton covers a load that is still out, and nothing
                else. It used to cover every unloaded day, and a failed
                fetch never writes its day — so the error and its Retry
                below were unreachable on exactly the failure that needed
                them (2026-09-17). */}
            {!isLoaded && !isStalled ? (
              <div className="space-y-3">
                {Array.from({ length: 4 }).map((_, i) => (
                  <ConferenceGroupSkeleton key={i} rows={i === 0 ? 4 : 3} />
                ))}
              </div>
            ) : isStalled || (error !== null && games.length === 0) ? (
              <EmptySlate message={error ?? "Couldn't load games"}>
                <button
                  type="button"
                  onClick={refresh}
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
                <EmptySlate
                  message={`No games on ${daySectionTitle(selectedDay)}`}
                />
              )
            ) : (
              <div className="space-y-3">
                {showFollowPrompt && (
                  // Hidden at rail width: the rail is already saying it, and
                  // one screen shouldn't ask twice (#112).
                  <div className="lg:hidden">
                    <FollowPromptCard onDismiss={uiState.dismissFollowPrompt} />
                  </div>
                )}
                {mine.map(accordion)}
                {hasBoundary && (
                  <>
                    <HideAllControl
                      others={others}
                      isHidden={othersHidden}
                      onToggle={uiState.toggleHideOtherSections}
                      controls="scores-other-sections"
                    />
                    {/* The stack below the line closes the way a section
                        does — the same 0.18s ease-out (2026-09-24). */}
                    <AnimatePresence initial={false}>
                      {!othersHidden && (
                        <motion.div
                          id="scores-other-sections"
                          initial={{ height: 0 }}
                          animate={{ height: "auto" }}
                          exit={{ height: 0 }}
                          transition={
                            reducedMotion
                              ? INSTANT_TRANSITION
                              : ACCORDION_TRANSITION
                          }
                          className="overflow-clip"
                        >
                          <div className="space-y-3">
                            {others.map(accordion)}
                          </div>
                        </motion.div>
                      )}
                    </AnimatePresence>
                  </>
                )}
              </div>
            )}

            {/* Bottom clearance for the floating Today button, so the last
                row is never underneath it. Only where the button exists. */}
            {showsTodayJump && <div aria-hidden="true" className="h-14" />}
          </div>
        </div>
      </div>

      {/* `position: fixed`, so it mounts outside the route template — a
          transformed ancestor would become its containing block for the
          length of the page-entrance animation and anchor it to that rather
          than to the viewport. The day strip needed the same escape until it
          moved into the control card and stopped being fixed at all. */}
      {showsTodayJump && (
        <ChromePortal>
          <TodayButton onClick={jumpToToday} liveOnly={uiState.narrowsToNow} />
        </ChromePortal>
      )}
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
