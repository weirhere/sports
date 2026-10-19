"use client";

// The Scores slate control — iOS `ScoresHeader`'s capsule: one menu chip
// reading All games, Live or Tight (`SlateFocusChip`, 2026-10-19), where
// the Live pill and its Tight sibling stood. Two pills took more of the row
// than Andy wanted, and they were already exclusive.
//
// The fills are the pills' (2026-09-12, 2026-09-24): Live wears the live
// tint under its edge with the green dot before the word, because the chip
// IS the live affordance — which is what keeps the budget at three; Tight
// wears an ink wash, since one row doesn't spend the green twice; All games
// paints nothing. `focus` is the selected day's effective filter, not the
// remembered one: off today it is suspended, and the chip says All games.

import { MenuChip } from "@/components/menu-chip";
import {
  SLATE_FOCUSES,
  slateFocusDescription,
  slateFocusTitle,
  type SlateFocus,
} from "@/lib/slate-focus";
import { cn } from "@/lib/utils";

interface ScoresHeaderProps {
  focus: SlateFocus;
  onSelectFocus: (focus: SlateFocus) => void;
}

export function ScoresHeaderControls({ focus, onSelectFocus }: ScoresHeaderProps) {
  return (
    <div className="flex items-center rounded-full bg-bg-elevated p-1">
      <MenuChip
        label={slateFocusTitle(focus)}
        ariaLabel={`Games shown, ${slateFocusTitle(focus)}`}
        isActive={focus !== "all"}
        activeClassName={cn(
          "text-text-primary",
          focus === "live"
            ? "border-live-edge bg-live-tint"
            : "border-text-primary/35 bg-text-primary/10"
        )}
        leading={
          focus === "live" ? (
            <span aria-hidden="true" className="h-2 w-2 shrink-0 rounded-full bg-live" />
          ) : undefined
        }
        options={SLATE_FOCUSES.map((choice) => ({
          id: choice,
          label: slateFocusTitle(choice),
          description: slateFocusDescription(choice),
          onSelect: () => onSelectFocus(choice),
        }))}
      />
      <span id="scores-tight-hint" className="sr-only">
        Tight: live games that are close late, or where the underdog leads
      </span>
    </div>
  );
}
