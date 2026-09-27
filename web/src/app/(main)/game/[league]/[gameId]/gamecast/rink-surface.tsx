// The hockey Gamecast's surface (iOS `RinkSurface`): the whole rink, 200 ×
// 85 feet with 28-foot corners, away shooting right every period. White ice,
// the red lines in the app's one red and the blue lines in gray, so no color
// joins the app for them.

import { useId } from "react";
import type { GameTeam } from "@/lib/types";
import type { ShotMap } from "@/lib/gamecast";
import { ShotMarksLayer } from "./shot-marks";
import { PIN_HEIGHT } from "./logo-pin";

const LENGTH = 200;
const WIDTH = 85;
const RED = "var(--rank-down)";
const BLUE = "var(--surface-blue-line)";

export function RinkSurface({
  map,
  away,
  home,
}: {
  map: ShotMap;
  away: GameTeam;
  home: GameTeam;
}) {
  const clip = useId();
  const line = { fill: "none", strokeWidth: 1, vectorEffect: "non-scaling-stroke" } as const;
  return (
    // Room above for the pin over a shot by the top boards.
    <div aria-hidden="true" style={{ paddingTop: PIN_HEIGHT }}>
      <div className="relative" style={{ aspectRatio: `${LENGTH} / ${WIDTH}` }}>
        <svg
          viewBox={`0 0 ${LENGTH} ${WIDTH}`}
          className="block h-full w-full overflow-visible"
          preserveAspectRatio="none"
        >
          <defs>
            <clipPath id={clip}>
              <rect width={LENGTH} height={WIDTH} rx={28} />
            </clipPath>
          </defs>
          <rect width={LENGTH} height={WIDTH} rx={28} fill="var(--surface-ice)" />
          <g clipPath={`url(#${clip})`}>
            <rect x={99.5} width={1} height={WIDTH} fill={RED} />
            <rect x={74.5} width={1} height={WIDTH} fill={BLUE} />
            <rect x={124.5} width={1} height={WIDTH} fill={BLUE} />
            <g stroke={RED} {...line}>
              <path d={`M 11 0 L 11 ${WIDTH} M 189 0 L 189 ${WIDTH}`} vectorEffect="non-scaling-stroke" />
              {/* End-zone faceoff circles, 15 ft, 22 ft either side of center. */}
              {[31, 169].flatMap((cx) =>
                [20.5, 64.5].map((cy) => (
                  <circle key={`${cx}-${cy}`} cx={cx} cy={cy} r={15} vectorEffect="non-scaling-stroke" />
                ))
              )}
              {/* The creases: half-circles out from each goal line. */}
              <path
                d="M 11 36.5 A 6 6 0 0 1 11 48.5 M 189 36.5 A 6 6 0 0 0 189 48.5"
                vectorEffect="non-scaling-stroke"
              />
            </g>
            <circle cx={100} cy={42.5} r={15} stroke={BLUE} {...line} />
          </g>
          <rect
            width={LENGTH}
            height={WIDTH}
            rx={28}
            fill="none"
            stroke="var(--surface-boards)"
            strokeWidth={1.5}
            vectorEffect="non-scaling-stroke"
          />
        </svg>
        <ShotMarksLayer map={map} width={LENGTH} height={WIDTH} away={away} home={home} />
      </div>
    </div>
  );
}
