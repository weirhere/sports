// The team page's lead card — iOS `NextGameCard` (Features/Teams/): the
// current season's next unplayed game, or the one in progress retitled
// "Current game". The body is the shared matchup row, which the conference
// slate reuses (do-not-import rule: the Scores game-row belongs to another
// surface).

import Link from "next/link";
import Image from "next/image";
import type { Game, GameTeam } from "@/lib/types";
import { gameState, otherStatusText } from "@/lib/game-state";
import { liveStatusText } from "@/lib/format";
import { CardHeader } from "@/components/card-header";
import { LiveDot } from "@/components/theme/live-dot";
import { cn } from "@/lib/utils";

function dayLine(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "TBD";
  const weekday = date.toLocaleDateString("en-US", { weekday: "short" });
  return `${weekday} ${date.getMonth() + 1}/${date.getDate()}`;
}

function kickTime(iso: string): string {
  const date = new Date(iso);
  if (Number.isNaN(date.getTime())) return "TBD";
  return date.toLocaleTimeString("en-US", { hour: "numeric", minute: "2-digit" });
}

function liveLine(game: Game): string {
  return (
    liveStatusText({
      livePhase: game.livePhase,
      quarter: game.quarter,
      clock: game.clock,
      detail: game.statusDetail,
    }) ?? "Live"
  );
}

/** One spoken sentence for a matchup row link. */
export function gameRowLabel(game: Game): string {
  const away = game.awayTeam.team.school;
  const home = game.homeTeam.team.school;
  const state = gameState(game.status);
  if (state === "final") {
    return `${away} ${game.awayTeam.score ?? "no score"}, ${home} ${
      game.homeTeam.score ?? "no score"
    }, final`;
  }
  if (state === "live") {
    const scores =
      game.awayTeam.score !== null || game.homeTeam.score !== null
        ? `, ${game.awayTeam.score ?? 0} to ${game.homeTeam.score ?? 0}`
        : "";
    return `${away} at ${home}, live, ${liveLine(game)}${scores}`;
  }
  if (state === "pre") {
    const kick = game.timeTBD
      ? "kickoff time to be determined"
      : `kickoff ${dayLine(game.scheduledAt)} ${kickTime(game.scheduledAt)}`;
    return `${away} at ${home}, ${kick}`;
  }
  return `${away} at ${home}, ${otherStatusText(game)}`;
}

function TeamLine({
  side,
  showsScore,
  isLive,
}: {
  side: GameTeam;
  showsScore: boolean;
  isLive: boolean;
}) {
  const won = side.isWinner === true;
  return (
    <span className="flex items-center gap-2">
      <Image
        src={side.team.logoUrl}
        alt=""
        width={20}
        height={20}
        className="h-5 w-5 shrink-0 object-contain"
        unoptimized
      />
      <span
        className={cn(
          "min-w-0 flex-1 truncate text-text-primary",
          showsScore && won ? "type-team-name-em" : "type-team-name"
        )}
      >
        {side.team.school}
        {side.ranking !== undefined && (
          <span className="ml-1.5 tnum type-meta text-text-secondary">
            {side.ranking}
          </span>
        )}
      </span>
      {showsScore && (
        <span
          className={cn(
            "shrink-0 tnum",
            isLive
              ? "type-score-live text-text-primary"
              : won
                ? "type-score text-text-primary"
                : "type-score-muted text-text-secondary"
          )}
        >
          {side.score ?? "–"}
        </span>
      )}
    </span>
  );
}

/**
 * The compact two-line matchup: away over home, scores while live/final,
 * and a hairline-divided trailing status column (kick day + time, the live
 * clock, or "Final"). Decorative internals — the wrapping link carries the
 * spoken sentence via `gameRowLabel`.
 */
export function GameMatchupRow({ game }: { game: Game }) {
  const state = gameState(game.status);
  const showsScores = state === "live" || state === "final";
  return (
    <span aria-hidden="true" className="flex items-center gap-3 px-4 py-2">
      <span className="flex min-w-0 flex-1 flex-col gap-1.5">
        <TeamLine
          side={game.awayTeam}
          showsScore={showsScores}
          isLive={state === "live"}
        />
        <TeamLine
          side={game.homeTeam}
          showsScore={showsScores}
          isLive={state === "live"}
        />
      </span>
      <span className="flex w-20 shrink-0 flex-col items-center gap-0.5 border-l border-divider py-1 text-center">
        {state === "live" ? (
          <span className="inline-flex items-center gap-1.5 type-meta-em text-live">
            <LiveDot />
            {liveLine(game)}
          </span>
        ) : state === "final" ? (
          <span className="type-meta text-text-secondary">Final</span>
        ) : state === "pre" ? (
          <>
            <span
              className="type-meta text-text-secondary"
              suppressHydrationWarning
            >
              {dayLine(game.scheduledAt)}
            </span>
            <span
              className="type-meta text-text-secondary"
              suppressHydrationWarning
            >
              {game.timeTBD ? "TBD" : kickTime(game.scheduledAt)}
            </span>
          </>
        ) : (
          <span className="type-meta text-text-secondary">
            {otherStatusText(game)}
          </span>
        )}
      </span>
    </span>
  );
}

/**
 * Card titled "Next game" — or "Current game" when live — wrapping the
 * matchup row in a link to the game's detail page.
 */
export function NextGameCard({ game }: { game: Game }) {
  const isLive = gameState(game.status) === "live";
  return (
    <section className="card-surface">
      <CardHeader title={isLive ? "Current game" : "Next game"} />
      <Link
        href={`/game/${game.id}`}
        aria-label={gameRowLabel(game)}
        className="block transition-colors hover:bg-bg-header"
        suppressHydrationWarning
      >
        <GameMatchupRow game={game} />
      </Link>
    </section>
  );
}
