"use client";

// The playing surface, portrait, with the away side's unit in the top half
// and the home side's in the bottom, facing each other across the midline —
// away first, the app's order for American sports (iOS `FormationField`,
// Andy, 2026-10-18).
//
// Painted as the place it pictures — turf, maple, ice — with the same
// surface tokens the live Gamecast surfaces use (Andy, 2026-10-18: "use a
// green background like we do on the current drive visual … a beige
// background like the court … hockey is just white like ice"). That widens
// the color budget's fourth exception from live-only to this field too;
// nothing else on the section takes color.

import { useLayoutEffect, useRef, useState } from "react";
import type { League } from "@/lib/leagues";
import type { Team } from "@/lib/types";
import { teamShortName } from "@/lib/game-roster";
import { rowPlayers, type Formation, type FormationRow } from "@/lib/formation";
import { TeamMark } from "../team-mark";
import { FormationSlot } from "./formation-slot";
import { inkAlpha, surfaceInk } from "./surface-ink";

const ROW_HEIGHT = 58;
/** A wing's slot is capped, so the wings sit at the edges and the gap
 *  between them is the field, not a share of it; a crowded wing row gives
 *  the gap up first and spreads evenly like a line. */
const WING_WIDTH = 74;

export function FormationField({
  league,
  top,
  bottom,
  topTeam,
  bottomTeam,
  topLabel,
  bottomLabel,
}: {
  league: League;
  top?: Formation;
  bottom?: Formation;
  topTeam: Team;
  bottomTeam: Team;
  /** "DEN offense" — undefined outside football, where the team is the unit. */
  topLabel?: string;
  bottomLabel?: string;
}) {
  const ink = surfaceInk(league).text;
  return (
    <div className="relative">
      <FieldMarkings league={league} />
      <div className="relative flex flex-col">
        <Half formation={top} team={topTeam} label={topLabel} isTop league={league} ink={ink} />
        <Half formation={bottom} team={bottomTeam} label={bottomLabel} isTop={false} league={league} ink={ink} />
      </div>
    </div>
  );
}

/**
 * One side's rows. Row 0 is the line of engagement, so the top half lists
 * its rows deepest-first and pins them to the midline. The team caption is a
 * strip of its own at the half's far end — it used to float over the deepest
 * row, where "JAX defense" landed on the free safety (Andy, 2026-10-18).
 */
function Half({
  formation,
  team,
  label,
  isTop,
  league,
  ink,
}: {
  formation?: Formation;
  team: Team;
  label?: string;
  isTop: boolean;
  league: League;
  ink: string;
}) {
  const rows = formation?.rows ?? [];
  const ordered = isTop ? [...rows].reverse() : rows;
  const caption = (
    <div
      className="flex items-center gap-1 px-2 py-1"
      style={{ color: inkAlpha(ink, 0.85) }}
    >
      <TeamMark logoUrl={team.logoUrl} alt="" size={14} className="h-3.5 w-3.5 shrink-0" />
      <span className="type-meta">{label ?? teamShortName(team)}</span>
    </div>
  );
  return (
    <div className="flex flex-col py-1">
      {isTop && caption}
      {rows.length === 0 ? (
        <p
          className="flex items-center justify-center type-meta"
          style={{ minHeight: ROW_HEIGHT * 2, color: inkAlpha(ink, 0.85) }}
        >
          Lineup TBA
        </p>
      ) : (
        ordered.map((row, index) => (
          <Row key={index} row={row} team={team} league={league} ink={ink} />
        ))
      )}
      {!isTop && caption}
    </div>
  );
}

function Row({
  row,
  team,
  league,
  ink,
}: {
  row: FormationRow;
  team: Team;
  league: League;
  ink: string;
}) {
  // Off the screen edge, now that the field is on it.
  const base = "flex items-center px-1";
  if (row.kind === "line") {
    return (
      <div className={base} style={{ height: ROW_HEIGHT }}>
        {row.players.map((person) => (
          <FormationSlot key={person.id} person={person} team={team} league={league} ink={ink} />
        ))}
      </div>
    );
  }
  if (rowPlayers(row).length === 0) return null;
  return (
    <div className={base} style={{ height: ROW_HEIGHT }}>
      {row.left.map((person) => (
        <FormationSlot key={person.id} person={person} team={team} league={league} ink={ink} maxWidth={WING_WIDTH} />
      ))}
      <div className="min-w-0 flex-1" />
      {row.right.map((person) => (
        <FormationSlot key={person.id} person={person} team={team} league={league} ink={ink} maxWidth={WING_WIDTH} />
      ))}
    </div>
  );
}

/**
 * The surface itself, as SVG fills and strokes over the surface tokens: turf
 * in alternating ten-yard bands with chalk yard lines and hashes; maple with
 * the keys in the darker paint; ice with its red and blue lines and creases,
 * inside the boards. Each gets the marks that make it recognisable at a
 * glance and no more. Drawn in pixels off the measured box, the
 * `DriveField` way, so strokes and radii stay in points whatever the size.
 */
function FieldMarkings({ league }: { league: League }) {
  const ref = useRef<HTMLDivElement>(null);
  const [size, setSize] = useState({ width: 0, height: 0 });
  useLayoutEffect(() => {
    const node = ref.current;
    if (!node) return;
    const observer = new ResizeObserver(([entry]) =>
      setSize({ width: entry.contentRect.width, height: entry.contentRect.height })
    );
    observer.observe(node);
    return () => observer.disconnect();
  }, []);
  const { width: w, height: h } = size;
  return (
    <div ref={ref} aria-hidden="true" className="absolute inset-0">
      {w > 0 && h > 0 && (
        <svg width={w} height={h} className="block">
          {league === "nba" ? (
            <Court w={w} h={h} />
          ) : league === "nhl" ? (
            <Rink w={w} h={h} />
          ) : (
            <Turf w={w} h={h} />
          )}
        </svg>
      )}
    </div>
  );
}

function Turf({ w, h }: { w: number; h: number }) {
  const step = h / 10;
  const chalk = "var(--surface-chalk)";
  return (
    <g>
      {/* Ten-yard bands either side of the line of scrimmage, alternating
          out from it the way the drive field's do. */}
      {Array.from({ length: 10 }, (_, band) => (
        <rect
          key={band}
          x={0}
          y={step * band}
          width={w}
          height={step + 0.5}
          fill={band % 2 === 0 ? "var(--surface-turf)" : "var(--surface-turf-alt)"}
        />
      ))}
      {/* Faint, the way a broadcast's are: the names are the brightest
          thing on the field, and the lines sit under them. */}
      {[1, 2, 3, 4, 6, 7, 8, 9].map((index) => (
        <line key={index} x1={0} x2={w} y1={step * index} y2={step * index} stroke={chalk} strokeOpacity={0.28} strokeWidth={1} />
      ))}
      <line x1={0} x2={w} y1={h / 2} y2={h / 2} stroke={chalk} strokeOpacity={0.7} strokeWidth={2} />
      {/* Hash marks down the inboard thirds. */}
      {Array.from({ length: 40 }, (_, index) => {
        const y = (h / 40) * (index + 0.5);
        return [0.38, 0.62].map((fraction) => (
          <line
            key={`${index}-${fraction}`}
            x1={w * fraction - 3}
            x2={w * fraction + 3}
            y1={y}
            y2={y}
            stroke={chalk}
            strokeOpacity={0.28}
            strokeWidth={1}
          />
        ));
      })}
    </g>
  );
}

function Court({ w, h }: { w: number; h: number }) {
  const line = { stroke: "var(--surface-chalk)", strokeOpacity: 0.9, fill: "none" } as const;
  const keyWidth = w * 0.3;
  const keyHeight = h * 0.22;
  const x = w / 2 - keyWidth / 2;
  return (
    <g>
      <rect width={w} height={h} fill="var(--surface-maple)" />
      {/* A key at each end, its free-throw circle facing the middle. */}
      {[true, false].map((top) => {
        const y = top ? 0 : h - keyHeight;
        const circleY = top ? keyHeight : h - keyHeight;
        const r = keyWidth / 2;
        const arc = top
          ? `M ${w / 2 - r} ${circleY} A ${r} ${r} 0 0 0 ${w / 2 + r} ${circleY}`
          : `M ${w / 2 - r} ${circleY} A ${r} ${r} 0 0 1 ${w / 2 + r} ${circleY}`;
        return (
          <g key={String(top)}>
            <rect x={x} y={y} width={keyWidth} height={keyHeight} fill="var(--surface-paint)" />
            <rect x={x} y={y} width={keyWidth} height={keyHeight} {...line} strokeWidth={1} />
            <path d={arc} {...line} strokeWidth={1} />
          </g>
        );
      })}
      <line x1={0} x2={w} y1={h / 2} y2={h / 2} {...line} strokeWidth={1.5} />
      <circle cx={w / 2} cy={h / 2} r={24} {...line} strokeWidth={1} />
    </g>
  );
}

function Rink({ w, h }: { w: number; h: number }) {
  const red = "var(--rank-down)";
  const blue = "var(--surface-blue-line)";
  return (
    <g>
      <rect width={w} height={h} fill="var(--surface-ice)" />
      <line x1={0} x2={w} y1={h / 2} y2={h / 2} stroke={red} strokeWidth={2} />
      <line x1={0} x2={w} y1={h * 0.34} y2={h * 0.34} stroke={blue} strokeWidth={1.5} />
      <line x1={0} x2={w} y1={h * 0.66} y2={h * 0.66} stroke={blue} strokeWidth={1.5} />
      <circle cx={w / 2} cy={h / 2} r={24} fill="none" stroke={blue} strokeWidth={1} />
      {[true, false].map((top) => {
        const y = top ? h * 0.07 : h * 0.93;
        const crease = top
          ? `M ${w / 2 - 14} ${y} A 14 14 0 0 0 ${w / 2 + 14} ${y}`
          : `M ${w / 2 - 14} ${y} A 14 14 0 0 1 ${w / 2 + 14} ${y}`;
        return (
          <g key={String(top)}>
            <line x1={0} x2={w} y1={y} y2={y} stroke={red} strokeWidth={1} />
            <path d={crease} fill="none" stroke={red} strokeWidth={1} />
          </g>
        );
      })}
      <rect x={0.75} y={0.75} width={w - 1.5} height={h - 1.5} fill="none" stroke="var(--surface-boards)" strokeWidth={1.5} />
    </g>
  );
}
