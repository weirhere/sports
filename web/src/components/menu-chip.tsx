"use client";

// The shared menu capsule behind every pane control — the standings scope,
// the team filter, the poll picker, the season.
//
// One component so the controls that sit in the same strip are the same
// object: same capsule, same chevron, same tap target, same ink rule.
// `isActive` fills it, which is how a *narrowing* control says so — a view
// choice (the same teams, arranged differently) stays quiet.

import { useEffect, useRef, useState } from "react";
import { Check, ChevronsUpDown } from "lucide-react";
import { cn } from "@/lib/utils";

export interface MenuChipOption {
  id: string;
  label: string;
  /** A second line under the label — the Scores focus menu's rows
   *  (2026-10-19), where "Tight" is a coined word. */
  description?: string;
  onSelect: () => void;
}

export function MenuChip({
  label,
  options,
  isActive = false,
  activeClassName,
  leading,
  ariaLabel,
}: {
  label: string;
  options: MenuChipOption[];
  isActive?: boolean;
  /** What an active chip wears instead of the ink fill — the Scores focus
   *  chip's live tint (2026-10-19). */
  activeClassName?: string;
  /** An ornament before the label: the live dot. */
  leading?: React.ReactNode;
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
          "inline-flex min-h-9 items-center gap-1.5 rounded-full border border-transparent px-3 py-1.5 type-chip transition-colors",
          isActive
            ? (activeClassName ?? "bg-text-primary text-bg-primary")
            : "bg-bg-elevated text-text-primary hover:bg-divider"
        )}
      >
        {leading}
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
              aria-current={option.label === label ? "true" : undefined}
              className={cn(
                "flex w-full items-start gap-3 px-3 py-2 text-left type-chip transition-colors hover:bg-bg-header",
                option.label === label
                  ? "text-text-primary"
                  : "text-text-secondary"
              )}
            >
              <span className="min-w-0 flex-1">
                {option.label}
                {option.description && (
                  <span className="block type-meta text-text-secondary">{option.description}</span>
                )}
              </span>
              {/* The check trails (iOS, 2026-10-19), so a row with one
                  lines up with the rows without. */}
              {option.label === label && (
                <Check aria-hidden="true" className="mt-0.5 h-3.5 w-3.5 shrink-0" />
              )}
            </button>
          ))}
        </div>
      )}
    </div>
  );
}
