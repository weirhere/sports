"use client";

// The Gamecast's "this just happened" marker (iOS `LogoPin`): a map pin with
// the team's logo, its point on the spot. The field puts it over the ball,
// the court and rink over the newest shot, and nothing else on the card
// highlights. Shared so the three can't drift.
//
// Positioned by its point: `left`/`top` are where the tip lands, as
// percentages of the surface, so it rides the surface's own scaling.

import { useEffect, useState } from "react";
import { TeamMark } from "../team-mark";
import { cn } from "@/lib/utils";

export const PIN_WIDTH = 26;
export const PIN_HEIGHT = 33;

export function LogoPin({
  logoUrl,
  left,
  top,
  lift = 0,
  moves,
}: {
  logoUrl?: string;
  /** Percent of the surface's width. */
  left: number;
  /** Percent of the surface's height. */
  top: number;
  /** Points to hold the tip above `top` — the field's pin floats over the
   *  turf rather than touching the ball. */
  lift?: number;
  /** Whether a change of spot slides the pin rather than jumping it. */
  moves: boolean;
}) {
  return (
    <div
      aria-hidden="true"
      className={cn(
        "pointer-events-none absolute",
        moves && "transition-[left,top] duration-[600ms] ease-out"
      )}
      style={{
        left: `${left}%`,
        top: `${top}%`,
        width: PIN_WIDTH,
        height: PIN_HEIGHT,
        transform: `translate(-50%, calc(-100% - ${lift}px))`,
      }}
    >
      <svg
        width={PIN_WIDTH}
        height={PIN_HEIGHT}
        viewBox={`0 0 ${PIN_WIDTH} ${PIN_HEIGHT}`}
        className="absolute inset-0 overflow-visible"
      >
        {/* A disc for the logo with a point beneath it. */}
        <path
          d="M 2.35 20.46 A 13 13 0 1 1 23.65 20.46 L 13 33 Z"
          className="fill-bg-card stroke-divider"
          strokeWidth={1}
        />
      </svg>
      {logoUrl && (
        <span className="absolute left-1/2 top-[4.5px] h-[17px] w-[17px] -translate-x-1/2">
          <TeamMark
            logoUrl={logoUrl}
            alt=""
            size={17}
            className="h-[17px] w-[17px] object-contain"
          />
        </span>
      )}
    </div>
  );
}

/**
 * False for the first render, so a card that appears mid-drive (or
 * mid-period) shows the last play already drawn rather than replaying it.
 */
export function useHasAppeared(): boolean {
  const [appeared, setAppeared] = useState(false);
  useEffect(() => {
    const frame = requestAnimationFrame(() => setAppeared(true));
    return () => cancelAnimationFrame(frame);
  }, []);
  return appeared;
}
