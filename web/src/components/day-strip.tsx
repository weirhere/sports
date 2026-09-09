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
    <div className="fixed left-0 right-0 top-14 z-40 bg-bg-recessed sm:top-16">
      {/* The strip steps past the follow rail's column so its chips and
          end chevrons start where the games do (#112) — it's fixed chrome,
          but it belongs to the slate. `--page-max` and `--sidebar-w` are
          set by AppShell and globals.css, one source of truth. */}
      <div className="mx-auto flex max-w-[var(--page-max)] items-center lg:pl-[calc(var(--sidebar-w)+var(--sidebar-gap))]">
        <div className="relative min-w-0 flex-1">
          <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-8 bg-gradient-to-r from-bg-recessed to-transparent sm:left-8" />
          <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-8 bg-gradient-to-l from-bg-recessed to-transparent" />

          {/* Desktop chevrons — the pointer accelerator for the content swipe. */}
          <button
            type="button"
            onClick={() => step(-1)}
            disabled={selectedIndex <= 0}
            aria-label="Previous day"
            className="absolute left-0 top-1/2 z-20 hidden h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full text-text-secondary transition-colors hover:bg-bg-elevated hover:text-text-primary disabled:opacity-30 sm:flex"
          >
            <ChevronLeft className="h-4 w-4" />
          </button>
          <button
            type="button"
            onClick={() => step(1)}
            disabled={selectedIndex === -1 || selectedIndex >= days.length - 1}
            aria-label="Next day"
            className="absolute right-0 top-1/2 z-20 hidden h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full text-text-secondary transition-colors hover:bg-bg-elevated hover:text-text-primary disabled:opacity-30 sm:flex"
          >
            <ChevronRight className="h-4 w-4" />
          </button>

          <div
            ref={scrollRef}
            onKeyDown={handleKeyDown}
            className="flex gap-1 overflow-x-auto px-4 py-2 scrollbar-none sm:px-10"
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

        {/* The calendar is a jump-to beside the axis, never a replacement
            for it: dragging is fine for the fortnight either side of today
            and hopeless for "the Iron Bowl in November". */}
        <button
          type="button"
          onClick={onOpenCalendar}
          aria-label="Pick a date"
          className="mr-2 flex h-8 w-8 shrink-0 items-center justify-center rounded-full text-text-secondary transition-colors hover:bg-bg-elevated hover:text-text-primary sm:mr-4"
        >
          <CalendarDays className="h-4 w-4" />
        </button>
      </div>
    </div>
  );
}
