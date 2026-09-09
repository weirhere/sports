"use client";

// Persisted Scores UI state — the web `UIStateStore` (iOS
// sports/Stores/UIStateStore.swift). One localStorage key carries the Live
// and slate filters (persisted per the 2026-08-29 decision), collapsed
// section ids, the followed-table order, and the follow-prompt dismissal.
//
// COLLAPSED ids are stored, not expanded ones, so a section never seen
// before defaults open — the iOS "Following + Top 25 open by default"
// semantics generalized to everything-open on web.
//
// The **grouping** retired with the week strip (iOS, 2026-09-05): the day is
// the axis now, and the by-conference view is what the league accordions
// already are. A stored `grouping` from an older build is simply ignored.

import { useCallback, useEffect, useState } from "react";
import { isValidScoreFilterToken } from "@/lib/game-sections";

const STORAGE_KEY = "statside.ui.v1";

interface StoredUIState {
  collapsedSections: string[];
  liveOnly: boolean;
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

const DEFAULTS: StoredUIState = {
  collapsedSections: [],
  liveOnly: false,
  scoreFilter: null,
  tableOrder: [],
  followPromptDismissed: false,
};

function sanitize(raw: unknown): StoredUIState {
  if (typeof raw !== "object" || raw === null) return DEFAULTS;
  const record = raw as Record<string, unknown>;
  const collapsed = Array.isArray(record.collapsedSections)
    ? record.collapsedSections.filter(
        (id): id is string => typeof id === "string"
      )
    : [];
  const filter =
    typeof record.scoreFilter === "string" &&
    isValidScoreFilterToken(record.scoreFilter)
      ? record.scoreFilter
      : null;
  const tableOrder = Array.isArray(record.tableOrder)
    ? record.tableOrder.filter((id): id is string => typeof id === "string")
    : [];
  return {
    collapsedSections: collapsed,
    liveOnly: record.liveOnly === true,
    scoreFilter: filter,
    tableOrder,
    followPromptDismissed: record.followPromptDismissed === true,
  };
}

export function useUIState() {
  const [state, setState] = useState<StoredUIState>(DEFAULTS);
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
    (patch: Partial<StoredUIState> | ((prev: StoredUIState) => StoredUIState)) => {
      setState((prev) => {
        const next =
          typeof patch === "function" ? patch(prev) : { ...prev, ...patch };
        try {
          localStorage.setItem(STORAGE_KEY, JSON.stringify(next));
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
    (liveOnly: boolean) => update({ liveOnly }),
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
    (sectionId: string) => state.collapsedSections.includes(sectionId),
    [state.collapsedSections]
  );

  const toggleSection = useCallback(
    (sectionId: string) =>
      update((prev) => ({
        ...prev,
        collapsedSections: prev.collapsedSections.includes(sectionId)
          ? prev.collapsedSections.filter((id) => id !== sectionId)
          : [...prev.collapsedSections, sectionId],
      })),
    [update]
  );

  /** The pinch analog's bulk ops, scoped to the ids on screen. */
  const collapseAll = useCallback(
    (sectionIds: string[]) =>
      update((prev) => ({
        ...prev,
        collapsedSections: [
          ...new Set([...prev.collapsedSections, ...sectionIds]),
        ],
      })),
    [update]
  );

  const expandAll = useCallback(
    (sectionIds: string[]) => {
      const clearing = new Set(sectionIds);
      update((prev) => ({
        ...prev,
        collapsedSections: prev.collapsedSections.filter(
          (id) => !clearing.has(id)
        ),
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
