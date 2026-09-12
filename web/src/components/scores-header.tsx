"use client";

// The Scores slate controls — the iOS `ScoresHeader` grouped capsule
// (FotMob's tap-target language): one bg-elevated capsule holding the Live
// pill and the view-options funnel.
//
// It rendered into the nav bar's right slot until 2026-09-10, on the
// reasoning that "/" already had a header and shouldn't grow a second one.
// True, but it put the day's two scopes a header away from the day itself —
// and left the strip below to carry the alignment alone. Both now sit in
// `ScoresControlCard`, one row apart, and the nav bar is the wordmark and
// the site nav again.

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
          // Active, the pill wears the accent rather than the ink (FotMob,
          // 2026-09-12) — a tint under a hairline, the label holding its
          // own contrast either way. Only the Live chip gets this: it IS
          // the live affordance, which is what keeps the budget at three.
          "type-chip-em flex items-center gap-1.5 rounded-full border border-transparent px-3 py-1.5 transition-colors",
          liveOnly
            ? "border-live-edge bg-live-tint text-text-primary"
            : "text-text-primary hover:bg-bg-header"
        )}
      >
        {/* The dot is the filter's "on" light — gray until it spends. */}
        <span
          aria-hidden="true"
          className={cn(
            "h-2 w-2 rounded-full",
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
          // The transparent border matches the Live pill's, so the two sit
          // at the same height whichever of them is active.
          "type-chip-em flex items-center gap-1.5 rounded-full border border-transparent px-3 py-1.5 transition-colors",
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
