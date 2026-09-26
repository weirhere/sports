// The Stats tab — iOS `PlayerStatsPane`: the player's latest season,
// category by category, in ESPN's own words — "Passing Yards 566" rather
// than "YDS 566", because a label/value card has the room a table header
// doesn't.
//
// The *latest* season with a line, not strictly the current one: in the
// NBA's summer the current season has no games yet, and an empty tab would
// hide numbers that are only four months old. Each card's subtitle says
// which season it is, so nothing passes for this year that isn't.

import type { PlayerStats } from "@/lib/player-stats";
import { LabeledValueCard, type LabeledValueRow } from "./labeled-value-card";

export function PlayerStatsPane({ stats }: { stats: PlayerStats }) {
  return (
    <>
      {stats.categories.map((category) => {
        const line = category.seasons.at(-1);
        if (!line) return null;
        const rows: LabeledValueRow[] = [];
        category.labels.forEach((label, index) => {
          const value = line.values[index];
          if (value === undefined) return;
          const fullName = category.displayNames[index];
          rows.push({ label: fullName || label, value, spokenLabel: fullName });
        });
        return (
          <LabeledValueCard
            key={category.id}
            title={category.title}
            subtitle={[line.label, line.teamName]
              .filter((part): part is string => Boolean(part))
              .join(" · ")}
            rows={rows}
          />
        );
      })}
    </>
  );
}
