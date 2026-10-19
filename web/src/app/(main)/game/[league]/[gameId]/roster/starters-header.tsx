"use client";

// The Starters section's title row, in both of its layouts (iOS
// `StartersHeader`): the title (and, under it, which side is only
// projected), with the Field / List chips trailing — on the section itself,
// because the field is what you are looking at when you decide you'd rather
// have the list (Andy, 2026-10-18). On the field the row sits on the
// surface's paint in its ink; over the list cards it sits on the page in the
// page's. It pads itself only sideways: the 8px above and below it is the
// container's, once, not the row's own on top of theirs.

import type { League } from "@/lib/leagues";
import type { SurfaceInk } from "@/components/slate-control-row";
import { SlateToggleChip } from "@/components/slate-control-row";
import type { StartersLayout } from "@/lib/hooks/use-starters-layout";
import {
  startersSubtitle,
  startersTitle,
  surfaceName,
  type GameRoster,
} from "@/lib/game-roster";
import { inkAlpha } from "./surface-ink";

export function StartersHeader({
  roster,
  league,
  layout,
  onLayoutChange,
  ink,
}: {
  roster: GameRoster;
  league: League;
  layout: StartersLayout;
  onLayoutChange: (layout: StartersLayout) => void;
  /** Set on the painted field; undefined over the list cards. */
  ink?: SurfaceInk;
}) {
  const subtitle = startersSubtitle(roster);
  const surface = surfaceName(league);
  return (
    <div className="flex items-baseline gap-2 px-4">
      <div className="min-w-0 flex-1">
        <h3
          className="type-section-header"
          style={{ color: ink?.text ?? "var(--text-primary)" }}
        >
          {startersTitle(roster)}
        </h3>
        {subtitle && (
          <p
            className="type-meta"
            style={{ color: ink ? inkAlpha(ink.text, 0.75) : "var(--text-secondary)" }}
          >
            {subtitle}
          </p>
        )}
      </div>
      <div className="flex items-center gap-1" role="group" aria-label="Starters layout">
        <SlateToggleChip
          title={surface}
          isOn={layout === "field"}
          hint={`Draws the starters on the ${surface.toLowerCase()}`}
          ink={ink}
          onToggle={() => onLayoutChange("field")}
        />
        <SlateToggleChip
          title="List"
          isOn={layout === "list"}
          hint="Lists the starters in cards"
          ink={ink}
          onToggle={() => onLayoutChange("list")}
        />
      </div>
    </div>
  );
}
