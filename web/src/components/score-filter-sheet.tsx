"use client";

// The Scores view-options sheet — the iOS `ScoreFilterSheet`: grouping
// (by date / by conference), the season menu (moved in from the old navbar
// portal), and the ESPN-style slate filter — all games, Top 25, then every
// FBS conference in the app's browsing order. A conference tap selects and
// dismisses; grouping and season apply in place.

import { Check, Trophy } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ConferenceLogo } from "./theme/conference-logo";
import { SeasonMenuChip } from "./season-menu-chip";
import { seasonYears } from "@/lib/season";
import type { ScoresGrouping } from "@/lib/game-sections";
import { conferenceFilterToken } from "@/lib/game-sections";
import { conferenceLogoUrl, conferenceName, orderedIds } from "@/lib/conferences";
import { cn } from "@/lib/utils";

interface ScoreFilterSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** The active slate filter token ("top25" | "conference-8") or null. */
  current: string | null;
  onSelect: (filter: string | null) => void;
  grouping: ScoresGrouping;
  onSetGrouping: (grouping: ScoresGrouping) => void;
  selectedYear: number;
  onYearChange: (year: number) => void;
}

export function ScoreFilterSheet({
  open,
  onOpenChange,
  current,
  onSelect,
  grouping,
  onSetGrouping,
  selectedYear,
  onYearChange,
}: ScoreFilterSheetProps) {
  const pick = (filter: string | null) => {
    onSelect(filter);
    onOpenChange(false);
  };

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent
        className={cn(
          // Bottom sheet on mobile, centered card on desktop.
          "gap-0 overflow-hidden border-divider bg-bg-card p-0",
          "max-sm:top-auto max-sm:bottom-0 max-sm:left-0 max-sm:max-w-full max-sm:translate-x-0 max-sm:translate-y-0 max-sm:rounded-b-none max-sm:rounded-t-2xl",
          "max-sm:data-[state=closed]:slide-out-to-bottom max-sm:data-[state=open]:slide-in-from-bottom max-sm:data-[state=closed]:zoom-out-100 max-sm:data-[state=open]:zoom-in-100"
        )}
      >
        <DialogHeader className="border-b border-divider px-4 py-3">
          <DialogTitle className="type-chip-em text-center text-text-primary">
            Filter
          </DialogTitle>
        </DialogHeader>

        <div className="max-h-[70vh] overflow-y-auto overscroll-contain p-4 pb-[max(1rem,env(safe-area-inset-bottom))]">
          {/* View */}
          <p className="type-chip-em mb-2 text-text-primary">View</p>
          <div
            role="radiogroup"
            aria-label="Grouping"
            className="flex rounded-[10px] bg-bg-elevated p-1"
          >
            {(
              [
                ["date", "By date"],
                ["conference", "By conference"],
              ] as const
            ).map(([value, label]) => (
              <button
                key={value}
                type="button"
                role="radio"
                aria-checked={grouping === value}
                onClick={() => onSetGrouping(value)}
                className={cn(
                  "type-chip flex-1 rounded-lg py-1.5 transition-colors",
                  grouping === value
                    ? "bg-bg-card text-text-primary shadow-card"
                    : "text-text-secondary hover:text-text-primary"
                )}
              >
                {label}
              </button>
            ))}
          </div>

          <div className="mt-3 flex items-center justify-between">
            <span className="type-chip text-text-primary">Season</span>
            <SeasonMenuChip
              value={selectedYear}
              years={seasonYears()}
              onSelect={onYearChange}
            />
          </div>

          {/* Conference */}
          <p className="type-chip-em mb-2 mt-5 text-text-primary">Conference</p>
          <div>
            <FilterRow
              label="All games"
              selected={current === null}
              onClick={() => pick(null)}
              mark={
                <span
                  aria-hidden="true"
                  className="flex h-6 w-6 items-center justify-center"
                >
                  <svg
                    viewBox="0 0 12 8"
                    className="h-2.5 w-4 fill-text-secondary"
                  >
                    <ellipse cx="6" cy="4" rx="5.6" ry="3.6" />
                  </svg>
                </span>
              }
            />
            <FilterRow
              label="Top 25"
              selected={current === "top25"}
              onClick={() => pick("top25")}
              mark={
                <span className="flex h-6 w-6 items-center justify-center">
                  <Trophy
                    aria-hidden="true"
                    className="h-4 w-4 text-text-secondary"
                  />
                </span>
              }
            />
            {orderedIds.map((id) => (
              <FilterRow
                key={id}
                label={conferenceName(id)}
                selected={current === conferenceFilterToken(id)}
                onClick={() => pick(conferenceFilterToken(id))}
                mark={
                  <span className="flex h-6 w-6 items-center justify-center">
                    <ConferenceLogo
                      src={conferenceLogoUrl(id)}
                      name={conferenceName(id)}
                    />
                  </span>
                }
              />
            ))}
          </div>
        </div>
      </DialogContent>
    </Dialog>
  );
}

function FilterRow({
  label,
  selected,
  onClick,
  mark,
}: {
  label: string;
  selected: boolean;
  onClick: () => void;
  mark: React.ReactNode;
}) {
  return (
    <button
      type="button"
      onClick={onClick}
      aria-pressed={selected}
      className="flex w-full items-center gap-3 rounded-lg px-2 py-2.5 text-left transition-colors hover:bg-bg-header"
    >
      {mark}
      <span
        className={cn(
          selected ? "type-chip-em" : "type-chip",
          "text-text-primary"
        )}
      >
        {label}
      </span>
      {selected && (
        <Check
          aria-hidden="true"
          className="ml-auto h-4 w-4 text-text-primary"
        />
      )}
    </button>
  );
}
