"use client";

// Everything that scopes the day, in one card at the top of the slate
// column: the day strip and its calendar, then the Live toggle, the view
// funnel, and the collapse-all (Andy, 2026-09-10, from FotMob, which puts
// its date nav and its filter row in exactly this container).
//
// These three controls used to live in three places — the strip as fixed
// chrome inset past the follow rail, the Live/funnel capsule portalled into
// the nav bar, and collapse-all floating above the first accordion. The cost
// was geometric: the rail's width of dead air to the left of the strip, and
// the strip's height of dead air above every card on the page, because the
// grid had to clear chrome it didn't contain. A card puts them in the
// column's own flow, so the rail top-aligns to it and the leagues below sit
// where the cards sit.
//
// Sticky, not merely in flow: the day is the screen's axis and a Saturday
// slate is long, so the way to the next day must not be a scroll back to the
// top. It tucks under the nav bar, which is the only chrome above it.

import { DayStrip } from "@/components/day-strip";
import { ScoresHeaderControls } from "@/components/scores-header";

interface ScoresControlCardProps {
  days: Date[];
  selectedDay: Date;
  onSelectDay: (day: Date) => void;
  onOpenCalendar: () => void;
  liveOnly: boolean;
  onToggleLive: () => void;
  filterLabel: string | null;
  onOpenFilter: () => void;
  /**
   * The iOS pinch analog. Null when the day has no sections to act on —
   * an empty slate offers no "collapse all", the way the pinch has nothing
   * to fire against.
   */
  allCollapsed: boolean;
  onToggleCollapseAll: (() => void) | null;
}

export function ScoresControlCard({
  days,
  selectedDay,
  onSelectDay,
  onOpenCalendar,
  liveOnly,
  onToggleLive,
  filterLabel,
  onOpenFilter,
  allCollapsed,
  onToggleCollapseAll,
}: ScoresControlCardProps) {
  return (
    <section
      aria-label="Day and filters"
      className="card-surface sticky top-14 z-30 sm:top-16"
    >
      <DayStrip
        days={days}
        selectedDay={selectedDay}
        onSelect={onSelectDay}
        onOpenCalendar={onOpenCalendar}
        liveOnly={liveOnly}
      />
      <div className="flex items-center gap-2 border-t border-divider px-2 py-2">
        <ScoresHeaderControls
          liveOnly={liveOnly}
          onToggleLive={onToggleLive}
          filterLabel={filterLabel}
          onOpenFilter={onOpenFilter}
        />
        {onToggleCollapseAll !== null && (
          <button
            type="button"
            onClick={onToggleCollapseAll}
            className="type-meta ml-auto rounded-full px-2 py-1.5 text-text-secondary transition-colors hover:text-text-primary"
          >
            {allCollapsed ? "Expand all" : "Collapse all"}
          </button>
        )}
      </div>
    </section>
  );
}
