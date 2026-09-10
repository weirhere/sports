"use client";

// The Plays tab's two lists — the web twins of iOS `PlayByPlayList` and
// `PeriodPlayList`.
//
// **Football groups by drive**, because a possession is the unit its game is
// played in: one card of accordion rows, each expanding into its plays. A
// full game is 22 possessions, and the density target is the reason it is one
// card rather than a card each. The Drives card moved in here — leaving it on
// Summary would print the same rows in two tabs.
//
// **Everything else groups by period**, because ESPN ships no drives for
// those leagues and the period is the only unit their flat feed carries (a
// basketball game is ~490 plays).

import { useState } from "react";
import Image from "next/image";
import { ChevronDown } from "lucide-react";
import type { Game, GameDrive, GameTeam, PlayItem } from "@/lib/types";
import { periodText, allowsShootout } from "@/lib/period-label";
import { PlayRow } from "./play-row";
import { cn } from "@/lib/utils";

/** Football: one accordion row per possession, newest first. */
export function DrivePlayList({
  drives,
  game,
  scoringOnly,
}: {
  drives: GameDrive[];
  game: Game;
  scoringOnly: boolean;
}) {
  const shown = scoringOnly
    ? drives
        .map((drive) => ({
          ...drive,
          plays: (drive.plays ?? []).filter((play) => play.isScoringPlay),
        }))
        // A drive with nothing that scored drops out entirely.
        .filter((drive) => drive.plays.length > 0)
    : drives;
  // Newest first: what just happened is the question the tab is opened with.
  const ordered = [...shown].reverse();

  return (
    <section className="card-surface pb-1">
      {ordered.map((drive, index) => (
        <div key={drive.id}>
          {index > 0 && <div className="ml-4 border-t border-divider" />}
          <DriveRow
            drive={drive}
            game={game}
            defaultExpanded={scoringOnly}
          />
        </div>
      ))}
    </section>
  );
}

function DriveRow({
  drive,
  game,
  defaultExpanded,
}: {
  drive: GameDrive;
  game: Game;
  defaultExpanded: boolean;
}) {
  const [expanded, setExpanded] = useState(defaultExpanded);
  const team = [game.homeTeam, game.awayTeam].find(
    (side: GameTeam) => String(side.team.espnId) === drive.teamId
  );
  const plays = drive.plays ?? [];
  const label = [team?.team.school, drive.result?.toLowerCase(), drive.summary]
    .filter(Boolean)
    .join(", ");

  return (
    <div>
      <button
        type="button"
        // A drive ESPN shipped no plays for can't open onto anything.
        disabled={plays.length === 0}
        onClick={() => setExpanded((was) => !was)}
        aria-expanded={plays.length > 0 ? expanded : undefined}
        aria-label={label}
        className="flex w-full items-center gap-3 px-4 py-2 text-left transition-colors hover:bg-bg-header disabled:hover:bg-transparent"
      >
        <span
          aria-hidden="true"
          className="flex h-4 w-4 shrink-0 items-center justify-center"
        >
          {team && (
            <Image
              src={team.team.logoUrl}
              alt=""
              width={16}
              height={16}
              unoptimized
              className="h-4 w-4 object-contain"
            />
          )}
        </span>
        <span
          aria-hidden="true"
          className={cn(
            "text-text-primary",
            drive.isScore ? "type-meta-em" : "type-meta"
          )}
        >
          {drive.result ?? "—"}
        </span>
        {drive.summary && (
          <span
            aria-hidden="true"
            className="ml-auto text-right type-meta tnum text-text-secondary"
          >
            {drive.summary}
          </span>
        )}
        {plays.length > 0 && (
          <ChevronDown
            aria-hidden="true"
            className={cn(
              "ml-1 h-3 w-3 shrink-0 text-text-secondary transition-transform",
              expanded && "rotate-180"
            )}
          />
        )}
      </button>
      {expanded &&
        plays.map((play) => (
          <PlayRow key={play.id} play={play} game={game} />
        ))}
    </div>
  );
}

/** Basketball and hockey: one accordion row per period, newest first. */
export function PeriodPlayList({
  plays,
  game,
  scoringOnly,
}: {
  plays: PlayItem[];
  game: Game;
  scoringOnly: boolean;
}) {
  const shown = scoringOnly
    ? plays.filter((play) => play.isScoringPlay)
    : plays;

  // Period order, newest first; a play with no period of its own trails.
  const byPeriod = new Map<number, PlayItem[]>();
  const orphans: PlayItem[] = [];
  for (const play of shown) {
    if (play.period === undefined) {
      orphans.push(play);
      continue;
    }
    const bucket = byPeriod.get(play.period);
    if (bucket) bucket.push(play);
    else byPeriod.set(play.period, [play]);
  }
  const periods = [...byPeriod.keys()].sort((a, b) => b - a);
  const shootout = allowsShootout(game);

  return (
    <section className="card-surface pb-1">
      {periods.map((period, index) => (
        <div key={period}>
          {index > 0 && <div className="ml-4 border-t border-divider" />}
          <PeriodRow
            title={periodText(period, game.league, shootout)}
            plays={byPeriod.get(period) ?? []}
            game={game}
            // The period in progress is the one being watched, so it opens.
            defaultExpanded={index === 0}
          />
        </div>
      ))}
      {orphans.length > 0 && (
        <div>
          {periods.length > 0 && <div className="ml-4 border-t border-divider" />}
          <PeriodRow
            title="Other"
            plays={orphans}
            game={game}
            defaultExpanded={periods.length === 0}
          />
        </div>
      )}
    </section>
  );
}

function PeriodRow({
  title,
  plays,
  game,
  defaultExpanded,
}: {
  title: string;
  plays: PlayItem[];
  game: Game;
  defaultExpanded: boolean;
}) {
  const [expanded, setExpanded] = useState(defaultExpanded);
  return (
    <div>
      <button
        type="button"
        onClick={() => setExpanded((was) => !was)}
        aria-expanded={expanded}
        aria-label={`${title}, ${plays.length} ${plays.length === 1 ? "play" : "plays"}`}
        className="flex w-full items-center gap-3 px-4 py-2 text-left transition-colors hover:bg-bg-header"
      >
        <span aria-hidden="true" className="type-meta-em text-text-primary">
          {title}
        </span>
        <span aria-hidden="true" className="tnum type-meta text-text-secondary">
          {plays.length}
        </span>
        <ChevronDown
          aria-hidden="true"
          className={cn(
            "ml-auto h-3 w-3 shrink-0 text-text-secondary transition-transform",
            expanded && "rotate-180"
          )}
        />
      </button>
      {expanded &&
        // The feed arrives oldest-first; inside a period the newest play is
        // the one being looked for, same as the periods themselves.
        [...plays].reverse().map((play) => (
          <PlayRow key={play.id} play={play} game={game} />
        ))}
    </div>
  );
}
