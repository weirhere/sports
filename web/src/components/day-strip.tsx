"use client";

// The day strip — the Scores screen's axis since the leagues stopped sharing
// a calendar (iOS, 2026-09-05). A port of `DayStrip`.
//
// A week strip can only ever be honest about one league: college football's
// Week 2 and the NFL's are different date ranges, and college football's
// single "Bowls" slot swallows four NFL playoff rounds whole. A day is the
// only unit every league agrees on, and the one every future sport will.
//
// Chips carry their month — "Sun, Sep 27" — because the strip spans a season
// that crosses a year boundary, so a bare "Sat 5" stops meaning anything
// once you drag past the fortnight either side of today. Yesterday and
// tomorrow get their names beside today's.
//
// It renders as a row inside `ScoresControlCard` rather than as fixed chrome
// of its own (2026-09-10). It was `position: fixed`, inset past the follow
// rail's column so its chips began where the games did — which left the
// rail's width of dead air to its left and pushed the whole grid down by the
// strip's height. Housed in the card it is the slate column's own first row,
// and the rail top-aligns to it.

import { useEffect, useRef } from "react";
import { CalendarDays, ChevronLeft, ChevronRight } from "lucide-react";
import { dayChipLabel, dayId, dayLongLabel } from "@/lib/day";
import { cn } from "@/lib/utils";

interface DayStripProps {
  /** Every day of the selected season, in order. */
  days: Date[];
  selectedDay: Date;
  onSelect: (day: Date) => void;
  onOpenCalendar: () => void;
}

export function DayStrip({
  days,
  selectedDay,
  onSelect,
  onOpenCalendar,
}: DayStripProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const selectedRef = useRef<HTMLButtonElement>(null);
  const selectedId = dayId(selectedDay);
  const selectedIndex = days.findIndex((day) => dayId(day) === selectedId);
  // The first scroll jumps; every later one animates. Landing mid-season
  // with a smooth scroll would sweep the whole strip past the eye.
  const hasScrolled = useRef(false);

  useEffect(() => {
    const container = scrollRef.current;
    const button = selectedRef.current;
    if (!container || !button) return;
    container.scrollTo({
      left:
        button.offsetLeft - container.offsetWidth / 2 + button.offsetWidth / 2,
      behavior: hasScrolled.current ? "smooth" : "auto",
    });
    hasScrolled.current = true;
  }, [selectedId, days.length]);

  const step = (offset: number) => {
    const target = days[selectedIndex + offset];
    // Season ends are a quiet no-op.
    if (target !== undefined) onSelect(target);
  };

  const handleKeyDown = (event: React.KeyboardEvent) => {
    if (event.key === "ArrowLeft") {
      event.preventDefault();
      step(-1);
    } else if (event.key === "ArrowRight") {
      event.preventDefault();
      step(1);
    }
  };

  return (
    <div className="flex items-center gap-0.5 px-2 py-2">
      {/* Desktop chevrons — the pointer accelerator for the content swipe. */}
      <StepButton
        direction="previous"
        onClick={() => step(-1)}
        disabled={selectedIndex <= 0}
      />

      <div className="relative min-w-0 flex-1">
        {/* The scroller runs under its own edges, so the chips fade out
            rather than being sliced off mid-word. */}
        <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-6 bg-gradient-to-r from-bg-card to-bg-card/0" />
        <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-6 bg-gradient-to-l from-bg-card to-bg-card/0" />

        <div
          ref={scrollRef}
          onKeyDown={handleKeyDown}
          className="flex gap-1 overflow-x-auto px-1 scrollbar-none"
        >
          {days.map((day) => {
            const id = dayId(day);
            const isSelected = id === selectedId;
            return (
              <button
                key={id}
                ref={isSelected ? selectedRef : undefined}
                onClick={() => onSelect(day)}
                aria-label={dayLongLabel(day)}
                aria-current={isSelected ? "true" : undefined}
                className={cn(
                  "type-chip shrink-0 whitespace-nowrap rounded-full px-3 py-1.5 transition-colors",
                  isSelected
                    ? "bg-text-primary text-bg-primary"
                    : "text-text-secondary hover:text-text-primary"
                )}
              >
                {dayChipLabel(day)}
              </button>
            );
          })}
        </div>
      </div>

      <StepButton
        direction="next"
        onClick={() => step(1)}
        disabled={selectedIndex === -1 || selectedIndex >= days.length - 1}
      />

      {/* The calendar is a jump-to beside the axis, never a replacement
          for it: dragging is fine for the fortnight either side of today
          and hopeless for "the Iron Bowl in November". */}
      <button
        type="button"
        onClick={onOpenCalendar}
        aria-label="Pick a date"
        className="flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-text-secondary transition-colors hover:bg-bg-elevated hover:text-text-primary"
      >
        <CalendarDays className="h-4 w-4" />
      </button>
    </div>
  );
}

/**
 * One day either way. Pointer-only: the chips themselves are the keyboard
 * and screen-reader path through the season, so nothing here is gated on a
 * control a touch user can't see.
 */
function StepButton({
  direction,
  onClick,
  disabled,
}: {
  direction: "previous" | "next";
  onClick: () => void;
  disabled: boolean;
}) {
  const Icon = direction === "previous" ? ChevronLeft : ChevronRight;
  return (
    <button
      type="button"
      onClick={onClick}
      disabled={disabled}
      aria-label={direction === "previous" ? "Previous day" : "Next day"}
      className="hidden h-8 w-8 shrink-0 items-center justify-center rounded-full text-text-secondary transition-colors hover:bg-bg-elevated hover:text-text-primary disabled:pointer-events-none disabled:opacity-30 sm:flex"
    >
      <Icon className="h-4 w-4" />
    </button>
  );
}
