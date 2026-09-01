"use client";

// The Scores header controls — the iOS `ScoresHeader` grouped capsule
// (FotMob's tap-target language): one bg-elevated capsule holding the Live
// pill and the view-options funnel. The wordmark half of the iOS header is
// already the nav bar's job on "/", so rather than mounting a second header
// this component renders the capsule INTO the nav bar's right slot — one
// header, wordmark left, controls right. (The old season-selector portal is
// gone; the season menu lives in the filter sheet now.)

import { useEffect, useState } from "react";
import { createPortal } from "react-dom";
import { ListFilter } from "lucide-react";
import { cn } from "@/lib/utils";

interface ScoresHeaderProps {
  liveOnly: boolean;
  onToggleLive: () => void;
  /**
   * The funnel's non-default-state label — "SEC", "2019", "SEC · 2019",
   * "Top 25" — or null when the slate and season are the defaults.
   */
  filterLabel: string | null;
  onOpenFilter: () => void;
}

export function ScoresHeaderControls({
  liveOnly,
  onToggleLive,
  filterLabel,
  onOpenFilter,
}: ScoresHeaderProps) {
  return (
    <div className="flex items-center gap-0.5 rounded-full bg-bg-elevated p-1">
      <button
        type="button"
        onClick={onToggleLive}
        aria-pressed={liveOnly}
        aria-label="Live games only"
        className={cn(
          "type-chip-em flex items-center gap-1.5 rounded-full px-3 py-1.5 transition-colors",
          liveOnly
            ? "bg-text-primary text-bg-primary"
            : "text-text-primary hover:bg-bg-header"
        )}
      >
        {/* The dot is the filter's "on" light — gray until it spends. */}
        <span
          aria-hidden="true"
          className={cn(
            "h-1.5 w-1.5 rounded-full",
            liveOnly ? "bg-live" : "bg-text-secondary"
          )}
        />
        Live
      </button>
      <button
        type="button"
        onClick={onOpenFilter}
        aria-label={
          filterLabel !== null ? `Filtered to ${filterLabel}` : "Filter games"
        }
        aria-haspopup="dialog"
        className={cn(
          "type-chip-em flex items-center gap-1.5 rounded-full px-3 py-1.5 transition-colors",
          filterLabel !== null
            ? "bg-text-primary text-bg-primary"
            : "text-text-primary hover:bg-bg-header"
        )}
      >
        <ListFilter aria-hidden="true" className="h-4 w-4" />
        {filterLabel !== null && (
          <span className="whitespace-nowrap">{filterLabel}</span>
        )}
      </button>
    </div>
  );
}

/**
 * Mounts the controls into the nav bar's right slot so "/" keeps exactly
 * one header row.
 */
export function ScoresHeader(props: ScoresHeaderProps) {
  const [target, setTarget] = useState<HTMLElement | null>(null);
  useEffect(() => {
    // The slot only exists post-hydration; the one-time lookup-and-set is
    // the same pattern use-favorites documents for post-hydration reads.
    // eslint-disable-next-line react-hooks/set-state-in-effect
    setTarget(document.getElementById("navbar-right-slot"));
    return () => setTarget(null);
  }, []);
  if (target === null) return null;
  return createPortal(<ScoresHeaderControls {...props} />, target);
}
