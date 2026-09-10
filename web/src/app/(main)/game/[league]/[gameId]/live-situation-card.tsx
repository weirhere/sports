// ESPN's Gamecast strip, monochrome — the web twin of iOS
// `LiveSituationCard`. Who has the ball, on what down, where on the field,
// and what just happened.
//
// Live games only: it is built from `drives.current`, which ESPN drops the
// moment a game ends, so the card retires itself without a second condition.
//
// **No colour.** The header above already carries the live dot, and a field
// this small reads on position and weight — the budget's own rule that a
// design problem wanting colour usually wants spacing instead.

import Image from "next/image";
import { ChevronLeft, ChevronRight } from "lucide-react";
import type { Game, GameSituation } from "@/lib/types";
import { cn } from "@/lib/utils";

export function LiveSituationCard({
  game,
  situation,
}: {
  game: Game;
  situation: GameSituation;
}) {
  const offense = [game.awayTeam, game.homeTeam].find(
    (side) => String(side.team.espnId) === situation.possessionTeamId
  );

  return (
    <section
      aria-label={situationSentence(game, situation)}
      className="card-surface flex flex-col gap-3 px-4 py-3"
    >
      {/* Mark, down and distance, then the spot — the three things a fan
          glancing at a live game asks for, in that order. */}
      <div aria-hidden="true" className="flex items-center gap-3">
        {offense && (
          <Image
            src={offense.team.logoUrl}
            alt=""
            width={18}
            height={18}
            unoptimized
            className="h-[18px] w-[18px] shrink-0 object-contain"
          />
        )}
        {situation.downDistanceText && (
          <span className="type-team-name-em text-text-primary">
            {situation.downDistanceText}
          </span>
        )}
        {situation.possessionText && (
          <span className="type-team-name text-text-secondary">
            {situation.possessionText}
          </span>
        )}
        {situation.driveSummary && (
          <span className="ml-auto shrink-0 whitespace-nowrap tnum type-meta text-text-secondary">
            {situation.driveSummary}
          </span>
        )}
      </div>

      {situation.fieldPosition !== undefined && (
        <FieldBar game={game} situation={situation} />
      )}

      {situation.lastPlayText && (
        <p aria-hidden="true" className="type-meta text-text-secondary">
          {situation.lastPlayText}
        </p>
      )}
    </section>
  );
}

/**
 * The away team's end zone is the left edge and the home team's the right,
 * matching the header's logo order. The arrow says which way this offence is
 * moving, so the marker's position can't be read backwards.
 */
function FieldBar({
  game,
  situation,
}: {
  game: Game;
  situation: GameSituation;
}) {
  const fraction = situation.fieldPosition ?? 0;
  return (
    <div aria-hidden="true" className="flex flex-col gap-1">
      <div className="relative h-3">
        <div className="absolute inset-x-0 top-1/2 h-1 -translate-y-1/2 rounded-full bg-divider" />
        {/* Every 10 yards, with the 50 carrying full ink — ticks are what
            turn a bar into a field. */}
        {[1, 2, 3, 4, 5, 6, 7, 8, 9].map((yard) => (
          <span
            key={yard}
            className={cn(
              "absolute top-1/2 w-px -translate-y-1/2",
              yard === 5 ? "h-2.5 bg-text-secondary" : "h-1.5 bg-bg-card"
            )}
            style={{ left: `${yard * 10}%` }}
          />
        ))}
        <span
          className="absolute top-1/2 flex -translate-y-1/2 items-center"
          style={{
            left: `${fraction * 100}%`,
            transform: "translate(-50%, -50%)",
          }}
        >
          {!situation.drivingRight && (
            <ChevronLeft className="h-2 w-2 shrink-0 stroke-[3] text-text-primary" />
          )}
          <span className="h-[9px] w-[9px] shrink-0 rounded-full bg-text-primary" />
          {situation.drivingRight && (
            <ChevronRight className="h-2 w-2 shrink-0 stroke-[3] text-text-primary" />
          )}
        </span>
      </div>
      <div className="flex items-center justify-between type-row-meta text-text-secondary">
        <span>{game.awayTeam.team.abbreviation}</span>
        <span>50</span>
        <span>{game.homeTeam.team.abbreviation}</span>
      </div>
    </div>
  );
}

/**
 * "Washington State ball, 2nd & 4, WSU 26, 1 play, 6 yards, 0:05, (7:53)
 * Shotgun #20 L.Pulalasi rush middle for 6 yards".
 */
export function situationSentence(
  game: Game,
  situation: GameSituation
): string {
  const offense = [game.awayTeam, game.homeTeam].find(
    (side) => String(side.team.espnId) === situation.possessionTeamId
  );
  const parts: string[] = [];
  if (offense) parts.push(`${offense.team.school} ball`);
  if (situation.downDistanceText) parts.push(situation.downDistanceText);
  if (situation.possessionText) parts.push(situation.possessionText);
  if (situation.driveSummary) parts.push(situation.driveSummary);
  if (situation.lastPlayText) parts.push(situation.lastPlayText);
  return parts.join(", ");
}
