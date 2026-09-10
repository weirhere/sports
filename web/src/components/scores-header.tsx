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
