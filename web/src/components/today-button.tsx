"use client";

// The floating jump home — iOS's Today button (2026-09-06).
//
// It left the day strip because pinned to the strip's trailing edge it cost
// ~70pt of strip on every day but today; floating costs nothing and sits
// where the thumb already is. It **inverts** — ink ground, page-coloured
// text — because it is the one control on the page that *changes* the day
// rather than describing it, the same pairing the selected day chip wears.
//
// It only exists while it has somewhere to go AND today's own chip is off
// the strip; the caller owns that condition (`showsTodayJump`).
//
// It wears whatever the strip's chip wears, the Live filter's "Ongoing"
// included (2026-09-12) — it is the way back to that chip, and a button
// naming a day the chip it lands on doesn't is the same one-word-apart
// problem in reverse.

import { CornerUpLeft } from "lucide-react";

export function TodayButton({
  onClick,
  liveOnly = false,
}: {
  onClick: () => void;
  liveOnly?: boolean;
}) {
  return (
    <div className="pointer-events-none fixed inset-x-0 bottom-16 z-40 flex justify-center sm:bottom-6">
      <button
        type="button"
        onClick={onClick}
        className="pointer-events-auto inline-flex items-center gap-1.5 rounded-full bg-text-primary px-4 py-2 type-chip-em text-bg-primary shadow-lg transition-transform hover:scale-105 active:scale-95"
      >
        <CornerUpLeft aria-hidden="true" className="h-3.5 w-3.5" />
        {liveOnly ? "Ongoing" : "Today"}
      </button>
    </div>
  );
}
