"use client";

// The team page's Stats tab — iOS `TeamStatsPane` (2026-09-24): every
// category ESPN tables for the season, in ESPN's own names, and in football
// the same categories for everyone who played this team, behind a Team /
// Opponents switch.
//
// The switch is a capsule rather than a second tab row, for the box score's
// reason: a tab row sits right above it. It only exists where the payload
// carries an opponents' block, which today is football alone — the other
// leagues don't grow one.

import { use, useState } from "react";
import { CardHeader } from "@/components/card-header";
import { Skeleton } from "@/components/ui/skeleton";
import type { TeamSeasonStats } from "@/lib/espn/team-stats";
import { cn } from "@/lib/utils";

export function TeamStatsPane({ stats }: { stats: Promise<TeamSeasonStats> }) {
  const resolved = use(stats);
  const [showsOpponents, setShowsOpponents] = useState(false);

  if (resolved.categories.length === 0) {
    return (
      <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
        Season stats TBA
      </section>
    );
  }

  const hasOpponents = resolved.opponent.length > 0;
  const shown =
    showsOpponents && hasOpponents ? resolved.opponent : resolved.categories;

  return (
    <>
      {hasOpponents && (
        <div
          role="group"
          aria-label="Whose stats"
          className="flex rounded-full bg-bg-elevated p-1"
        >
          <Segment
            title="Team"
            active={!showsOpponents}
            onSelect={() => setShowsOpponents(false)}
          />
          <Segment
            title="Opponents"
            active={showsOpponents}
            onSelect={() => setShowsOpponents(true)}
          />
        </div>
      )}
      {shown.map((category, categoryIndex) => (
        <section key={category.id} className="card-surface pb-1">
          <CardHeader
            title={category.title}
            // The season is said once, on the first card.
            subtitle={categoryIndex === 0 ? resolved.seasonLabel : undefined}
          />
          {category.stats.map((stat, index) => {
            const value = stat.rank ? `${stat.value} · ${stat.rank}` : stat.value;
            return (
              <div key={stat.name}>
                {index > 0 && <div className="ml-4 border-t border-divider" />}
                <div
                  role="group"
                  aria-label={
                    stat.rank
                      ? `${stat.fullName} ${stat.value}, ranked ${stat.rank}`
                      : `${stat.fullName} ${stat.value}`
                  }
                  className="flex items-center justify-between gap-2 px-4 py-3"
                >
                  <span aria-hidden="true" className="type-row-name text-text-secondary">
                    {stat.fullName}
                  </span>
                  <span
                    aria-hidden="true"
                    className="shrink-0 tnum type-row-name-em text-text-primary"
                  >
                    {value}
                  </span>
                </div>
              </div>
            );
          })}
        </section>
      ))}
    </>
  );
}

function Segment({
  title,
  active,
  onSelect,
}: {
  title: string;
  active: boolean;
  onSelect: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onSelect}
      aria-pressed={active}
      className={cn(
        "min-h-11 flex-1 truncate rounded-full px-3 type-chip-em transition-colors focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-text-secondary",
        active ? "bg-text-primary text-bg-primary" : "text-text-primary hover:bg-divider"
      )}
    >
      {title}
    </button>
  );
}

/** The tab's wait: two card-shaped blocks, the roster tab's rhythm. */
export function TeamStatsPaneSkeleton() {
  return (
    <>
      {[0, 1].map((card) => (
        <Skeleton key={card} className="h-48 w-full rounded-[10px]" />
      ))}
      <span className="sr-only">Loading season stats</span>
    </>
  );
}
