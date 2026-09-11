"use client";

// The Roster tab's card stack — iOS `RosterList` + `RosterRow`
// (Features/Teams/). A Coach card, then a card per position group in the
// payload's own order.
//
// FotMob's squad screen is the reference, built out of the app's existing
// table language (`CardHeader`, a captions row, inset dividers), so a roster
// reads like a standings table rather than a second dialect.
//
// The grouping is always ESPN's, never ours: football's six squads, hockey's
// five position names, and — for basketball, which ships no grouping at all —
// one card. Deriving guards and forwards from each athlete's position would
// be inventing a structure the payload doesn't have.

import { Fragment, useState } from "react";
import Image from "next/image";
import { CardHeader } from "@/components/card-header";
import { cn } from "@/lib/utils";
import { headshotThumbnail } from "@/lib/logos";
import type { League } from "@/lib/leagues";
import {
  rosterMetric,
  rosterMetricValue,
  rosterSentence,
  type RosterMetric,
} from "@/lib/roster-metric";
import type { RosterCoach, RosterPlayer, TeamRoster } from "@/lib/types";

interface RosterListProps {
  roster: TeamRoster;
  league: League;
}

export function RosterList({ roster, league }: RosterListProps) {
  const metric = rosterMetric(league);

  return (
    <>
      {roster.coach && <CoachCard coach={roster.coach} />}
      {roster.groups.map((group) => (
        <section key={group.name} className="card-surface pb-1">
          <CardHeader title={group.name} />
          <ColumnCaptions metric={metric} />
          {group.players.map((player, index) => (
            <Fragment key={player.id}>
              {index > 0 && <div className="ml-4 border-t border-divider" />}
              <PlayerRow player={player} metric={metric} />
            </Fragment>
          ))}
        </section>
      ))}
    </>
  );
}

function CoachCard({ coach }: { coach: RosterCoach }) {
  return (
    <section className="card-surface">
      <CardHeader title="Coach" />
      <div className="flex items-center justify-between gap-3 px-4 py-3">
        <span className="type-team-name truncate text-text-primary">
          {coach.name}
        </span>
        <span className="type-meta shrink-0 text-text-secondary">
          Head coach
        </span>
      </div>
    </section>
  );
}

/**
 * The roster table's captions — `#` / `PLAYER` / the league's own metric,
 * `StandingsList`'s caption row in the same widths as the rows below.
 *
 * Visual-only: rows speak themselves as sentences, so a screen reader skips
 * this entirely.
 */
function ColumnCaptions({ metric }: { metric: RosterMetric }) {
  return (
    <div
      aria-hidden="true"
      className="flex items-center gap-3 px-4 pb-2 pt-3 type-row-meta-medium text-text-secondary"
    >
      <span className="w-6 shrink-0 text-right">#</span>
      {/* The headshot gutter, so PLAYER sits over the names. */}
      <span className="w-9 shrink-0" />
      <span className="min-w-0 flex-1">PLAYER</span>
      <span style={{ width: metric.width }} className="shrink-0 text-right">
        {metric.caption}
      </span>
    </div>
  );
}

/**
 * One player's line: jersey gutter, headshot, name over the facts about
 * them, and the one metric column this league keeps.
 *
 * Not a link. There is no player page anywhere in the app, and a row that
 * looks tappable promises one.
 */
function PlayerRow({
  player,
  metric,
}: {
  player: RosterPlayer;
  metric: RosterMetric;
}) {
  const value = rosterMetricValue(player, metric);
  // Position, height, weight — and an injury designation where ESPN ships one
  // (the NFL's, and only for the handful carrying it). Each part drops out on
  // its own, so a row with none of them is just a name.
  const meta = [player.position, player.height, player.weight, player.injuryStatus]
    .filter((part): part is string => Boolean(part))
    .join(" · ");

  return (
    <div className="flex items-center gap-3 px-4 py-2">
      {/* The row speaks one sentence, since the captions above it are
          decoration — `StandingsList`'s treatment, and iOS's. The position is
          spoken in full inside it: "QB" is read as letters, and a roster is
          exactly the place a listener is learning who these people are. */}
      <span className="sr-only">{rosterSentence(player, metric)}</span>
      {/* The number labels the row; the name is its subject, so the number
          sits in the quieter ink. Tabular so a column of them lines up, and
          blank where ESPN ships no jersey rather than inventing a dash. */}
      <span
        aria-hidden="true"
        className="w-6 shrink-0 text-right type-team-name tnum text-text-secondary"
      >
        {player.jersey ?? ""}
      </span>
      <Headshot player={player} />
      <div aria-hidden="true" className="min-w-0 flex-1">
        <p className="type-team-name truncate text-text-primary">
          {player.name}
        </p>
        {meta && (
          <p className="type-meta truncate text-text-secondary">{meta}</p>
        )}
      </div>
      <span
        aria-hidden="true"
        style={{ width: metric.width }}
        className={cn(
          "shrink-0 text-right type-team-name tnum",
          value === undefined ? "text-text-secondary" : "text-text-primary"
        )}
      >
        {value ?? "\u2014"}
      </span>
    </div>
  );
}

/**
 * The player photo cropped into a quiet disc — the Leaders card's treatment,
 * at row scale. A player with no headshot keeps the disc, so the names stay
 * in one column.
 */
function Headshot({ player }: { player: RosterPlayer }) {
  const [failed, setFailed] = useState(false);
  // The thumbnail, or the full press photo for any URL the resizer doesn't
  // answer for.
  const src = player.headshotUrl
    ? (headshotThumbnail(player.headshotUrl) ?? player.headshotUrl)
    : undefined;

  return (
    <div
      aria-hidden="true"
      className="h-9 w-9 shrink-0 overflow-hidden rounded-full bg-bg-elevated"
    >
      {src && !failed && (
        <Image
          src={src}
          alt=""
          width={36}
          height={36}
          unoptimized
          loading="lazy"
          onError={() => setFailed(true)}
          className="h-full w-full object-cover"
        />
      )}
    </div>
  );
}
