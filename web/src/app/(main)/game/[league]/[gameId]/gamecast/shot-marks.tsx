"use client";

// A period's shots over a court or rink (iOS `ShotMarksLayer`). Shape says
// what happened and color says whose: filled for a make or a shot on goal, a
// ring for a miss, a cross for a block, a larger disc for a goal. The newest
// shot scales in over 0.6s with the pin moving onto it, the field's timing;
// a card that appears mid-period shows its state without replaying it.
//
// Marks are sized in points, not surface units, so a shot reads the same on
// the court and the rink even though the two scale differently: each sits in
// a nested <svg> placed by percentage, drawn around its own origin.

import { useState, type ReactNode } from "react";
import type { GameTeam } from "@/lib/types";
import {
  teamMarkHex,
  type ShotMap,
  type ShotMark,
} from "@/lib/gamecast";
import { LogoPin, useHasAppeared } from "./logo-pin";

export function ShotMarksLayer({
  map,
  width,
  height,
  away,
  home,
}: {
  map: ShotMap;
  /** The surface's size in its own units: 94 × 50, 200 × 85. */
  width: number;
  height: number;
  away: GameTeam;
  home: GameTeam;
}) {
  const appeared = useHasAppeared();
  // Court and ice are light in both modes, so a mark asks for the color that
  // reads on a light ground whatever the page is doing.
  const color = (mark: ShotMark) => {
    const team = (mark.side === "away" ? away : home).team;
    return (
      teamMarkHex(team.color, team.altColor, false) ??
      "var(--surface-mark-fallback)"
    );
  };
  const latest = map.marks[map.marks.length - 1];
  const left = (mark: ShotMark) => (mark.x / width) * 100;
  const top = (mark: ShotMark) => (mark.y / height) * 100;

  return (
    <>
      <svg
        aria-hidden="true"
        className="pointer-events-none absolute inset-0 h-full w-full overflow-visible"
      >
        {map.marks.map((mark) => (
          <svg
            key={mark.id}
            x={`${left(mark)}%`}
            y={`${top(mark)}%`}
            overflow="visible"
          >
            <Grows onMount={mark === latest && appeared}>
              <Mark outcome={mark.outcome} color={color(mark)} />
            </Grows>
          </svg>
        ))}
      </svg>
      {latest && (
        <LogoPin
          logoUrl={(latest.side === "away" ? away : home).team.logoUrl}
          left={left(latest)}
          top={top(latest)}
          moves={appeared}
        />
      )}
    </>
  );
}

/** Scales its mark in when it arrived after the card was already showing.
 *  Decided once, at mount: a mark that was on the first frame never
 *  replays, and one that stops being the newest doesn't shrink back. */
function Grows({ onMount, children }: { onMount: boolean; children: ReactNode }) {
  const [grows] = useState(onMount);
  return <g className={grows ? "gamecast-grow" : undefined}>{children}</g>;
}

function Mark({ outcome, color }: { outcome: ShotMark["outcome"]; color: string }) {
  switch (outcome) {
    case "made":
      return (
        <circle r={3.4} fill={color} stroke="var(--surface-chalk)" strokeWidth={1} />
      );
    case "goal":
      return (
        <circle r={5.4} fill={color} stroke="var(--surface-chalk)" strokeWidth={1.5} />
      );
    case "missed":
      return <circle r={2.8} fill="none" stroke={color} strokeWidth={1.5} />;
    case "blocked":
      return (
        <path
          d="M -2.8 -2.8 L 2.8 2.8 M 2.8 -2.8 L -2.8 2.8"
          stroke={color}
          strokeWidth={1.5}
          strokeLinecap="round"
        />
      );
  }
}
