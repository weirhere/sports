"use client";

// The Overview's season in four numbers — iOS `StatTilesCard` as TeamPage
// uses it (2026-09-24). The whole card opens the Stats tab, where the rest
// of the numbers live; the chevron in its header says so.
//
// The headline registry is per league and keyed on ESPN's stat names
// (`teamStatHeadlines`), so a stat ESPN didn't send is a tile that isn't
// drawn rather than a dash.

import { use } from "react";
import { ChevronRight } from "lucide-react";
import type { League } from "@/lib/leagues";
import {
  teamStatHeadlines,
  type TeamSeasonStats,
} from "@/lib/espn/team-stats";

interface SeasonStatsCardProps {
  league: League;
  stats: Promise<TeamSeasonStats>;
  onOpen: () => void;
}

export function SeasonStatsCard({ league, stats, onOpen }: SeasonStatsCardProps) {
  const resolved = use(stats);
  const tiles = teamStatHeadlines(resolved, league);
  // Hide rather than apologise: the Stats tab is where "TBA" is said.
  if (tiles.length === 0) return null;

  const spoken = tiles.map((tile) => `${tile.fullName} ${tile.value}`).join(", ");

  return (
    // A button rather than a section wrapped in one: a heading isn't
    // allowed inside a button, so the header is drawn from spans in the
    // `CardHeader` metrics instead.
    <button
      type="button"
      onClick={onOpen}
      className="card-surface block w-full text-left transition-colors hover:bg-bg-header focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-text-secondary"
    >
      <span className="sr-only">
        Season stats{resolved.seasonLabel ? `, ${resolved.seasonLabel}` : ""}:{" "}
        {spoken}. Opens the Stats tab.
      </span>
      <span aria-hidden="true" className="block">
        <span className="flex items-center justify-between gap-2 p-3">
          <span className="type-section-header text-text-primary">
            Season stats
          </span>
          <span className="flex items-center gap-1 type-meta text-text-secondary">
            {resolved.seasonLabel}
            <ChevronRight className="h-3 w-3" />
          </span>
        </span>
        <span className="block border-t border-divider" />
        <span className="flex items-start px-2 py-3">
          {tiles.map((tile) => (
            <span
              key={tile.name}
              className="flex min-w-0 flex-1 flex-col items-center gap-0.5 text-center"
            >
              <span className="max-w-full truncate type-score text-text-primary">
                {tile.value}
              </span>
              <span className="max-w-full truncate type-row-meta text-text-secondary">
                {tile.label}
              </span>
            </span>
          ))}
        </span>
      </span>
    </button>
  );
}
