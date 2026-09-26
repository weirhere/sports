"use client";

// The boundary between the sections that are yours — Following, and every
// conference, league or poll you follow — and the rest of the day's slate
// below them. The iOS `HideAllControl` (sports/Features/Scores/
// HideAllControl.swift; FotMob parity, Andy 2026-09-22).
//
// One click collapses that whole remaining stack to this one line, or brings
// it back. It never touches Following, a followed table, or any accordion's
// own open/closed state, which is what makes it safe to leave on across
// days. Only ever rendered where there's a boundary to draw — see
// `splitAtHideAll`.
//
// A pill that hugs its label and chevron, centered, rather than a row
// spanning the slate (2026-09-25): full width it read as one more section
// header; as a pill it reads as a control over the stack below. Its fill is
// `bg-inset`, one step darker than the page in light mode (2026-09-25) —
// `bg-elevated` there is the page's own grey, and the pill had no edge.

import { ChevronDown, ChevronUp } from "lucide-react";
import {
  hiddenSectionsSummary,
  type GameSection,
} from "@/lib/game-sections";

interface HideAllControlProps {
  /** The sections this control hides, in slate order. */
  others: readonly GameSection[];
  isHidden: boolean;
  onToggle: () => void;
  /** The id of the stack this control shows and hides. */
  controls: string;
}

export function HideAllControl({
  others,
  isHidden,
  onToggle,
  controls,
}: HideAllControlProps) {
  const summary = hiddenSectionsSummary(others);
  const Chevron = isHidden ? ChevronDown : ChevronUp;
  return (
    <div className="flex flex-col items-center gap-1 py-1">
      <button
        type="button"
        onClick={onToggle}
        aria-expanded={!isHidden}
        aria-controls={controls}
        // The caption below is hidden from assistive tech, so the button
        // carries what's behind it — iOS reads the same sentence as the
        // button's value.
        aria-label={
          isHidden ? `Show all sections, ${summary}` : "Hide all sections"
        }
        className="type-chip-em inline-flex items-center gap-2 rounded-full bg-bg-inset px-4 py-2.5 text-text-primary transition-[filter] hover:brightness-95 dark:hover:brightness-125"
      >
        {isHidden ? "Show all" : "Hide all"}
        <Chevron aria-hidden="true" strokeWidth={2.5} className="h-3 w-3" />
      </button>
      {/* Named so a hidden stack never reads as gone for good — what's
          behind it is the whole reason this isn't an empty tap target
          (FotMob's "22 other competitions play today"). */}
      {isHidden && (
        <p
          aria-hidden="true"
          className="type-meta px-4 text-center text-text-secondary"
        >
          {summary}
        </p>
      )}
    </div>
  );
}
