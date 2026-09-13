"use client";

// The H2H tab: what these two have done to each other, and the games that say
// so — the web twin of iOS `HeadToHeadPane`.
//
// Two cards. The tally leads — two marks, two numbers, the leader's in ink and
// the other muted, which is the centered score line from the header above
// applied to a series instead of a game. Then the meetings, newest first, as
// `GameRow`s that link to their own detail page: the same matchup language the
// rest of the app speaks, and a rivalry game from 2019 is one click from its
// box score.
//
// The window caption is not decoration. A series assembled from ten seasons of
// schedules is not the all-time record and must never be read as one, so
// "Since 2017" rides in the card header where the number can't be seen without
// it.

import { Fragment } from "react";
import type { Team } from "@/lib/types";
import {
  leadingSide,
  seriesIsEmpty,
  seriesSentence,
  windowLabel,
  type HeadToHead,
} from "@/lib/head-to-head";
import type { OnDemand } from "@/lib/hooks/use-on-demand";
import { CardHeader } from "@/components/card-header";
import { GameRow } from "@/components/game-row";
import { TeamLogo } from "@/components/team-logo";
import { Skeleton } from "@/components/ui/skeleton";
import { cn } from "@/lib/utils";

interface HeadToHeadPaneProps {
  away: Team;
  home: Team;
  state: OnDemand<HeadToHead>;
  /** The pane's own retry — the page's refresh reloads the summary, which is
   * a different fetch. */
  onRetry: () => void;
}

export function HeadToHeadPane({
  away,
  home,
  state,
  onRetry,
}: HeadToHeadPaneProps) {
  if (state.status === "loading") return <SeriesSkeleton />;
  if (state.status === "failed") {
    return (
      <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
        <p className="type-team-name text-text-secondary">
          Couldn&apos;t load the series.
        </p>
        <button
          type="button"
          onClick={onRetry}
          className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
        >
          Retry
        </button>
      </section>
    );
  }

  const series = state.value;
  const empty = seriesIsEmpty(series);
  const leader = leadingSide(series);

  return (
    <div className="flex flex-col gap-2">
      <section className="card-surface pb-1">
        <CardHeader title="Series" subtitle={windowLabel(series)} />
        {empty ? (
          // Honest about the window rather than claiming a first meeting:
          // these two may well have played in 1994, and the series simply
          // doesn't reach back that far.
          <p className="px-4 py-6 text-center type-team-name text-text-secondary">
            These two haven&apos;t met {windowLabel(series).toLowerCase()}.
          </p>
        ) : (
          <div
            // One sentence rather than six fragments, the GameRow rule. `img`
            // is what makes a non-interactive block announce its label and
            // collapse its children into it.
            role="img"
            aria-label={seriesSentence(series, away, home)}
            className="flex items-start gap-6 px-4 py-6"
          >
            <SeriesSide
              team={away}
              wins={series.awayWins}
              leads={leader === "away"}
            />
            <div className="flex shrink-0 flex-col items-center gap-1">
              {/* The mark's own row, held empty, so the dash lands level with
                  the two numbers instead of level with the crests above. */}
              <div className="h-8" />
              <span className="type-score-hero text-text-secondary">–</span>
              {series.ties > 0 && (
                <span className="type-meta text-text-secondary">
                  {series.ties} {series.ties === 1 ? "tie" : "ties"}
                </span>
              )}
            </div>
            <SeriesSide
              team={home}
              wins={series.homeWins}
              leads={leader === "home"}
            />
          </div>
        )}
      </section>

      {!empty && (
        <section className="card-surface pb-1">
          <CardHeader
            title="Previous meetings"
            subtitle={String(series.meetings.length)}
          />
          {series.meetings.map((game, index) => (
            <Fragment key={game.id}>
              {index > 0 && <div className="ml-4 border-t border-divider" />}
              {/* Ten rows can be ten different years. */}
              <GameRow game={game} showsYear />
            </Fragment>
          ))}
        </section>
      )}
    </div>
  );
}

/**
 * One team's half of the tally. The muted ink on the trailing side is the
 * header score line's own rule — the leader reads without color.
 */
function SeriesSide({
  team,
  wins,
  leads,
}: {
  team: Team;
  wins: number;
  leads: boolean;
}) {
  return (
    <div className="flex min-w-0 flex-1 flex-col items-center gap-1">
      <TeamLogo
        team={team}
        teamName={team.school}
        size="md"
        className="h-8 w-8 object-contain"
      />
      <span
        className={cn(
          "type-score-hero tnum",
          leads ? "text-text-primary" : "text-text-secondary"
        )}
      >
        {wins}
      </span>
      <span className="type-meta text-center text-text-secondary">
        {team.school}
      </span>
    </div>
  );
}

function SeriesSkeleton() {
  return (
    <div className="flex flex-col gap-2">
      <section className="card-surface pb-1">
        <CardHeader title="Series" />
        <div className="flex items-start justify-center gap-6 px-4 py-6">
          {[0, 1].map((side) => (
            <div key={side} className="flex flex-col items-center gap-2">
              <Skeleton className="h-8 w-8 rounded-full" />
              <Skeleton className="h-7 w-8" />
              <Skeleton className="h-2.5 w-16" />
            </div>
          ))}
        </div>
      </section>
    </div>
  );
}
