// One game on a team page, from that team's perspective — iOS `ScheduleRow`
// (Features/Teams/ScheduleRow.swift): date · vs/@ opponent · result or kick
// time. Finals render the P1 result chip: green win / red loss, the score
// itself in mine-first order so color is never the only signal.

import Link from "next/link";
import Image from "next/image";
import type { Game } from "@/lib/types";
import { gameState, otherStatusText } from "@/lib/game-state";
import { LiveDot } from "@/components/theme/live-dot";
import { cn } from "@/lib/utils";

interface ScheduleRowProps {
  game: Game;
  /** The page's own team — the row reads from this side's perspective. */
  teamId: string;
}

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

export function ScheduleRow({ game, teamId }: ScheduleRowProps) {
  const isHome = game.homeTeam.team.id === teamId;
  const mine = isHome ? game.homeTeam : game.awayTeam;
  const opponent = isHome ? game.awayTeam : game.homeTeam;
  const state = gameState(game.status);

  const won = mine.isWinner === true;
  const lost = opponent.isWinner === true;
  const mineFirstScore = `${mine.score ?? "–"}-${opponent.score ?? "–"}`;

  // One spoken sentence from this team's perspective: "Sat 9/27, versus
  // Tennessee, won 24 to 17".
  const spokenScore = `${mine.score ?? "no score"} to ${
    opponent.score ?? "no score"
  }`;
  const parts: string[] = [dayLine(game.scheduledAt)];
  parts.push(`${isHome ? "versus" : "at"} ${opponent.team.school}`);
  if (state === "final") {
    parts.push(`${won ? "won" : lost ? "lost" : "final"} ${spokenScore}`);
  } else if (state === "live") {
    parts.push(
      mine.score !== null || opponent.score !== null
        ? `live, ${spokenScore}`
        : "live now"
    );
  } else if (state === "pre") {
    parts.push(
      game.timeTBD
        ? "kickoff time to be determined"
        : `kickoff ${kickTime(game.scheduledAt)}`
    );
  } else {
    parts.push(otherStatusText(game));
  }

  return (
    <Link
      href={`/game/${game.id}`}
      aria-label={parts.join(", ")}
      className="flex items-center gap-3 px-4 py-2 transition-colors hover:bg-bg-header"
      suppressHydrationWarning
    >
      <span
        aria-hidden="true"
        className="min-w-13 shrink-0 whitespace-nowrap type-meta text-text-secondary"
        suppressHydrationWarning
      >
        {dayLine(game.scheduledAt)}
      </span>
      <span aria-hidden="true" className="flex min-w-0 flex-1 items-center gap-2">
        <span className="type-meta text-text-secondary">
          {isHome ? "vs" : "@"}
        </span>
        <Image
          src={opponent.team.logoUrl}
          alt=""
          width={32}
          height={32}
          className="h-8 w-8 shrink-0 object-contain"
          unoptimized
        />
        <span className="truncate type-team-name text-text-primary">
          {opponent.team.school}
        </span>
      </span>
      <span aria-hidden="true" className="shrink-0">
        {state === "final" ? (
          <span
            className={cn(
              "inline-block rounded px-1.5 py-1 tnum type-chip-em",
              won
                ? "bg-rank-up text-bg-primary"
                : lost
                  ? "bg-rank-down text-bg-primary"
                  : "bg-bg-elevated text-text-primary"
            )}
          >
            {mineFirstScore}
          </span>
        ) : state === "live" ? (
          <span className="inline-flex items-center gap-1.5 type-meta-em text-text-primary">
            <LiveDot />
            Live
          </span>
        ) : state === "pre" ? (
          <span
            className="type-meta text-text-secondary"
            suppressHydrationWarning
          >
            {game.timeTBD ? "TBD" : kickTime(game.scheduledAt)}
          </span>
        ) : (
          <span className="type-meta text-text-secondary">
            {otherStatusText(game)}
          </span>
        )}
      </span>
    </Link>
  );
}
