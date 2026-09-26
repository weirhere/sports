// The player's season so far, in the three or four numbers their position
// is about — iOS `CurrentSeasonCard` over `StatTilesCard`: games played,
// then yards, touchdowns and interceptions for a quarterback, points,
// rebounds and assists for a guard, goals, assists and points for a skater.
//
// Which numbers is `headlineNames`, keyed by ESPN's own category name, so a
// relabelled column can't move them. The card is the caller's to hide: no
// line for this season means no card, not zeroes.

import { CardHeader } from "@/components/card-header";
import type { PlayerHeadline } from "@/lib/player-stats";

interface ThisSeasonCardProps {
  seasonLabel: string;
  headlines: PlayerHeadline[];
}

export function ThisSeasonCard({ seasonLabel, headlines }: ThisSeasonCardProps) {
  return (
    <section className="card-surface">
      <CardHeader title="This season" subtitle={seasonLabel} />
      <dl className="flex items-start px-2 py-3">
        {headlines.map((headline) => (
          // One tile reads as one fact: "Passing Yards 566", in ESPN's own
          // full name rather than the letters the tile prints.
          <div
            key={headline.label}
            className="flex min-w-0 flex-1 flex-col items-center gap-0.5"
          >
            <dt className="sr-only">{headline.spokenLabel}</dt>
            <dd className="truncate tnum type-score text-text-primary">
              {headline.value}
            </dd>
            <dd
              aria-hidden="true"
              className="truncate type-row-meta text-text-secondary"
            >
              {headline.label}
            </dd>
          </div>
        ))}
      </dl>
    </section>
  );
}
