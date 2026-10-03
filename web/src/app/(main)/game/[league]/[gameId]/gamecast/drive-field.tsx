"use client";

// ESPN's Gamecast field (iOS `DriveField`): the current drive drawn where it
// happened. A trail from the drive's first snap to where the last play
// began, the last play over it — straight on the ground, an arc through the
// air — the offense's logo pinned above the ball, and the line to gain.
//
// Laid out in a 360 × 85.5 unit space scaled to the card's width, so the
// field keeps its proportions on every screen: 10-yard end zones and 100
// yards of turf at 3 units a yard, the away end zone on the left to match
// the header's logo order. Strokes, the arrowhead and the pin stay in
// points, which is why the width is measured rather than left to a viewBox.
// The turf is the color budget's fourth exception.

import { useId, useLayoutEffect, useRef, useState } from "react";
import type { GameSituationField, GameTeam } from "@/lib/types";
import { teamMarkHex } from "@/lib/gamecast";
import { cn } from "@/lib/utils";
import { LogoPin, useHasAppeared } from "./logo-pin";

const WIDTH = 360;
const TURF_TOP = 40;
const TURF_HEIGHT = 27.5;
const HEIGHT = 85.5;
const MIDLINE = TURF_TOP + TURF_HEIGHT / 2;

/** Yards from the away goal line to units from the left edge. */
const x = (yard: number) => 30 + 3 * yard;

export function DriveField({
  field,
  away,
  home,
  offenseLogoUrl,
  playId,
}: {
  field: GameSituationField;
  away: GameTeam;
  home: GameTeam;
  offenseLogoUrl?: string;
  /** A new id draws the new play in; the same id, polled again, is left
   *  alone. */
  playId?: string;
}) {
  const ref = useRef<HTMLDivElement>(null);
  const [width, setWidth] = useState(0);
  const appeared = useHasAppeared();
  const clip = useId();

  useLayoutEffect(() => {
    const node = ref.current;
    if (!node) return;
    const observer = new ResizeObserver(([entry]) =>
      setWidth(entry.contentRect.width)
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, []);

  const s = width / WIDTH;
  const labelTop = ((TURF_TOP + TURF_HEIGHT + 11) / HEIGHT) * 100;
  const pct = (units: number) => (units / WIDTH) * 100;

  return (
    // The card's own label already speaks the down, the spot and the drive;
    // the drawing repeats it.
    <div
      ref={ref}
      aria-hidden="true"
      className="relative w-full"
      style={{ aspectRatio: `${WIDTH} / ${HEIGHT}` }}
    >
      {width > 0 && (
        <svg
          width={width}
          height={HEIGHT * s}
          className="absolute inset-0 overflow-visible"
        >
          <defs>
            <clipPath id={clip}>
              <rect y={TURF_TOP * s} width={WIDTH * s} height={TURF_HEIGHT * s} rx={6} />
            </clipPath>
          </defs>
          <Turf s={s} clip={clip} away={away} home={home} />
          <Marks s={s} field={field} />
          {field.playStart !== undefined &&
            Math.abs(field.playStart - field.ball) >= 0.5 && (
              <PlayArrow
                key={playId}
                from={{ x: x(field.playStart) * s, y: MIDLINE * s }}
                to={{ x: x(field.ball) * s, y: MIDLINE * s }}
                isPass={field.isPass}
                peak={
                  // Longer throws arc higher, capped so a bomb stays on the card.
                  Math.min(34, 10 + Math.abs(x(field.ball) - x(field.playStart)) * 0.35) * s
                }
                animates={appeared}
              />
            )}
        </svg>
      )}
      <Label left={pct(15)} top={labelTop} emphasized>
        {away.team.abbreviation}
      </Label>
      <Label left={pct(x(20))} top={labelTop}>20</Label>
      <Label left={pct(x(50))} top={labelTop}>50</Label>
      <Label left={pct(x(80))} top={labelTop}>20</Label>
      <Label left={pct(345)} top={labelTop} emphasized>
        {home.team.abbreviation}
      </Label>
      <LogoPin
        logoUrl={offenseLogoUrl}
        left={pct(x(field.ball))}
        top={(TURF_TOP / HEIGHT) * 100}
        lift={2}
        moves={appeared}
      />
    </div>
  );
}

function Turf({
  s,
  clip,
  away,
  home,
}: {
  s: number;
  clip: string;
  away: GameTeam;
  home: GameTeam;
}) {
  const top = TURF_TOP * s;
  const h = TURF_HEIGHT * s;
  const chalk = (at: number, opacity: number, width: number) => (
    <line
      key={`${at}-${width}`}
      x1={at * s}
      x2={at * s}
      y1={top}
      y2={top + h}
      stroke="var(--surface-chalk)"
      strokeOpacity={opacity}
      strokeWidth={width}
    />
  );
  return (
    <g clipPath={`url(#${clip})`}>
      <EndZone side={away} x={0} y={top} width={30 * s} height={h} />
      <EndZone side={home} x={330 * s} y={top} width={30 * s} height={h} />
      {Array.from({ length: 10 }, (_, band) => (
        <rect
          key={band}
          x={(30 + 30 * band) * s}
          y={top}
          width={30 * s}
          height={h}
          fill={band % 2 === 0 ? "var(--surface-turf)" : "var(--surface-turf-alt)"}
        />
      ))}
      {[10, 20, 30, 40, 60, 70, 80, 90].map((yard) => chalk(x(yard), 0.45, 1))}
      {[30, 180, 330].map((edge) => chalk(edge, 0.9, 1.5))}
    </g>
  );
}

/** Each end zone in its team's color: the primary unless it would vanish
 *  against the page, then the alternate, then gray. Picked per mode. */
function EndZone({
  side,
  ...rect
}: {
  side: GameTeam;
  x: number;
  y: number;
  width: number;
  height: number;
}) {
  const fallback = "var(--surface-mark-fallback)";
  const light = teamMarkHex(side.team.color, side.team.altColor, false) ?? fallback;
  const dark = teamMarkHex(side.team.color, side.team.altColor, true) ?? fallback;
  return (
    <rect
      {...rect}
      className="gamecast-team-mark"
      style={{ "--mark-light": light, "--mark-dark": dark } as React.CSSProperties}
    />
  );
}

/** The line to gain, the trail and the drive's first snap. */
function Marks({ s, field }: { s: number; field: GameSituationField }) {
  const trailTo = field.playStart ?? field.ball;
  return (
    <g>
      {field.lineToGain !== undefined && (
        <line
          x1={x(field.lineToGain) * s}
          x2={x(field.lineToGain) * s}
          y1={(TURF_TOP - 3) * s}
          y2={(TURF_TOP + TURF_HEIGHT + 3) * s}
          stroke="var(--surface-line-to-gain)"
          strokeWidth={2}
        />
      )}
      {field.driveStart !== undefined && (
        <>
          {Math.abs(x(trailTo) - x(field.driveStart)) >= 0.5 && (
            <line
              x1={x(field.driveStart) * s}
              x2={x(trailTo) * s}
              y1={MIDLINE * s}
              y2={MIDLINE * s}
              stroke="var(--surface-chalk)"
              strokeWidth={2}
              strokeLinecap="round"
            />
          )}
          <circle
            cx={x(field.driveStart) * s}
            cy={MIDLINE * s}
            r={3.2 * s}
            fill="var(--surface-chalk)"
            stroke="var(--surface-ink)"
            strokeWidth={1.5}
          />
        </>
      )}
    </g>
  );
}

interface Point {
  x: number;
  y: number;
}

/** The last play: drawn in over 0.6s when it's new, with its arrowhead
 *  landing as the line arrives. Whether it animates is decided at mount,
 *  so a poll that re-renders it never replays it. */
function PlayArrow({
  from,
  to,
  isPass,
  peak,
  animates: animatesOnMount,
}: {
  from: Point;
  to: Point;
  isPass: boolean;
  peak: number;
  animates: boolean;
}) {
  const [animates] = useState(animatesOnMount);
  const control = { x: (from.x + to.x) / 2, y: from.y - 2 * peak };
  const d = isPass
    ? `M ${from.x} ${from.y} Q ${control.x} ${control.y} ${to.x} ${to.y}`
    : `M ${from.x} ${from.y} L ${to.x} ${to.y}`;
  // The direction of travel as the line arrives — along the ground, or down
  // the arc's last stretch.
  const origin = isPass ? control : from;
  const angle = (Math.atan2(to.y - origin.y, to.x - origin.x) * 180) / Math.PI;
  return (
    <g>
      <path
        d={d}
        pathLength={1}
        fill="none"
        stroke="var(--surface-ink)"
        strokeWidth={2}
        strokeLinecap="round"
        className={cn(animates && "gamecast-draw")}
      />
      {/* Points right, tip on the ball; rotated to the play's direction. */}
      <polygon
        points="0,0 -8,-4 -8,4"
        fill="var(--surface-ink)"
        transform={`translate(${to.x} ${to.y}) rotate(${angle})`}
        className={cn(animates && "gamecast-head-in")}
      />
    </g>
  );
}

function Label({
  left,
  top,
  emphasized = false,
  children,
}: {
  left: number;
  top: number;
  emphasized?: boolean;
  children: React.ReactNode;
}) {
  return (
    <span
      className={cn(
        "absolute -translate-x-1/2 -translate-y-1/2 whitespace-nowrap tnum",
        emphasized
          ? "type-row-meta-medium text-text-primary"
          : "type-row-meta text-text-secondary"
      )}
      style={{ left: `${left}%`, top: `${top}%` }}
    >
      {children}
    </span>
  );
}
