"use client";

// A calendar beside the day strip — the jump-to for "the Iron Bowl in
// November". A port of iOS `DayCalendarSheet` (2026-09-06).
//
// This is deliberately NOT a picker standing in for the axis. The strip is
// still the axis; dragging it is fine for the fortnight either side of today
// and hopeless for a date three months out, which is the only thing this
// answers. Bounded by the same season the strip is, so it can never land on
// a day the strip has no chip for.

import { useEffect, useMemo, useRef } from "react";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import { addDays, dayId, dayLongLabel, isSameDay, startOfDay } from "@/lib/day";
import { cn } from "@/lib/utils";

const WEEKDAYS = ["S", "M", "T", "W", "T", "F", "S"];

interface DayCalendarSheetProps {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** The season's own bounds — the grid never runs past them. */
  days: Date[];
  selectedDay: Date;
  onSelect: (day: Date) => void;
  /** Undefined in the offseason, where today is outside every league's span. */
  onToday?: () => void;
}

interface MonthGrid {
  key: string;
  label: string;
  /** Leading blanks so the 1st lands under its weekday. */
  leading: number;
  days: Date[];
}

function monthGrids(days: Date[]): MonthGrid[] {
  const months = new Map<string, Date[]>();
  for (const day of days) {
    const key = `${day.getFullYear()}-${String(day.getMonth() + 1).padStart(2, "0")}`;
    const bucket = months.get(key);
    if (bucket) bucket.push(day);
    else months.set(key, [day]);
  }
  return [...months.entries()].map(([key, monthDays]) => ({
    key,
    label: monthDays[0].toLocaleDateString("en-US", {
      month: "long",
      year: "numeric",
    }),
    leading: monthDays[0].getDay(),
    days: monthDays,
  }));
}

export function DayCalendarSheet({
  open,
  onOpenChange,
  days,
  selectedDay,
  onSelect,
  onToday,
}: DayCalendarSheetProps) {
  const months = useMemo(() => monthGrids(days), [days]);
  const selectedRef = useRef<HTMLButtonElement>(null);
  const today = useMemo(() => startOfDay(new Date()), []);

  useEffect(() => {
    if (!open) return;
    // Open on the month you're already in, not on August.
    selectedRef.current?.scrollIntoView({ block: "center" });
  }, [open]);

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[80vh] overflow-y-auto p-0">
        <div className="sticky top-0 z-10 flex items-center justify-between border-b border-divider bg-bg-primary px-4 py-3">
          <DialogTitle className="type-section-header text-text-primary">
            Pick a date
          </DialogTitle>
          {onToday && (
            <button
              type="button"
              onClick={() => {
                onToday();
                onOpenChange(false);
              }}
              className="type-chip-em rounded-full bg-bg-elevated px-3 py-1.5 text-text-primary transition-colors hover:bg-divider"
            >
              Today
            </button>
          )}
        </div>

        {/* Pinned weekday captions — the grid's own header, which every
            month below shares. */}
        <div className="sticky top-[57px] z-10 grid grid-cols-7 bg-bg-primary px-4 pb-2 pt-1">
          {WEEKDAYS.map((letter, index) => (
            <span
              key={index}
              aria-hidden="true"
              className="type-meta text-center text-text-secondary"
            >
              {letter}
            </span>
          ))}
        </div>

        <div className="space-y-5 px-4 pb-5">
          {months.map((month) => (
            <section key={month.key}>
              <h3 className="mb-2 type-section-header text-text-primary">
                {month.label}
              </h3>
              <div className="grid grid-cols-7 gap-y-1">
                {Array.from({ length: month.leading }, (_, index) => (
                  <span key={`blank-${index}`} aria-hidden="true" />
                ))}
                {month.days.map((day) => {
                  const isSelected = isSameDay(day, selectedDay);
                  const isToday = isSameDay(day, today);
                  return (
                    <button
                      key={dayId(day)}
                      ref={isSelected ? selectedRef : undefined}
                      type="button"
                      onClick={() => {
                        onSelect(day);
                        onOpenChange(false);
                      }}
                      aria-label={dayLongLabel(day)}
                      aria-current={isSelected ? "date" : undefined}
                      className={cn(
                        "mx-auto flex h-9 w-9 items-center justify-center rounded-full type-chip transition-colors",
                        isSelected
                          ? "bg-text-primary text-bg-primary"
                          : isToday
                            ? "text-text-primary underline underline-offset-4"
                            : "text-text-secondary hover:bg-bg-elevated hover:text-text-primary"
                      )}
                    >
                      {day.getDate()}
                    </button>
                  );
                })}
              </div>
            </section>
          ))}
        </div>
      </DialogContent>
    </Dialog>
  );
}

/** Guards against an empty season span producing a zero-month grid. */
export function hasCalendarDays(days: Date[]): boolean {
  return days.length > 0 && addDays(days[0], 0) <= days[days.length - 1];
}
