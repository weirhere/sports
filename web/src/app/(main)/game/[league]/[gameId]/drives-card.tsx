// Every possession, chronological with quarter markers (iOS DriveLogList):
// who had the ball and what came of it. Scoring drives get weight; the
// rest stay quiet.

import Image from "next/image";
import type { Game, GameDrive, GameTeam } from "@/lib/types";
import { DetailCard } from "./detail-card";
import { quarterMarkerLabel } from "./game-status";

export function DrivesCard({
  drives,
  game,
}: {
  drives: GameDrive[];
  game: Game;
}) {
  function teamFor(drive: GameDrive): GameTeam | undefined {
    if (drive.teamId === undefined) return undefined;
    return [game.homeTeam, game.awayTeam].find(
      (side) => String(side.team.espnId) === drive.teamId
    );
  }

  return (
    <DetailCard title="Drives">
      <ul className="pb-2">
        {drives.map((drive, index) => {
          const marker =
            index === 0 || drive.quarter !== drives[index - 1].quarter;
          const team = teamFor(drive);
          return (
            <li key={drive.id}>
              {marker && (
                <p
                  className={`px-4 pb-1 type-meta text-text-secondary ${
                    index === 0 ? "pt-1" : "pt-3"
                  }`}
                >
                  {quarterMarkerLabel(drive.quarter)}
                </p>
              )}
              {/* One spoken sentence: "Miami, punt, 5 plays, 20 yards, 2:39". */}
              <div
                aria-label={[
                  team?.team.school,
                  drive.result?.toLowerCase(),
                  drive.summary,
                ]
                  .filter(Boolean)
                  .join(", ")}
                className="flex items-center gap-3 px-4 py-[5px]"
              >
                <span
                  aria-hidden="true"
                  className="flex h-4 w-4 shrink-0 items-center justify-center"
                >
                  {team && (
                    <Image
                      src={team.team.logoUrl}
                      alt=""
                      width={16}
                      height={16}
                      unoptimized
                      className="h-4 w-4 object-contain"
                    />
                  )}
                </span>
                <span
                  aria-hidden="true"
                  className={`text-text-primary ${
                    drive.isScore ? "type-meta-em" : "type-meta"
                  }`}
                >
                  {drive.result ?? "—"}
                </span>
                {drive.summary && (
                  <span
                    aria-hidden="true"
                    className="ml-auto text-right type-meta tnum text-text-secondary"
                  >
                    {drive.summary}
                  </span>
                )}
              </div>
            </li>
          );
        })}
      </ul>
    </DetailCard>
  );
}
