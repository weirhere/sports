"use client";

// One game, one compact row — the iOS 2240-spec matchup shape
// (sports/Features/Scores/GameRow.swift): two stacked team lines (away over
// home, the CFB convention) beside a hairline-divided fixed status column.
// Pre and final rows stay quiet; live rows spend the visual budget.

import Link from "next/link";
import type { Game, GameStatus, GameTeam } from "@/lib/types";
import { TeamLogo } from "./team-logo";
import { LiveDot } from "./theme/live-dot";
import { isLiveStatus } from "@/lib/game-sections";
import {
  formatKickTime,
  liveStatusText,
  relativeKick,
  relativeKickParts,
} from "@/lib/format";
import { cn } from "@/lib/utils";

interface GameRowProps {
  game: Game;
  /**
   * True inside a day-grouped section, whose header names the whole day —
   * the row spends nothing on the date, just kick time and network. The
   * spoken sentence still carries the full date.
   */
  timeOnly?: boolean;
}

type RowPhase = "pre" | "live" | "final" | "other";

function phaseOf(status: GameStatus): RowPhase {
  if (isLiveStatus(status)) return "live";
  if (status === "complete") return "final";
  if (status === "scheduled") return "pre";
  return "other";
}

const OTHER_LABELS: Partial<Record<GameStatus, string>> = {
  postponed: "Postponed",
  cancelled: "Cancelled",
  delayed: "Delayed",
};

function finalLabel(game: Game): string {
  // Sentence case per the 2240 spec; OT detected from ESPN's detail string.
  return /ot/i.test(game.statusDetail ?? "") ? "Final OT" : "Final";
}

function kickoffDate(game: Game): Date | undefined {
  const time = Date.parse(game.scheduledAt);
  return Number.isFinite(time) ? new Date(time) : undefined;
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

export function GameRow({ game, timeOnly = false }: GameRowProps) {
  const phase = phaseOf(game.status);

  return (
    <Link
      href={`/game/${game.id}`}
      aria-label={accessibilitySummary(game)}
      className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-bg-header"
    >
      <div aria-hidden="true" className="flex min-w-0 flex-1 flex-col gap-1">
        <TeamLine game={game} side={game.awayTeam} phase={phase} isHome={false} />
        <TeamLine game={game} side={game.homeTeam} phase={phase} isHome />
      </div>
      <div aria-hidden="true" className="h-11 w-px shrink-0 bg-divider" />
      <div aria-hidden="true" className="w-20 shrink-0">
        <StatusColumn game={game} phase={phase} timeOnly={timeOnly} />
      </div>
    </Link>
  );
}

// --- Team line: logo, name, rank after it, possession; record or score at
// the trailing edge -------------------------------------------------------

function TeamLine({
  game,
  side,
  phase,
  isHome,
}: {
  game: Game;
  side: GameTeam;
  phase: RowPhase;
  isHome: boolean;
}) {
  // Final rows put the winner in heavier type; live rows emphasize both.
  // If ESPN omits the winner flag, nobody fades.
  const emphasized =
    phase === "live" || (phase === "final" && side.isWinner === true);
  const otherSide = isHome ? game.awayTeam : game.homeTeam;
  const muted = phase === "final" && otherSide.isWinner === true;
  const hasPossession =
    phase === "live" && game.possession === (isHome ? "home" : "away");

  return (
    <div className="flex min-w-0 items-center gap-2">
      <TeamLogo
        espnId={side.team.espnId}
        teamName={side.team.school}
        size="sm"
        className="h-5 w-5 shrink-0 object-contain"
      />
      <span className="flex min-w-0 items-baseline gap-1">
        <span
          className={cn(
            "truncate",
            emphasized ? "type-row-name-em" : "type-row-name",
            muted ? "text-text-secondary" : "text-text-primary"
          )}
        >
          {side.team.school}
        </span>
        {side.ranking !== undefined && (
          <span className="type-row-meta shrink-0 text-text-secondary">
            {side.ranking}
          </span>
        )}
      </span>
      {hasPossession && (
        // Tiny football: live possession's quiet marker.
        <svg
          viewBox="0 0 12 8"
          className="h-2 w-3 shrink-0 fill-text-secondary"
        >
          <ellipse cx="6" cy="4" rx="5.6" ry="3.6" />
        </svg>
      )}
      <span className="ml-auto shrink-0 pl-2">
        {phase === "pre" && side.record !== undefined && (
          <span className="type-row-meta-medium text-text-secondary">
            {side.record}
          </span>
        )}
        {(phase === "live" || phase === "final") && (
          <span
            className={cn(
              "tnum",
              emphasized && !muted ? "type-row-name-em" : "type-row-name",
              muted ? "text-text-secondary" : "text-text-primary"
            )}
          >
            {side.score ?? "–"}
          </span>
        )}
      </span>
    </div>
  );
}

// --- Status column: what the game needs from you now ----------------------

function StatusColumn({
  game,
  phase,
  timeOnly,
}: {
  game: Game;
  phase: RowPhase;
  timeOnly: boolean;
}) {
  const network = game.broadcast;
  const date = kickoffDate(game);

  switch (phase) {
    case "pre": {
      return (
        <div className="flex flex-col gap-0.5">
          {date === undefined ? (
            <span className="type-row-meta-medium text-text-primary">TBD</span>
          ) : timeOnly ? (
            <span className="type-row-meta-medium truncate text-text-primary">
              {game.timeTBD ? "TBD" : formatKickTime(date)}
            </span>
          ) : (
            (() => {
              const kick = relativeKickParts(date, { timeTBD: game.timeTBD });
              return (
                <>
                  <span className="type-row-meta-medium truncate text-text-primary">
                    {kick.day}
                  </span>
                  <span className="type-row-meta truncate text-text-secondary">
                    {kick.time}
                  </span>
                </>
              );
            })()
          )}
          {network && (
            <span className="type-row-meta truncate text-text-secondary">
              {network}
            </span>
          )}
        </div>
      );
    }
    case "live":
      return (
        <div className="flex flex-col gap-1">
          <span className="flex items-center gap-1.5">
            <LiveDot />
            <span className="type-row-meta-medium tnum truncate text-text-primary">
              {liveLine(game)}
            </span>
          </span>
          {/* "Where do I watch" is the live row's second question. */}
          {network && (
            <span className="type-row-meta truncate text-text-secondary">
              {network}
            </span>
          )}
        </div>
      );
    case "final":
      return (
        <div className="flex flex-col gap-0.5">
          <span className="type-row-meta-medium text-text-primary">
            {finalLabel(game)}
          </span>
          {date !== undefined && !timeOnly && (
            <span className="type-row-meta truncate text-text-secondary">
              {date.toLocaleDateString("en-US", {
                weekday: "short",
                month: "numeric",
                day: "numeric",
              })}
            </span>
          )}
        </div>
      );
    case "other":
      return (
        <span className="type-row-meta truncate text-text-secondary">
          {OTHER_LABELS[game.status] ?? game.statusDetail ?? "—"}
        </span>
      );
  }
}

// --- The spoken sentence --------------------------------------------------
// One iOS-style sentence per row instead of a dozen fragments. Exported for
// tests; always carries the full date, even when the row suppresses it.

function sideName(side: GameTeam): string {
  return side.ranking !== undefined
    ? `No. ${side.ranking} ${side.team.school}`
    : side.team.school;
}

/** "5-0" reads as "5 and 0" — the spoken convention, not "5 minus 0". */
function spokenRecord(side: GameTeam): string | undefined {
  return side.record?.replace("-", " and ");
}

function spokenPeriod(period: number): string {
  switch (period) {
    case 1:
      return "1st quarter";
    case 2:
      return "2nd quarter";
    case 3:
      return "3rd quarter";
    case 4:
      return "4th quarter";
    case 5:
      return "overtime";
    default:
      return `overtime ${period - 4}`;
  }
}

function scoreSummary(game: Game): string {
  const score = (side: GameTeam) =>
    `${sideName(side)} ${side.score ?? "no score"}`;
  return `${score(game.awayTeam)}, ${score(game.homeTeam)}`;
}

export function accessibilitySummary(game: Game): string {
  const phase = phaseOf(game.status);
  const date = kickoffDate(game);

  switch (phase) {
    case "pre": {
      const side = (s: GameTeam) =>
        [sideName(s), spokenRecord(s)].filter(Boolean).join(" ");
      const parts = [`${side(game.awayTeam)} at ${side(game.homeTeam)}`];
      if (date !== undefined) {
        if (game.timeTBD) {
          const kick = relativeKickParts(date, { weekday: "long" });
          parts.push(`${kick.day}, kickoff time to be determined`);
        } else {
          parts.push(relativeKick(date, { weekday: "long" }));
        }
      }
      if (game.broadcast) parts.push(`on ${game.broadcast}`);
      return parts.join(", ");
    }
    case "live": {
      const parts = [scoreSummary(game)];
      if (game.livePhase === "halftime") {
        parts.push("halftime");
      } else if (game.livePhase === "endOfPeriod") {
        if (game.quarter !== undefined) {
          parts.push(`end of ${spokenPeriod(game.quarter)}`);
        }
      } else {
        if (game.quarter !== undefined) parts.push(spokenPeriod(game.quarter));
        if (game.clock) parts.push(`${game.clock} left`);
      }
      if (game.possession !== undefined) {
        const holder =
          game.possession === "home" ? game.homeTeam : game.awayTeam;
        parts.push(`${holder.team.school} has the ball`);
      }
      if (game.broadcast) parts.push(`on ${game.broadcast}`);
      parts.push("live");
      return parts.join(", ");
    }
    case "final": {
      const overtime = /ot/i.test(game.statusDetail ?? "");
      return `${scoreSummary(game)}, ${overtime ? "final, overtime" : "final"}`;
    }
    case "other":
      return `${sideName(game.awayTeam)} at ${sideName(game.homeTeam)}, ${
        OTHER_LABELS[game.status] ?? game.statusDetail ?? "status unavailable"
      }`;
  }
}
