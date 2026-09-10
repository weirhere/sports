// One play, wherever it is listed — inside a football drive or inside a
// basketball or hockey period. The web twin of iOS `PlayRow`.
//
// Extracted rather than copied into both lists: they ask the same question of
// a play and would otherwise answer it differently the first time either
// changed.

import type { Game, PlayItem } from "@/lib/types";
import { cn } from "@/lib/utils";

export function PlayRow({
  play,
  game,
  /** How far the row indents past its parent's mark, so the plays read as
   *  that drive's or that period's children. */
  indented = true,
}: {
  play: PlayItem;
  game: Game;
  indented?: boolean;
}) {
  // "1st & 10 at IU 5" in football, falling back to the play's own type where
  // ESPN gives no down — kickoffs and extra points, and every basketball and
  // hockey play, none of which has a down at all.
  const lead = play.downDistanceText ?? play.typeText;

  return (
    <div
      aria-label={playSentence(play, game)}
      className={cn(
        "flex gap-2 py-[5px] pr-4",
        indented ? "pl-10" : "pl-4"
      )}
    >
      {play.clock && (
        <span
          aria-hidden="true"
          className="w-10 shrink-0 tnum type-meta text-text-secondary"
        >
          {play.clock}
        </span>
      )}
      <div aria-hidden="true" className="min-w-0 flex-1">
        <div className="flex items-baseline gap-2">
          {lead && (
            <span className="type-meta-em text-text-primary">{lead}</span>
          )}
          {/* Only scoring plays carry the running score — every other row
              would repeat the number above it. Weight marks the side that
              scored, the scoring list's rule, so the budget stays at three
              colours; a play the transform couldn't attribute emphasises
              neither number. */}
          {play.isScoringPlay &&
            play.awayScore !== undefined &&
            play.homeScore !== undefined && (
              <span className="ml-auto shrink-0 whitespace-nowrap tnum">
                <Number
                  value={play.awayScore}
                  emphasized={play.scoringSide === "away"}
                />
                <span className="type-meta text-text-secondary">–</span>
                <Number
                  value={play.homeScore}
                  emphasized={play.scoringSide === "home"}
                />
              </span>
            )}
        </div>
        {play.text && (
          <p
            className={cn(
              "type-meta",
              play.isScoringPlay ? "text-text-primary" : "text-text-secondary"
            )}
          >
            {play.text}
          </p>
        )}
      </div>
    </div>
  );
}

function Number({
  value,
  emphasized,
}: {
  value: number;
  emphasized: boolean;
}) {
  return (
    <span
      className={
        emphasized
          ? "type-meta-em text-text-primary"
          : "type-meta text-text-secondary"
      }
    >
      {value}
    </span>
  );
}

/**
 * "1st & 10 at IU 5, 12:16, Shotgun #15 F.Mendoza pass complete…" — the down
 * first, because it's the context the narration assumes.
 */
export function playSentence(play: PlayItem, game: Game): string {
  const parts: string[] = [];
  const lead = play.downDistanceText ?? play.typeText;
  if (lead) parts.push(lead);
  if (play.clock) parts.push(play.clock);
  if (play.text) parts.push(play.text);
  if (
    play.isScoringPlay &&
    play.awayScore !== undefined &&
    play.homeScore !== undefined
  ) {
    parts.push(
      `${game.awayTeam.team.school} ${play.awayScore}, ${game.homeTeam.team.school} ${play.homeScore}`
    );
  }
  return parts.join(", ");
}
