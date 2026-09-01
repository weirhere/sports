"use client";

// Horizontal week selector — the iOS `WeekStrip`, driven entirely by ESPN's
// parsed calendar. Past weeks sit left, future right; postseason slots use
// names. The selected chip is the strip's one piece of filled chrome; the
// rest stay bare text. Desktop adds end chevrons and arrow-key stepping —
// the pointer-accelerator parity for the content swipe.

import { useEffect, useRef } from "react";
import { ChevronLeft, ChevronRight } from "lucide-react";
import type { WeekSlot } from "@/lib/season";
import { cn } from "@/lib/utils";

interface WeekStripProps {
  /** Calendar-derived slots for the selected season, in season order. */
  weeks: WeekSlot[];
  selectedId: string;
  onSelect: (slot: WeekSlot) => void;
}

function compactLabel(slot: WeekSlot): string {
  return slot.shortLabel.replace("Week ", "Wk ");
}

/** Spoken label uses the full "Week 5", not the compact "Wk 5". */
function spokenLabel(slot: WeekSlot): string {
  return slot.label.startsWith("Week") ? slot.label : slot.shortLabel;
}

export function WeekStrip({ weeks, selectedId, onSelect }: WeekStripProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const selectedRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (selectedRef.current && scrollRef.current) {
      const container = scrollRef.current;
      const button = selectedRef.current;
      container.scrollTo({
        left:
          button.offsetLeft - container.offsetWidth / 2 + button.offsetWidth / 2,
        behavior: "smooth",
      });
    }
  }, [selectedId, weeks]);

  const selectedIndex = weeks.findIndex((slot) => slot.id === selectedId);

  const step = (offset: number) => {
    const target = weeks[selectedIndex + offset];
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
      <div className="relative mx-auto max-w-7xl">
        <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-8 bg-gradient-to-r from-bg-recessed to-transparent sm:left-8" />
        <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-8 bg-gradient-to-l from-bg-recessed to-transparent sm:right-8" />

        {/* Desktop chevrons at the strip's ends. */}
        <button
          type="button"
          onClick={() => step(-1)}
          disabled={selectedIndex <= 0}
          aria-label="Previous week"
          className="absolute left-0 top-1/2 z-20 hidden h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full text-text-secondary transition-colors hover:bg-bg-elevated hover:text-text-primary disabled:opacity-30 sm:flex"
        >
          <ChevronLeft className="h-4 w-4" />
        </button>
        <button
          type="button"
          onClick={() => step(1)}
          disabled={selectedIndex === -1 || selectedIndex >= weeks.length - 1}
          aria-label="Next week"
          className="absolute right-0 top-1/2 z-20 hidden h-8 w-8 -translate-y-1/2 items-center justify-center rounded-full text-text-secondary transition-colors hover:bg-bg-elevated hover:text-text-primary disabled:opacity-30 sm:flex"
        >
          <ChevronRight className="h-4 w-4" />
        </button>

        <div
          ref={scrollRef}
          onKeyDown={handleKeyDown}
          className="flex gap-1 overflow-x-auto px-4 py-2 scrollbar-none sm:px-10"
        >
          {weeks.map((slot) => {
            const isSelected = slot.id === selectedId;
            return (
              <button
                key={slot.id}
                ref={isSelected ? selectedRef : undefined}
                onClick={() => onSelect(slot)}
                aria-label={spokenLabel(slot)}
                aria-current={isSelected ? "true" : undefined}
                className={cn(
                  "type-chip shrink-0 rounded-full px-3 py-1.5 whitespace-nowrap transition-colors",
                  isSelected
                    ? "bg-text-primary text-bg-primary"
                    : "text-text-secondary hover:text-text-primary"
                )}
              >
                {compactLabel(slot)}
              </button>
            );
          })}
        </div>
      </div>
    </div>
  );
}
