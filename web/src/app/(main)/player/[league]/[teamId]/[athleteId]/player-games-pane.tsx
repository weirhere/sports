// The Games tab — iOS `PlayerGamesList`: one row per appearance — when, who
// against, how it ended, and that night's line for this player.
//
// Grouped the way ESPN's log is (regular season, postseason) and labelled
// the way the app labels time per league: football by week, basketball and
// hockey by date, because ESPN sends `week: null` for both (principle 2).
// Every row links to the game it names.
//
// Rendered on the client only, after the log arrives, so the date it
// prints is the reader's own local day with no server render to disagree.

import Image from "next/image";
import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { CardHeader } from "@/components/card-header";
import { Skeleton } from "@/components/ui/skeleton";
import { hasWeeks, type League } from "@/lib/leagues";
import type { OnDemand } from "@/lib/hooks/use-on-demand";
import { gamePath } from "@/lib/routes";
import {
  gameLogHeadline,
  gameLogIsEmpty,
  gameLogResult,
  type PlayerGameLog,
  type PlayerGameLogEntry,
} from "@/lib/player-stats";

interface PlayerGamesPaneProps {
  league: League;
  log: OnDemand<PlayerGameLog>;
  /** The player's own stat category ("passing", "averages"), which picks
   *  the row's headline columns. */
  category?: string;
  onRetry: () => void;
}

export function PlayerGamesPane({ league, log, category, onRetry }: PlayerGamesPaneProps) {
  if (log.status === "loading") return <GamesSkeleton />;
  if (log.status === "failed") {
    return (
      <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
        <p className="type-team-name text-text-secondary">
          Couldn&rsquo;t load this season&rsquo;s games.
        </p>
        <button
          type="button"
          onClick={onRetry}
          className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-text-secondary"
        >
          Retry
        </button>
      </section>
    );
  }
  // Told apart from a failed fetch above: a season he didn't play and a
  // network that answered nothing look identical here, and only one of
  // them is worth a Retry button.
  if (gameLogIsEmpty(log.value)) {
    return (
      <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
        No games this season
      </section>
    );
  }

  return (
    <>
      {log.value.sections.map((section) => (
        <section key={section.title} className="card-surface pb-1">
          <CardHeader
            title={section.title}
            subtitle={`${section.entries.length} ${section.entries.length === 1 ? "game" : "games"}`}
          />
          {section.entries.map((entry, index) => (
            <div key={entry.eventId}>
              {index > 0 && <div className="ml-4 border-t border-divider" />}
              <GameLogRow
                league={league}
                log={log.value}
                entry={entry}
                category={category}
              />
            </div>
          ))}
        </section>
      ))}
    </>
  );
}

function GameLogRow({
  league,
  log,
  entry,
  category,
}: {
  league: League;
  log: PlayerGameLog;
  entry: PlayerGameLogEntry;
  category?: string;
}) {
  const result = gameLogResult(entry);
  const headline = gameLogHeadline(log, entry, category);

  return (
    <Link
      href={gamePath({ league, id: entry.eventId })}
      className="flex flex-col gap-0.5 px-4 py-2 transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none"
    >
      {/* The row speaks one sentence; everything drawn below is its
          decoration, the roster row's treatment. */}
      <span className="sr-only">{spokenLabel(entry, headline)}</span>
      <span aria-hidden="true" className="flex items-center gap-2">
        {/* Room for "Wk 15" and "Dec 14", the two things this column says. */}
        <span className="w-11 shrink-0 tnum type-row-meta text-text-secondary">
          {when(entry, league)}
        </span>
        <span className="type-row-meta text-text-secondary">
          {entry.isAway ? "@" : "vs"}
        </span>
        <span className="flex h-[18px] w-[18px] shrink-0 items-center justify-center">
          {entry.opponentLogoUrl && (
            <Image
              src={entry.opponentLogoUrl}
              alt=""
              width={18}
              height={18}
              unoptimized
              className="h-[18px] w-[18px] object-contain"
            />
          )}
        </span>
        <span className="min-w-0 flex-1 truncate type-row-name text-text-primary">
          {entry.opponentAbbreviation ?? entry.opponentName ?? ""}
        </span>
        {result && (
          <span className="shrink-0 tnum type-row-name-em text-text-primary">
            {result}
          </span>
        )}
        <ChevronRight className="h-3 w-3 shrink-0 text-text-secondary" />
      </span>
      {headline && (
        <span
          aria-hidden="true"
          className="truncate pl-[3.25rem] tnum type-row-meta text-text-secondary"
        >
          {headline}
        </span>
      )}
    </Link>
  );
}

/** "Wk 15" in football, "Dec 14" elsewhere. */
function when(entry: PlayerGameLogEntry, league: League): string {
  if (entry.week !== undefined && hasWeeks(league)) return `Wk ${entry.week}`;
  const date = entry.date ? new Date(entry.date) : undefined;
  return date && !Number.isNaN(date.getTime())
    ? date.toLocaleDateString(undefined, { month: "short", day: "numeric" })
    : "";
}

function spokenLabel(entry: PlayerGameLogEntry, headline: string): string {
  const parts: string[] = [];
  const date = entry.date ? new Date(entry.date) : undefined;
  if (date && !Number.isNaN(date.getTime())) {
    parts.push(
      date.toLocaleDateString(undefined, {
        weekday: "long",
        month: "long",
        day: "numeric",
      })
    );
  }
  const opponent = entry.opponentName ?? entry.opponentAbbreviation ?? "opponent";
  parts.push(entry.isAway ? `at ${opponent}` : `versus ${opponent}`);
  if (entry.result === "W") parts.push("won");
  else if (entry.result === "L") parts.push("lost");
  else if (entry.result === "T") parts.push("tied");
  if (entry.teamScore !== undefined && entry.opponentScore !== undefined) {
    parts.push(`${entry.teamScore} to ${entry.opponentScore}`);
  }
  if (headline) parts.push(headline);
  return parts.join(", ");
}

function GamesSkeleton() {
  return (
    <section className="card-surface pb-1" aria-busy="true">
      <CardHeader title="Games" />
      {[0, 1, 2].map((row) => (
        <div key={row} className="flex flex-col gap-1.5 px-4 py-2.5">
          <Skeleton className="h-3.5 w-48" />
          <Skeleton className="ml-[3.25rem] h-2.5 w-32" />
        </div>
      ))}
    </section>
  );
}
