// Per-quarter line score, OT columns included (iOS LineScoreGrid): team
// abbreviations leading, the numeric columns as one block against the
// trailing edge, totals emphasized. All numbers tabular.

import { isBaseball } from "@/lib/leagues";
import type { Game, GameTeam } from "@/lib/types";
import { cn } from "@/lib/utils";
import { DetailCard } from "./detail-card";

export function LineScoreCard({ game }: { game: Game }) {
  const count = Math.max(
    game.awayTeam.linescores?.length ?? 0,
    game.homeTeam.linescores?.length ?? 0,
    1
  );
  // Baseball ends R H E and counts its extra innings as innings
  // (2026-11-03).
  const baseball = isBaseball(game.league);
  // "1 2 3 4" plus "OT", "2OT", … past regulation.
  const periods = Array.from({ length: count }, (_, i) => {
    const period = i + 1;
    if (baseball || period <= 4) return `${period}`;
    return period === 5 ? "OT" : `${period - 4}OT`;
  });
  const cell = baseball ? "pl-2" : "pl-4";

  return (
    <DetailCard>
      <div className="overflow-x-auto">
        <table className="w-full px-4">
          <thead>
            <tr>
              <th scope="col" className="w-full px-4 pb-1 pt-2 text-left">
                <span className="sr-only">Team</span>
              </th>
              {periods.map((label) => (
                <th
                  key={label}
                  scope="col"
                  className={cn("pb-1 pt-2 text-right type-meta text-text-secondary", cell)}
                >
                  {label}
                </th>
              ))}
              <th
                scope="col"
                className={cn(
                  "pb-1 pt-2 text-right type-meta-em text-text-secondary",
                  cell,
                  !baseball && "pr-4"
                )}
              >
                {baseball ? "R" : "T"}
              </th>
              {baseball &&
                ["H", "E"].map((caption, index) => (
                  <th
                    key={caption}
                    scope="col"
                    className={cn(
                      "pb-1 pt-2 text-right type-meta-em text-text-secondary",
                      cell,
                      index === 1 && "pr-4"
                    )}
                  >
                    {caption}
                  </th>
                ))}
            </tr>
          </thead>
          <tbody>
            <LineScoreRow side={game.awayTeam} periodCount={count} baseball={baseball} />
            <LineScoreRow side={game.homeTeam} periodCount={count} baseball={baseball} />
          </tbody>
        </table>
      </div>
    </DetailCard>
  );
}

function LineScoreRow({
  side,
  periodCount,
  baseball = false,
}: {
  side: GameTeam;
  periodCount: number;
  baseball?: boolean;
}) {
  const cell = baseball ? "pl-2" : "pl-4";
  const linescores = side.linescores ?? [];
  return (
    <tr>
      <th
        scope="row"
        className={cn(
          "px-4 py-1.5 text-left font-normal text-text-primary",
          side.isWinner === true ? "type-team-name-em" : "type-team-name"
        )}
      >
        {side.team.abbreviation || side.team.school}
      </th>
      {Array.from({ length: periodCount }, (_, index) => (
        <td
          key={index}
          className={cn("py-1.5 text-right type-team-name tnum text-text-primary", cell)}
        >
          {index < linescores.length ? linescores[index] : "–"}
        </td>
      ))}
      <td
        className={cn(
          "py-1.5 text-right type-team-name-em tnum text-text-primary",
          cell,
          !baseball && "pr-4"
        )}
      >
        {side.score ?? "–"}
      </td>
      {baseball &&
        [side.hits, side.errors].map((value, index) => (
          <td
            key={index}
            className={cn(
              "py-1.5 text-right type-team-name tnum text-text-primary",
              cell,
              index === 1 && "pr-4"
            )}
          >
            {value ?? "–"}
          </td>
        ))}
    </tr>
  );
}
