"use client";

import { useState, useRef, useEffect } from "react";
import { ChevronDown } from "lucide-react";
import { cn } from "@/lib/utils";

interface SeasonSelectorProps {
  selectedYear: number;
  onYearChange: (year: number) => void;
  seasons: number[];
}

export function SeasonSelector({
  selectedYear,
  onYearChange,
  seasons,
}: SeasonSelectorProps) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  // Close on click outside
  useEffect(() => {
    function handleClickOutside(e: MouseEvent) {
      if (ref.current && !ref.current.contains(e.target as Node)) {
        setOpen(false);
      }
    }

    if (open) {
      document.addEventListener("mousedown", handleClickOutside);
      return () =>
        document.removeEventListener("mousedown", handleClickOutside);
    }
  }, [open]);

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((prev) => !prev)}
        className={cn(
          "flex items-center gap-1 rounded-full border px-3 py-1.5 text-xs font-medium transition-colors",
          open
            ? "border-foreground bg-foreground text-background"
            : "border-border text-muted-foreground hover:border-foreground/30 hover:text-foreground"
        )}
      >
        {selectedYear}
        <ChevronDown
          className={cn(
            "h-3 w-3 transition-transform",
            open && "rotate-180"
          )}
        />
      </button>

      {open && (
        <div className="absolute right-0 top-full z-50 mt-1 min-w-[7rem] overflow-hidden rounded-xl border bg-card shadow-lg">
          {seasons.map((year) => (
            <button
              key={year}
              type="button"
              onClick={() => {
                onYearChange(year);
                setOpen(false);
              }}
              className={cn(
                "flex w-full items-center whitespace-nowrap px-4 py-2 text-xs font-medium transition-colors hover:bg-accent/50",
                year === selectedYear
                  ? "bg-accent text-foreground"
                  : "text-muted-foreground"
              )}
            >
              {year}–{String(year + 1).slice(2)}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
