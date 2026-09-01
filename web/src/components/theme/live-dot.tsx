import { cn } from "@/lib/utils";

interface LiveDotProps {
  className?: string;
}

/**
 * The live indicator dot: 6px, live-accent green (the app carries one
 * green — live shares rank-up's token), pulsing opacity 1 -> 0.25.
 * The pulse keyframes live in globals.css (`.live-dot`) and are held
 * steady under prefers-reduced-motion. Decorative only — surfaces that
 * need "live" spoken carry their own accessible text.
 */
export function LiveDot({ className }: LiveDotProps) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        "live-dot inline-block h-1.5 w-1.5 shrink-0 rounded-full bg-live",
        className
      )}
    />
  );
}
