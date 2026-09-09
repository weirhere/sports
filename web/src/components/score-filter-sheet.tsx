"use client";

// The Scores view-options sheet — the iOS `ScoreFilterSheet`: the season
// menu and the ESPN-style slate filter — all games, Top 25, then every FBS
// conference in the app's browsing order. A conference tap selects and
// dismisses; the season applies in place.
//
// The grouping segmented control retired with the week strip (iOS,
// 2026-09-05): the day is the axis now, and the by-conference view is what
// the league accordions already are.

import { Check, Trophy } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { ConferenceLogo } from "./theme/conference-logo";
import { SeasonMenuChip } from "./season-menu-chip";
import { conferenceFilterToken } from "@/lib/game-sections";
import { conferenceLogoUrl, conferenceName, orderedIds } from "@/lib/conferences";
import { cn } from "@/lib/utils";

interface ScoreFilterSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** The active slate filter token ("top25" | "conference-cfb:8") or null. */
  current: string | null;
  onSelect: (filter: string | null) => void;
  selectedYear: number;
  availableSeasons: number[];
  onYearChange: (year: number) => void;
}

export function ScoreFilterSheet({
  open,
  onOpenChange,
  current,
  onSelect,
  selectedYear,
  availableSeasons,
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
          <div className="flex items-center justify-between">
            <span className="type-chip text-text-primary">Season</span>
            <SeasonMenuChip
              value={selectedYear}
              years={availableSeasons}
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
            {orderedIds.map((id) => {
              // College football's conferences are the only ones the sheet
              // lists today; W2 gives it every league's.
              const ref = { league: "cfb" as const, id };
              const token = conferenceFilterToken(ref);
              return (
                <FilterRow
                  key={id}
                  label={conferenceName(id, "cfb")}
                  selected={current === token}
                  onClick={() => pick(token)}
                  mark={
                    <span className="flex h-6 w-6 items-center justify-center">
                      <ConferenceLogo
                        src={conferenceLogoUrl(id, "cfb")}
                        name={conferenceName(id, "cfb")}
                      />
                    </span>
                  }
                />
              );
            })}
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
