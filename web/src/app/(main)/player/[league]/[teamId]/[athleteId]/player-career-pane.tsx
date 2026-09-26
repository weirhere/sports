// The Career tab — iOS `PlayerCareerPane` over `StatTableCard`: every
// season the player has a line for, with the club he played it for, and
// ESPN's own career totals closing each table.
//
// Nothing here is summed (2026-09-24): the seasons are ESPN's rows and the
// career line is ESPN's `totals`, so our numbers can't disagree with theirs
// and a traded player's two lines for a year stay two lines. Columns come
// from the payload and are never named here, for the box score's reason —
// ESPN's column sets vary by league and position. The table scrolls inside
// its card rather than squeezing, as the box score's does.
//
// The club caption is the stats payload's own abbreviation. iOS resolves it
// through the team directory, which a college player's old FCS school can
// fall outside of; the payload names every club it lists.
//
// A player with no season lines gets an empty state rather than a table
// header over nothing, since the tab row is always drawn (2026-09-25).

import type { PlayerStats, PlayerSeasonLine } from "@/lib/player-stats";
import { categoriesWithLines, seasonLineId } from "@/lib/player-stats";
import { CardHeader } from "@/components/card-header";

export function PlayerCareerPane({ stats }: { stats: PlayerStats }) {
  const categories = categoriesWithLines(stats);
  if (categories.length === 0) {
    return (
      <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
        No career stats yet
      </section>
    );
  }

  return (
    <>
      {categories.map((category) => (
        <section key={category.id} className="card-surface">
          <CardHeader title={category.title} />
          <div className="overflow-x-auto">
            <table className="w-full min-w-max border-collapse">
              <thead>
                <tr className="type-row-meta-medium text-text-secondary">
                  <th
                    scope="col"
                    className="sticky left-0 z-10 bg-bg-card px-4 py-2 text-left font-normal"
                  >
                    <span className="sr-only">Season</span>
                  </th>
                  {category.labels.map((label, index) => (
                    <th
                      key={`${label}-${index}`}
                      scope="col"
                      className="px-2 py-2 text-right font-normal last:pr-4"
                    >
                      {/* ESPN's full name for the screen reader, the letters
                          for the eye. */}
                      <span aria-hidden="true">{label}</span>
                      <span className="sr-only">
                        {category.displayNames[index] || label}
                      </span>
                    </th>
                  ))}
                </tr>
              </thead>
              <tbody>
                {category.seasons.map((line) => (
                  <tr
                    key={seasonLineId(line)}
                    className="border-t border-divider align-middle"
                  >
                    <th
                      scope="row"
                      className="sticky left-0 z-10 bg-bg-card px-4 py-2 text-left font-normal"
                    >
                      <SeasonCell line={line} />
                    </th>
                    {line.values.map((value, index) => (
                      <td
                        key={index}
                        className="px-2 py-2 text-right tnum type-row-name text-text-primary last:pr-4"
                      >
                        {value}
                      </td>
                    ))}
                  </tr>
                ))}
                {category.career.length > 0 && (
                  <tr className="border-t border-divider">
                    <th
                      scope="row"
                      className="sticky left-0 z-10 bg-bg-card px-4 py-2 text-left type-row-name-em text-text-primary"
                    >
                      Career
                    </th>
                    {category.career.map((value, index) => (
                      <td
                        key={`career-${index}`}
                        className="px-2 py-2 text-right tnum type-row-name-em text-text-primary last:pr-4"
                      >
                        {value}
                      </td>
                    ))}
                  </tr>
                )}
              </tbody>
            </table>
          </div>
        </section>
      ))}
    </>
  );
}

/** "2025-26" over "LAL" in the quieter ink — the season names the row, the
 *  club qualifies it. */
function SeasonCell({ line }: { line: PlayerSeasonLine }) {
  return (
    <span className="flex items-baseline gap-1.5 whitespace-nowrap">
      <span className="tnum type-row-name text-text-primary">{line.label}</span>
      {line.teamAbbreviation && (
        <span className="type-row-meta text-text-secondary">
          {line.teamAbbreviation}
        </span>
      )}
    </span>
  );
}
