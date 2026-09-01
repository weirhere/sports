"use client";

import { useRef, useEffect } from "react";
import { WEEKS } from "@/lib/constants";
import { cn } from "@/lib/utils";

interface WeekSelectorProps {
  selectedWeek: number;
  onWeekChange: (week: number) => void;
  currentWeek?: number;
}

export function WeekSelector({
  selectedWeek,
  onWeekChange,
  currentWeek = 8,
}: WeekSelectorProps) {
  const scrollRef = useRef<HTMLDivElement>(null);
  const selectedRef = useRef<HTMLButtonElement>(null);

  useEffect(() => {
    if (selectedRef.current && scrollRef.current) {
      const container = scrollRef.current;
      const button = selectedRef.current;
      const scrollLeft =
        button.offsetLeft - container.offsetWidth / 2 + button.offsetWidth / 2;
      container.scrollTo({ left: scrollLeft, behavior: "smooth" });
    }
  }, [selectedWeek]);

  return (
    <div className="fixed left-0 right-0 top-14 z-40 bg-background sm:top-16">
      <div className="relative mx-auto max-w-7xl">
        {/* Left fade */}
        <div className="pointer-events-none absolute inset-y-0 left-0 z-10 w-8 bg-gradient-to-r from-background to-transparent" />
        {/* Right fade */}
        <div className="pointer-events-none absolute inset-y-0 right-0 z-10 w-8 bg-gradient-to-l from-background to-transparent" />

        <div
          ref={scrollRef}
          className="flex gap-1 overflow-x-auto px-4 py-2 scrollbar-none"
        >
          {WEEKS.map((week) => (
            <button
              key={week.number}
              ref={week.number === selectedWeek ? selectedRef : undefined}
              onClick={() => onWeekChange(week.number)}
              className={cn(
                "shrink-0 rounded-full px-3 py-1.5 text-xs font-medium transition-colors",
                week.number === selectedWeek
                  ? "bg-primary text-primary-foreground"
                  : "text-muted-foreground hover:bg-accent hover:text-accent-foreground",
                week.number === currentWeek &&
                  week.number !== selectedWeek &&
                  "font-semibold text-foreground"
              )}
            >
              {week.label}
            </button>
          ))}
        </div>
      </div>
    </div>
  );
}
