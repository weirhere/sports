// The basketball Gamecast's surface (iOS `CourtSurface`): the whole court,
// landscape, 94 × 50 feet, home shooting at the left basket and away at the
// right. Maple with the keys a shade darker and chalk lines — the color
// budget's fourth exception, drawn only while a game is live.

import type { GameTeam } from "@/lib/types";
import type { ShotMap } from "@/lib/gamecast";
import { ShotMarksLayer } from "./shot-marks";
import { PIN_HEIGHT } from "./logo-pin";

const LENGTH = 94;
const WIDTH = 50;

export function CourtSurface({
  map,
  away,
  home,
}: {
  map: ShotMap;
  away: GameTeam;
  home: GameTeam;
}) {
  return (
    // Room above for the pin over a shot on the top sideline.
    <div aria-hidden="true" style={{ paddingTop: PIN_HEIGHT }}>
      <div className="relative" style={{ aspectRatio: `${LENGTH} / ${WIDTH}` }}>
        {/* The court's corners, not the pin's: the clip stops at the court. */}
        <div className="absolute inset-0 overflow-hidden rounded-[6px]">
          <svg
            viewBox={`0 0 ${LENGTH} ${WIDTH}`}
            className="block h-full w-full"
            preserveAspectRatio="none"
          >
            <rect width={LENGTH} height={WIDTH} fill="var(--surface-maple)" />
            <End mirrored={false} />
            <End mirrored />
            <g
              fill="none"
              stroke="var(--surface-chalk)"
              strokeWidth={1.5}
              vectorEffect="non-scaling-stroke"
            >
              <rect width={LENGTH} height={WIDTH} vectorEffect="non-scaling-stroke" />
              <path
                d={`M ${LENGTH / 2} 0 L ${LENGTH / 2} ${WIDTH}`}
                vectorEffect="non-scaling-stroke"
              />
              <circle cx={LENGTH / 2} cy={25} r={6} vectorEffect="non-scaling-stroke" />
            </g>
          </svg>
        </div>
        <ShotMarksLayer map={map} width={LENGTH} height={WIDTH} away={away} home={home} />
      </div>
    </div>
  );
}

/** One end, drawn in basket-left coordinates and mirrored for the other. */
function End({ mirrored }: { mirrored: boolean }) {
  const x = (v: number) => (mirrored ? LENGTH - v : v);
  // The three-point line: straight in the corners, 22 ft out, then an arc
  // 23.75 ft from the rim.
  const sweep = mirrored ? 0 : 1;
  const three = `M ${x(0)} 3 L ${x(14.2)} 3 A 23.75 23.75 0 0 ${sweep} ${x(14.2)} 47 L ${x(0)} 47`;
  return (
    <>
      <rect
        x={Math.min(x(0), x(19))}
        y={17}
        width={19}
        height={16}
        fill="var(--surface-paint)"
      />
      <g fill="none" stroke="var(--surface-chalk)" strokeWidth={1}>
        <rect
          x={Math.min(x(0), x(19))}
          y={17}
          width={19}
          height={16}
          vectorEffect="non-scaling-stroke"
        />
        <circle cx={x(19)} cy={25} r={6} vectorEffect="non-scaling-stroke" />
        <path d={three} vectorEffect="non-scaling-stroke" />
        <path d={`M ${x(4)} 22 L ${x(4)} 28`} vectorEffect="non-scaling-stroke" />
        <circle cx={x(5.25)} cy={25} r={0.75} vectorEffect="non-scaling-stroke" />
      </g>
    </>
  );
}
