"use client";

import Link from "next/link";
import type { Game, GameStatus } from "@/lib/types";
import { TeamLogo } from "./team-logo";
import { LiveIndicator } from "./live-indicator";
import { cn } from "@/lib/utils";

interface GameRowProps {
  game: Game;
}

function isLive(status: GameStatus) {
  return status === "in_progress" || status === "halftime" || status === "end_period";
}

function formatGameTime(dateStr: string) {
  const date = new Date(dateStr);
  return date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
  });
}

function getStatusText(game: Game) {
  if (game.status === "complete") return "FT";
  if (game.status === "halftime") return "HT";
  if (game.status === "end_period") return `End Q${game.quarter}`;
  if (isLive(game.status)) {
    const q = game.quarter && game.quarter > 4 ? "OT" : `Q${game.quarter}`;
    return `${q} ${game.clock || ""}`.trim();
  }
  if (game.status === "postponed") return "PPD";
  if (game.status === "cancelled") return "CAN";
  if (game.status === "delayed") return "DEL";
  return formatGameTime(game.scheduledAt);
}

export function GameRow({ game }: GameRowProps) {
  const live = isLive(game.status);
  const scheduled = game.status === "scheduled";
  const complete = game.status === "complete";

  return (
    <Link
      href={`/game/${game.id}`}
      className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-accent/30"
    >
      {/* Status column */}
      <div className="flex w-12 shrink-0 flex-col items-center justify-center">
        {live ? (
          <LiveIndicator />
        ) : (
          <span
            className={cn(
              "text-xs font-medium",
              complete ? "text-muted-foreground" : "text-foreground"
            )}
          >
            {getStatusText(game)}
          </span>
        )}
      </div>

      {/* Teams + Scores */}
      <div className="flex min-w-0 flex-1 flex-col gap-1.5">
        {/* Away team */}
        <div className="flex items-center gap-2.5">
          <TeamLogo espnId={game.awayTeam.team.espnId} teamName={game.awayTeam.team.school} size="sm" />
          <div className="flex min-w-0 flex-1 items-center gap-1.5">
            {game.awayTeam.ranking && (
              <span className="text-[11px] font-medium text-muted-foreground">
                {game.awayTeam.ranking}
              </span>
            )}
            <span
              className={cn(
                "truncate text-sm",
                game.awayTeam.isWinner ? "font-semibold" : "font-normal"
              )}
            >
              {game.awayTeam.team.school}
            </span>
          </div>
          {!scheduled && (
            <span
              className={cn(
                "font-score text-sm",
                game.awayTeam.isWinner ? "font-bold" : "text-muted-foreground"
              )}
            >
              {game.awayTeam.score}
            </span>
          )}
        </div>

        {/* Home team */}
        <div className="flex items-center gap-2.5">
          <TeamLogo espnId={game.homeTeam.team.espnId} teamName={game.homeTeam.team.school} size="sm" />
          <div className="flex min-w-0 flex-1 items-center gap-1.5">
            {game.homeTeam.ranking && (
              <span className="text-[11px] font-medium text-muted-foreground">
                {game.homeTeam.ranking}
              </span>
            )}
            <span
              className={cn(
                "truncate text-sm",
                game.homeTeam.isWinner ? "font-semibold" : "font-normal"
              )}
            >
              {game.homeTeam.team.school}
            </span>
          </div>
          {!scheduled && (
            <span
              className={cn(
                "font-score text-sm",
                game.homeTeam.isWinner ? "font-bold" : "text-muted-foreground"
              )}
            >
              {game.homeTeam.score}
            </span>
          )}
        </div>
      </div>

      {/* Broadcast badge */}
      {game.broadcast && (
        <span className="hidden shrink-0 text-[11px] text-muted-foreground sm:block">
          {game.broadcast}
        </span>
      )}
    </Link>
  );
}
