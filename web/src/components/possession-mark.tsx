import { cn } from "@/lib/utils";

/**
 * Live possession's quiet marker — a tiny football in the secondary ink.
 * One glyph for the Scores row, the game header and its compact
 * scoreboard, so "who has the ball" reads the same everywhere.
 */
export function PossessionMark({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 12 8"
      aria-hidden="true"
      className={cn("h-2 w-3 shrink-0 fill-text-secondary", className)}
    >
      <ellipse cx="6" cy="4" rx="5.6" ry="3.6" />
    </svg>
  );
}
