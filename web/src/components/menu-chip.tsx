"use client";

// The shared menu capsule behind every pane control — the standings scope,
// the team filter, the poll picker, the season.
//
// One component so the controls that sit in the same strip are the same
// object: same capsule, same chevron, same tap target, same ink rule.
// `isActive` fills it, which is how a *narrowing* control says so — a view
// choice (the same teams, arranged differently) stays quiet.

import { useEffect, useRef, useState } from "react";
import { ChevronsUpDown } from "lucide-react";
import { cn } from "@/lib/utils";

export interface MenuChipOption {
  id: string;
  label: string;
  onSelect: () => void;
}

export function MenuChip({
  label,
  options,
  isActive = false,
  ariaLabel,
}: {
  label: string;
  options: MenuChipOption[];
  isActive?: boolean;
  ariaLabel?: string;
}) {
  const [open, setOpen] = useState(false);
  const ref = useRef<HTMLDivElement>(null);

  useEffect(() => {
    if (!open) return;
    const onDown = (event: MouseEvent) => {
      if (!ref.current?.contains(event.target as Node)) setOpen(false);
    };
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };
    document.addEventListener("mousedown", onDown);
    document.addEventListener("keydown", onKey);
    return () => {
      document.removeEventListener("mousedown", onDown);
      document.removeEventListener("keydown", onKey);
    };
  }, [open]);

  return (
    <div ref={ref} className="relative">
      <button
        type="button"
        onClick={() => setOpen((was) => !was)}
        aria-haspopup="menu"
        aria-expanded={open}
        aria-label={ariaLabel}
        className={cn(
          "inline-flex min-h-9 items-center gap-1.5 rounded-full px-3 py-1.5 type-chip transition-colors",
          isActive
            ? "bg-text-primary text-bg-primary"
            : "bg-bg-elevated text-text-primary hover:bg-divider"
        )}
      >
        <span className="whitespace-nowrap">{label}</span>
        <ChevronsUpDown aria-hidden="true" className="h-3 w-3 shrink-0" />
      </button>

      {open && (
        <div
          role="menu"
          className="absolute right-0 z-30 mt-1 min-w-[10rem] overflow-hidden rounded-[10px] border border-divider bg-bg-card py-1 shadow-lg"
        >
          {options.map((option) => (
            <button
              key={option.id}
              type="button"
              role="menuitem"
              onClick={() => {
                option.onSelect();
                setOpen(false);
              }}
              className={cn(
                "block w-full px-3 py-2 text-left type-chip transition-colors hover:bg-bg-header",
                option.label === label
                  ? "text-text-primary"
                  : "text-text-secondary"
              )}
            >
              {option.label}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
