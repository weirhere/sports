"use client";

// Scores UI state — the web `UIStateStore` (iOS
// sports/Stores/UIStateStore.swift). One localStorage key carries the slate
// filter (persisted per the 2026-08-29 decision), the Hide all/Show all
// state, collapsed section ids, the followed-table order, and the
// follow-prompt dismissal.
//
// Live and Tight are *session-only* (Josh Vertucci via Andy, 2026-10-22,
// superseding 2026-08-29): "Live" is a question about right now, and a fresh
// page load answers it fresh, the way FotMob does. The funnel filter is a
// preference and still persists. A `liveOnly`/`tightOnly` an older build
// wrote to storage is ignored on read and dropped on the next write.
//
// Live and Tight are held as *intent*. What narrows a given day is
// `narrowsOn` below: both apply to today and nowhere else (iOS, 2026-09-12).
//
// COLLAPSED ids are stored, not expanded ones, so a section never seen
// before defaults open — the iOS "Following + Top 25 open by default"
// semantics generalized to everything-open on web. The one exception is
// college basketball's conferences (2026-11-02, iOS's same rule): they start
// closed, ~350 games a night in two sections each, so for those the OPENED
// ids are stored instead (`openedSections`).
//
// The **grouping** retired with the week strip (iOS, 2026-09-05): the day is
// the axis now, and the by-conference view is what the league accordions
// already are. A stored `grouping` from an older build is simply ignored.

import { useCallback, useEffect, useState } from "react";
import { isSameDay } from "@/lib/day";
import { isValidScoreFilterToken } from "@/lib/game-sections";
import { foldDivisionTokens } from "@/lib/favorites-migration";

const STORAGE_KEY = "statside.ui.v1";

/** What reaches localStorage. */
export interface StoredUIState {
  collapsedSections: string[];
  /** Sections that start closed and were opened — see `startsClosed`. */
  openedSections: string[];
  /**
   * Hide all/Show all (iOS, 2026-09-22): true collapses every Scores section
   * that isn't Following or a followed table to the one control. Persisted
   * like the filters — a crowded slate hidden once stays hidden until you
   * ask to see it again.
   */
  hideOtherSections: boolean;
  /** `"top25"` | `"conference-cfb:8"` | null. */
  scoreFilter: string | null;
  /**
   * Followed tables in the order they lead the Scores page — one list, one
   * order, both screens (iOS, 2026-09-06). A set saved before the order
   * existed falls back to the hub's own tier order, so nothing migrates.
   */
  tableOrder: string[];
  followPromptDismissed: boolean;
}

/** The stored state plus the two session-only filters. */
export interface UIState extends StoredUIState {
  liveOnly: boolean;
  /**
   * The Tight filter (iOS, 2026-09-24). Exclusive with `liveOnly` — Tight is
   * already a narrower Live — so turning one on turns the other off.
   */
  tightOnly: boolean;
}

const DEFAULTS: UIState = {
  collapsedSections: [],
  openedSections: [],
  liveOnly: false,
  tightOnly: false,
  hideOtherSections: false,
  scoreFilter: null,
  tableOrder: [],
  followPromptDismissed: false,
};

/**
 * What an older build saved for Live and Tight never comes back: the read
 * keeps the session defaults (both off) whatever storage says.
 */
export function sanitize(raw: unknown): UIState {
  if (typeof raw !== "object" || raw === null) return DEFAULTS;
  const record = raw as Record<string, unknown>;
  const collapsed = Array.isArray(record.collapsedSections)
    ? record.collapsedSections.filter(
        (id): id is string => typeof id === "string"
      )
    : [];
  const opened = Array.isArray(record.openedSections)
    ? record.openedSections.filter((id): id is string => typeof id === "string")
    : [];
  const filter =
    typeof record.scoreFilter === "string" &&
    isValidScoreFilterToken(record.scoreFilter)
      ? record.scoreFilter
      : null;
  // Division tokens fold into their conference's, as the follows themselves
  // do (2026-09-26): a dragged Atlantic keeps its place as the East.
  const tableOrder = Array.isArray(record.tableOrder)
    ? foldDivisionTokens(
        record.tableOrder.filter((id): id is string => typeof id === "string"),
        "conf-"
      )
    : [];
  return {
    collapsedSections: collapsed,
    openedSections: opened,
    liveOnly: false,
    tightOnly: false,
    hideOtherSections: record.hideOtherSections === true,
    scoreFilter: filter,
    tableOrder,
    followPromptDismissed: record.followPromptDismissed === true,
  };
}

/**
 * Whether a Scores section starts closed: a college basketball conference,
 * or its "Other" bucket. A weeknight is ~180 Division I men's games and
 * ~165 women's, each in two conference sections, and open by default that
 * is seven hundred rows between NCAAF and the NFL. A followed one, hoisted
 * under Following, opens like the rest of what's yours (iOS, WEIR-93).
 */
export function startsClosed(section: SectionRef): boolean {
  const { id, isFollowed } = sectionRef(section);
  return !isFollowed && /^(conf-|other-)(mcbb|wcbb)(:|$)/.test(id);
}

/** A Scores section, or a bare id for one that is never followed. */
export type SectionRef = string | { id: string; isFollowed?: boolean };

function sectionRef(section: SectionRef): { id: string; isFollowed: boolean } {
  return typeof section === "string"
    ? { id: section, isFollowed: false }
    : { id: section.id, isFollowed: section.isFollowed === true };
}

/** The slice that is written: everything but the session-only filters. */
export function toStored(state: UIState): StoredUIState {
  return {
    collapsedSections: state.collapsedSections,
    openedSections: state.openedSections,
    hideOtherSections: state.hideOtherSections,
    scoreFilter: state.scoreFilter,
    tableOrder: state.tableOrder,
    followPromptDismissed: state.followPromptDismissed,
  };
}

export function useUIState() {
  const [state, setState] = useState<UIState>(DEFAULTS);
  const [isLoaded, setIsLoaded] = useState(false);

  useEffect(() => {
    // Read post-hydration on purpose (the use-favorites pattern): a lazy
    // initializer would diverge from the server-rendered markup.
    try {
      const raw = localStorage.getItem(STORAGE_KEY);
      if (raw !== null) {
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setState(sanitize(JSON.parse(raw)));
      }
    } catch {
      // Ignore storage errors — defaults stand.
    }
    setIsLoaded(true);
  }, []);

  const update = useCallback(
    (patch: Partial<UIState> | ((prev: UIState) => UIState)) => {
      setState((prev) => {
        const next =
          typeof patch === "function" ? patch(prev) : { ...prev, ...patch };
        try {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(toStored(next)));
        } catch {
          // Ignore storage errors — in-memory state still updates.
        }
        return next;
      });
    },
    []
  );

  const setTableOrder = useCallback(
    (tableOrder: string[]) => update({ tableOrder }),
    [update]
  );
  const setLiveOnly = useCallback(
    (liveOnly: boolean) =>
      update((prev) => ({
        ...prev,
        liveOnly,
        tightOnly: liveOnly ? false : prev.tightOnly,
      })),
    [update]
  );
  const setTightOnly = useCallback(
    (tightOnly: boolean) =>
      update((prev) => ({
        ...prev,
        tightOnly,
        liveOnly: tightOnly ? false : prev.liveOnly,
      })),
    [update]
  );
  const toggleHideOtherSections = useCallback(
    () =>
      update((prev) => ({
        ...prev,
        hideOtherSections: !prev.hideOtherSections,
      })),
    [update]
  );
  const setScoreFilter = useCallback(
    (scoreFilter: string | null) => update({ scoreFilter }),
    [update]
  );
  const dismissFollowPrompt = useCallback(
    () => update({ followPromptDismissed: true }),
    [update]
  );

  const isCollapsed = useCallback(
    (section: SectionRef) => {
      const sectionId = sectionRef(section).id;
      return startsClosed(section)
        ? !state.openedSections.includes(sectionId)
        : state.collapsedSections.includes(sectionId);
    },
    [state.collapsedSections, state.openedSections]
  );

  const toggleSection = useCallback(
    (section: SectionRef) => {
      const sectionId = sectionRef(section).id;
      update((prev) =>
        startsClosed(section)
          ? {
              ...prev,
              openedSections: prev.openedSections.includes(sectionId)
                ? prev.openedSections.filter((id) => id !== sectionId)
                : [...prev.openedSections, sectionId],
            }
          : {
              ...prev,
              collapsedSections: prev.collapsedSections.includes(sectionId)
                ? prev.collapsedSections.filter((id) => id !== sectionId)
                : [...prev.collapsedSections, sectionId],
            }
      );
    },
    [update]
  );

  /** The pinch analog's bulk ops, scoped to the ids on screen. */
  const collapseAll = useCallback(
    (sections: SectionRef[]) => {
      const sectionIds = sections.map((section) => sectionRef(section).id);
      const closing = new Set(sectionIds);
      update((prev) => ({
        ...prev,
        collapsedSections: [
          ...new Set([
            ...prev.collapsedSections,
            ...sections
              .filter((section) => !startsClosed(section))
              .map((section) => sectionRef(section).id),
          ]),
        ],
        openedSections: prev.openedSections.filter((id) => !closing.has(id)),
      }));
    },
    [update]
  );

  const expandAll = useCallback(
    (sections: SectionRef[]) => {
      const sectionIds = sections.map((section) => sectionRef(section).id);
      const clearing = new Set(sectionIds);
      update((prev) => ({
        ...prev,
        collapsedSections: prev.collapsedSections.filter(
          (id) => !clearing.has(id)
        ),
        openedSections: [
          ...new Set([
            ...prev.openedSections,
            ...sections
              .filter(startsClosed)
              .map((section) => sectionRef(section).id),
          ]),
        ],
      }));
    },
    [update]
  );

  return {
    isLoaded,
    tableOrder: state.tableOrder,
    setTableOrder,
    liveOnly: state.liveOnly,
    setLiveOnly,
    tightOnly: state.tightOnly,
    setTightOnly,
    /**
     * Either filter that narrows the slate to what's happening now — the
     * intent, not the day's effective filter. It's what renames today
     * "Ongoing" on the strip and the Today button.
     */
    narrowsToNow: state.liveOnly || state.tightOnly,
    hideOtherSections: state.hideOtherSections,
    toggleHideOtherSections,
    scoreFilter: state.scoreFilter,
    setScoreFilter,
    followPromptDismissed: state.followPromptDismissed,
    dismissFollowPrompt,
    collapsedSections: state.collapsedSections,
    isCollapsed,
    toggleSection,
    collapseAll,
    expandAll,
  };
}

/**
 * Whether a remembered "now" filter is actually narrowing `day`: the toggle
 * is on *and* the day is today (iOS `UIStateStore.liveOnly(on:)`,
 * 2026-09-12).
 *
 * "Live" is a question about right now, and today is the only day that can
 * answer it — on tomorrow the filter guarantees an empty screen, and on
 * yesterday it hides every result the day exists to show. So stepping off
 * today suspends the filter and coming back restores it, with the pill
 * following. Suspended, never forgotten: the intent stays stored, which is
 * what makes coming home turn it back on. Tight follows the same rule.
 */
export function narrowsOn(
  intent: boolean,
  day: Date,
  now: Date = new Date()
): boolean {
  return intent && isSameDay(day, now);
}
