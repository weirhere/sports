"use client";

// The season picker — iOS `SeasonMenuChip` (Theme/SeasonMenuChip.swift): a
// capsule chip opening a menu of seasons, newest first, floored at the 2014
// CFP era (the caller passes `seasonYears()`). Trailing-aligned above the
// first card of the tab pane it scopes.

import { useEffect, useRef, useState } from "react";
import { ChevronsUpDown } from "lucide-react";
import { cn } from "@/lib/utils";

interface SeasonMenuChipProps {
  value: number;
  /** Selectable seasons, newest first (`seasonYears()`). */
  years: number[];
  onSelect: (year: number) => void;
}

export function SeasonMenuChip({ value, years, onSelect }: SeasonMenuChipProps) {
  const [open, setOpen] = useState(false);
  const rootRef = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onPointerDown = (event: MouseEvent | TouchEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onPointerDown);
    document.addEventListener("touchstart", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("mousedown", onPointerDown);
      document.removeEventListener("touchstart", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  return (
    <div ref={rootRef} className="relative inline-flex">
      <button
        type="button"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-label={`Season, ${value}`}
        onClick={() => setOpen((was) => !was)}
        className="inline-flex items-center gap-1 rounded-full bg-bg-elevated px-3 py-2 type-chip text-text-primary transition-colors hover:bg-divider"
      >
        <span className="tnum">{value}</span>
        <ChevronsUpDown aria-hidden="true" className="h-3 w-3" />
      </button>
      {open && (
        <ul
          role="listbox"
          aria-label="Season"
          className="absolute right-0 top-full z-20 mt-1 max-h-72 min-w-24 overflow-y-auto py-1 card-surface border border-divider"
        >
          {years.map((year) => {
            const isSelected = year === value;
            return (
              <li key={year} role="presentation">
                <button
                  type="button"
                  role="option"
                  aria-selected={isSelected}
                  onClick={() => {
                    setOpen(false);
                    if (!isSelected) onSelect(year);
                  }}
                  className={cn(
                    "block w-full px-4 py-1.5 text-left tnum transition-colors hover:bg-bg-header",
                    isSelected
                      ? "type-chip-em text-text-primary"
                      : "type-chip text-text-primary"
                  )}
                >
                  {year}
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
