"use client";

import Link from "next/link";
import type { Game, GameStatus } from "@/lib/types";
import { TeamLogo } from "./team-logo";
import { ScoreDisplay } from "./score-display";
import { LiveIndicator } from "./live-indicator";
import { cn } from "@/lib/utils";

interface GameCardProps {
  game: Game;
  className?: string;
}

function isLive(status: GameStatus) {
  return status === "in_progress" || status === "halftime" || status === "end_period";
}

function formatGameTime(dateStr: string) {
  const date = new Date(dateStr);
  return date.toLocaleTimeString("en-US", {
    hour: "numeric",
    minute: "2-digit",
    timeZoneName: "short",
  });
}

function getStatusText(game: Game) {
  if (game.status === "complete") return "Final";
  if (game.status === "halftime") return "Halftime";
  if (game.status === "end_period") return `End Q${game.quarter}`;
  if (isLive(game.status)) {
    const q = game.quarter && game.quarter > 4 ? "OT" : `Q${game.quarter}`;
    return `${q} ${game.clock || ""}`.trim();
  }
  if (game.status === "postponed") return "Postponed";
  if (game.status === "cancelled") return "Cancelled";
  if (game.status === "delayed") return "Delayed";
  return formatGameTime(game.scheduledAt);
}

function TeamRow({
  team,
  score,
  ranking,
  isWinner,
  record,
  live,
}: {
  team: Game["homeTeam"]["team"];
  score: number | null;
  ranking?: number;
  isWinner?: boolean;
  record?: string;
  live: boolean;
}) {
  return (
    <div className="flex items-center gap-3">
      <TeamLogo espnId={team.espnId} teamName={team.school} size="md" />
      <div className="flex min-w-0 flex-1 items-center gap-1.5">
        {ranking && (
          <span className="text-xs font-medium text-muted-foreground">
            {ranking}
          </span>
        )}
        <span
          className={cn(
            "truncate text-sm",
            isWinner ? "font-semibold" : "font-medium"
          )}
        >
          {team.school}
        </span>
        {record && (
          <span className="hidden text-xs text-muted-foreground sm:inline">
            ({record})
          </span>
        )}
      </div>
      <ScoreDisplay score={score} isWinner={isWinner} isLive={live} />
    </div>
  );
}

export function GameCard({ game, className }: GameCardProps) {
  const live = isLive(game.status);

  return (
    <Link href={`/game/${game.id}`} className="block">
      <div
        className={cn(
          "rounded-lg border bg-card p-4 transition-all hover:bg-accent/50 hover:-translate-y-0.5 hover:shadow-md",
          live && "border-red-500/20 bg-red-500/[0.02]",
          className
        )}
      >
        {/* Away team */}
        <TeamRow
          team={game.awayTeam.team}
          score={game.awayTeam.score}
          ranking={game.awayTeam.ranking}
          isWinner={game.awayTeam.isWinner}
          record={game.awayTeam.record}
          live={live}
        />

        {/* Spacer */}
        <div className="my-2.5" />

        {/* Home team */}
        <TeamRow
          team={game.homeTeam.team}
          score={game.homeTeam.score}
          ranking={game.homeTeam.ranking}
          isWinner={game.homeTeam.isWinner}
          record={game.homeTeam.record}
          live={live}
        />

        {/* Status bar */}
        <div className="mt-3 flex items-center justify-between border-t pt-2.5">
          <div className="flex items-center gap-2">
            {live ? (
              <LiveIndicator />
            ) : (
              <span className="text-xs text-muted-foreground">
                {getStatusText(game)}
              </span>
            )}
          </div>
          {game.broadcast && (
            <span className="text-xs font-medium text-muted-foreground">
              {game.broadcast}
            </span>
          )}
        </div>

        {/* Live game: show clock/quarter inline */}
        {live && (
          <div className="mt-1">
            <span className="text-xs text-muted-foreground">
              {getStatusText(game)}
            </span>
          </div>
        )}
      </div>
    </Link>
  );
}
