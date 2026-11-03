// The baseball Gamecast's surface (iOS `DiamondSurface`, 2026-11-03): the
// infield from behind home plate, the turf's green with the diamond cut into
// it in infield dirt, and the three bags — an occupied one filled in the
// batting team's color. The color budget's fourth exception, drawn only while
// a game is live.

import type { BaseballDiamond } from "@/lib/baseball-gamecast";
import { teamMarkHex } from "@/lib/gamecast";
import type { GameTeam } from "@/lib/types";

const WIDTH = 220;
const HEIGHT = 100;

export function DiamondSurface({
  diamond,
  away,
  home,
}: {
  diamond: BaseballDiamond;
  away: GameTeam;
  home: GameTeam;
}) {
  const batting = diamond.battingSide === "away" ? away : home;
  const runner =
    teamMarkHex(batting.team.color, batting.team.altColor, false) ??
    "var(--surface-mark-fallback)";
  const cx = WIDTH / 2;
  const cy = HEIGHT * 0.52;
  const reach = HEIGHT * 0.4;
  const diamondPoints = (r: number) =>
    `${cx},${cy + r} ${cx + r},${cy} ${cx},${cy - r} ${cx - r},${cy}`;
  const bag = 10;
  const bags: [number, number, boolean][] = [
    [cx + reach, cy, diamond.onFirst],
    [cx, cy - reach, diamond.onSecond],
    [cx - reach, cy, diamond.onThird],
  ];
  const homeY = cy + reach;

  return (
    <div aria-hidden="true" className="overflow-hidden rounded-[6px]">
      <svg viewBox={`0 0 ${WIDTH} ${HEIGHT}`} className="block h-auto w-full">
        <rect width={WIDTH} height={HEIGHT} fill="var(--surface-turf)" />
        <polygon points={diamondPoints(reach * 1.18)} fill="var(--surface-infield-dirt)" />
        <polygon points={diamondPoints(reach * 0.72)} fill="var(--surface-turf)" />
        <g stroke="var(--surface-chalk)" strokeWidth={1.5} strokeOpacity={0.85}>
          <line x1={cx} y1={homeY} x2={cx + WIDTH} y2={homeY - WIDTH} />
          <line x1={cx} y1={homeY} x2={cx - WIDTH} y2={homeY - WIDTH} />
        </g>
        <circle cx={cx} cy={cy} r={reach * 0.16} fill="var(--surface-infield-dirt)" />
        <rect
          x={cx - bag / 3}
          y={homeY - bag / 3}
          width={(bag * 2) / 3}
          height={(bag * 2) / 3}
          fill="var(--surface-chalk)"
        />
        {bags.map(([x, y, occupied], index) => (
          <rect
            key={index}
            x={x - bag / 2}
            y={y - bag / 2}
            width={bag}
            height={bag}
            transform={`rotate(45 ${x} ${y})`}
            fill={occupied ? runner : "var(--surface-chalk)"}
            fillOpacity={occupied ? 1 : 0.35}
            stroke="var(--surface-chalk)"
            strokeWidth={occupied ? 2 : 1.5}
          />
        ))}
      </svg>
    </div>
  );
}
