"use client";

// The game header once it has scrolled away (iOS CompactGameHeader,
// 2026-10-02): both marks at 22px with the score between them, one line.
// iOS hangs it in the nav bar's title slot; the web's nav bar is the app's
// own, so it rides at the top of the pinned tab strip instead.
//
// Decorative to assistive tech: the full header is still in the document,
// so this would only read the same facts twice.

import type { Game, GameTeam } from "@/lib/types";
import { PossessionMark } from "@/components/possession-mark";
import { cn } from "@/lib/utils";
import { TeamMark } from "./team-mark";
import { isLiveStatus, kickoffHero, showsScores, statusLine } from "./game-status";

export function CompactGameHeader({
  game,
  possessionTeamId,
}: {
  game: Game;
  possessionTeamId?: string;
}) {
  const live = isLiveStatus(game.status);
  const kickoff = kickoffHero(game);
  const awayScore = game.awayTeam.score;
  const homeScore = game.homeTeam.score;
  const scored = showsScores(game) && awayScore !== null && homeScore !== null;
  const status = statusLine(game);

  return (
    <div
      aria-hidden="true"
      className="flex h-11 items-center justify-center gap-3 px-4"
    >
      <Mark
        side={game.awayTeam}
        outer="left"
        hasBall={live && possessionTeamId === game.awayTeam.team.id}
      />
      {kickoff ? (
        // Before kickoff the time takes the score's slot, as it does in
        // the full header.
        <span className="whitespace-nowrap type-score text-text-primary">
          {kickoff.time}
        </span>
      ) : scored ? (
        <span className="flex items-center gap-1 text-text-primary">
          <span className="min-w-6 text-center type-score">{awayScore}</span>
          {live ? (
            // A fixed-width slot, so the numbers hold still as the clock
            // text changes length.
            <span className="min-w-[90px] whitespace-nowrap text-center type-meta-em tnum text-text-secondary">
              {status}
            </span>
          ) : (
            <span className="type-meta-em">–</span>
          )}
          <span className="min-w-6 text-center type-score">{homeScore}</span>
        </span>
      ) : (
        // No score and no kickoff ("Postponed"): the status alone.
        <span className="whitespace-nowrap type-meta-em text-text-secondary">
          {status}
        </span>
      )}
      <Mark
        side={game.homeTeam}
        outer="right"
        hasBall={live && possessionTeamId === game.homeTeam.team.id}
      />
    </div>
  );
}

/** A 22px mark, with the possession glyph 8px off its outer edge. */
function Mark({
  side,
  outer,
  hasBall,
}: {
  side: GameTeam;
  outer: "left" | "right";
  hasBall: boolean;
}) {
  return (
    <span className="relative h-[22px] w-[22px] shrink-0">
      <TeamMark
        logoUrl={side.team.logoUrl}
        alt=""
        size={22}
        className="h-[22px] w-[22px] object-contain"
      />
      {hasBall && (
        <PossessionMark
          className={cn(
            "absolute top-1/2 -translate-y-1/2",
            outer === "left" ? "right-full mr-2" : "left-full ml-2"
          )}
        />
      )}
    </span>
  );
}
