// Per-quarter line score, OT columns included (iOS LineScoreGrid): team
// abbreviations leading, the numeric columns as one block against the
// trailing edge, totals emphasized. All numbers tabular.

import type { Game, GameTeam } from "@/lib/types";
import { cn } from "@/lib/utils";
import { DetailCard } from "./detail-card";

export function LineScoreCard({ game }: { game: Game }) {
  const count = Math.max(
    game.awayTeam.linescores?.length ?? 0,
    game.homeTeam.linescores?.length ?? 0,
    1
  );
  // "1 2 3 4" plus "OT", "2OT", … past regulation.
  const periods = Array.from({ length: count }, (_, i) => {
    const period = i + 1;
    if (period <= 4) return `${period}`;
    return period === 5 ? "OT" : `${period - 4}OT`;
  });

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
                  className="pb-1 pl-4 pt-2 text-right type-meta text-text-secondary"
                >
                  {label}
                </th>
              ))}
              <th
                scope="col"
                className="pb-1 pl-4 pr-4 pt-2 text-right type-meta-em text-text-secondary"
              >
                T
              </th>
            </tr>
          </thead>
          <tbody>
            <LineScoreRow side={game.awayTeam} periodCount={count} />
            <LineScoreRow side={game.homeTeam} periodCount={count} />
          </tbody>
        </table>
      </div>
    </DetailCard>
  );
}

function LineScoreRow({
  side,
  periodCount,
}: {
  side: GameTeam;
  periodCount: number;
}) {
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
          className="py-1.5 pl-4 text-right type-team-name tnum text-text-primary"
        >
          {index < linescores.length ? linescores[index] : "–"}
        </td>
      ))}
      <td className="py-1.5 pl-4 pr-4 text-right type-team-name-em tnum text-text-primary">
        {side.score ?? "–"}
      </td>
    </tr>
  );
}
