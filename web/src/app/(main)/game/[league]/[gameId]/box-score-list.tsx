// The Box score tab — the web twin of iOS `BoxScoreList`.
//
// One card per team per stat group, and **every column comes from the
// payload**: ESPN ships its own headers, and the set changes during the game
// (a live `passing` group has five columns and the same group has six once
// the game is final — QBR only lands at the end). A schema named in code
// would misalign every row mid-game, which is the one thing a stats table
// must never do.
//
// The table scrolls inside its own card rather than squeezing: a football
// passing line is six columns wide and a phone is not.

import Image from "next/image";
import type { BoxScoreTeam, Game, GameTeam } from "@/lib/types";
import { CardHeader } from "@/components/card-header";

export function BoxScoreList({
  boxScore,
  game,
}: {
  boxScore: BoxScoreTeam[];
  game: Game;
}) {
  // Away first, the scoreboard's own order — and any team the payload names
  // that the header doesn't still gets its table rather than being dropped.
  const sides = [game.awayTeam, game.homeTeam];
  const ordered = [...boxScore].sort(
    (a, b) => sideIndex(a.teamId, sides) - sideIndex(b.teamId, sides)
  );

  return (
    <div className="flex flex-col gap-2">
      {ordered.map((team) => {
        const side = sides.find(
          (entry) => String(entry.team.espnId) === team.teamId
        );
        return team.categories.map((category) => (
          <section key={`${team.teamId}-${category.id}`} className="card-surface">
            <CardHeader
              title={
                side ? `${side.team.school} ${category.label}` : category.label
              }
            />
            <div className="overflow-x-auto">
              <table className="w-full min-w-max border-collapse">
                <thead>
                  <tr className="type-row-meta-medium text-text-secondary">
                    <th
                      scope="col"
                      className="sticky left-0 z-10 bg-bg-card px-4 py-2 text-left font-normal"
                    >
                      {side?.team.abbreviation ?? "PLAYER"}
                    </th>
                    {category.columns.map((column, index) => (
                      <th
                        key={`${column}-${index}`}
                        scope="col"
                        className="px-2 py-2 text-right font-normal last:pr-4"
                      >
                        {column}
                      </th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {category.players.map((player) => (
                    <tr
                      key={player.id}
                      className="border-t border-divider align-middle"
                    >
                      <th
                        scope="row"
                        className="sticky left-0 z-10 max-w-[10rem] truncate bg-bg-card px-4 py-2 text-left type-row-name text-text-primary"
                      >
                        <span className="flex items-center gap-1.5">
                          {player.headshotUrl && (
                            <Image
                              src={player.headshotUrl}
                              alt=""
                              width={20}
                              height={20}
                              unoptimized
                              className="h-5 w-5 shrink-0 rounded-full object-cover"
                            />
                          )}
                          <span className="truncate">{player.name}</span>
                          {player.jersey && (
                            <span className="shrink-0 tnum type-row-meta text-text-secondary">
                              {player.jersey}
                            </span>
                          )}
                        </span>
                      </th>
                      {player.stats.map((stat, index) => (
                        <td
                          key={`${player.id}-${index}`}
                          className="px-2 py-2 text-right tnum type-row-name text-text-primary last:pr-4"
                        >
                          {stat}
                        </td>
                      ))}
                    </tr>
                  ))}
                  {category.totals.length > 0 && (
                    <tr className="border-t border-divider">
                      <th
                        scope="row"
                        className="sticky left-0 z-10 bg-bg-card px-4 py-2 text-left type-row-name-em text-text-primary"
                      >
                        Total
                      </th>
                      {category.totals.map((total, index) => (
                        <td
                          key={`total-${index}`}
                          className="px-2 py-2 text-right tnum type-row-name-em text-text-primary last:pr-4"
                        >
                          {total}
                        </td>
                      ))}
                    </tr>
                  )}
                </tbody>
              </table>
            </div>
          </section>
        ));
      })}
    </div>
  );
}

function sideIndex(teamId: string, sides: GameTeam[]): number {
  const index = sides.findIndex(
    (side) => String(side.team.espnId) === teamId
  );
  return index === -1 ? sides.length : index;
}
