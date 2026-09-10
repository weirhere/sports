"use client";

// The shared standings table — iOS `StandingsList` + `ConferenceStandingRow`
// + `StandingsColumnCaptions` (Features/Conference/). Rows stay in the
// provider's order (seed-backed — never re-sorted here); the championship
// cut is a full-bleed hairline against the rows' inset ones, decoded by
// text instead of swatches.

import { Fragment, useEffect, useRef } from "react";
import Link from "next/link";
import Image from "next/image";
import { titleGameIsTopTwo } from "@/lib/conferences";
import type { ConferenceStanding } from "@/lib/types";
import { cn } from "@/lib/utils";
import { teamPath } from "@/lib/routes";
import type { League } from "@/lib/leagues";
import {
  standingSentence,
  standingValue,
  standingsColumns,
} from "@/lib/standings-columns";

interface StandingsListProps {
  /** ESPN's standings order — tiebreaker-aware, never re-sorted. */
  entries: ConferenceStanding[];
  /** Which league's group-id space `conferenceId` belongs to. */
  league: League;
  /** Numeric conference group id, for the championship-cut gate. */
  conferenceId: number;
  /** The season the table describes, for the championship-cut gate. */
  year: number;
  /**
   * Whether the championship cut may render. False whenever the tables on
   * screen are **divisions**: in a divisional format the division winners
   * meet, so a per-division top-two footnote would claim the wrong thing.
   */
  showsCut?: boolean;
  /** Highlight (and scroll to) this team's own row. */
  highlightTeamId?: string;
}


/** "7-1" reads as "7 and 1" — a bare dash is swallowed or read as "minus". */

export function StandingsList({
  entries,
  league,
  conferenceId,
  year,
  showsCut = true,
  highlightTeamId,
}: StandingsListProps) {
  const highlightRef = useRef<HTMLAnchorElement>(null);

  useEffect(() => {
    // The anchor scroll: a push from a team page lands with the team's own
    // row in view — FotMob's table pattern.
    if (highlightTeamId) {
      highlightRef.current?.scrollIntoView({ block: "center" });
    }
    // Mount-only on purpose; a later re-render must not yank the scroll.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, []);

  if (entries.length === 0) {
    // ESPN's offseason standings can come back empty (Sun Belt did), and an
    // old season can omit a young conference.
    return (
      <p className="px-4 py-8 text-center type-team-name text-text-secondary">
        Standings TBA
      </p>
    );
  }

  // The cut renders only when the top two are knowably the top two:
  // seed-backed placement (payload order alone is not the standings), a
  // table bigger than the pair, and a non-0-0 record so preseason's
  // carried-over order claims nothing. Gated exactly like iOS.
  const columns = standingsColumns(league);
  const leaderRecord = entries[0]?.conferenceRecord;
  const cutIsVisible =
    showsCut &&
    titleGameIsTopTwo(conferenceId, year, league) &&
    entries.length > 2 &&
    entries[0].playoffSeed === 1 &&
    entries[1].playoffSeed === 2 &&
    leaderRecord !== undefined &&
    leaderRecord !== "0-0";

  return (
    <div>
      {/* Visual-only captions — rows speak themselves as sentences.
          Which columns these are is per league: football shows a
          conference record beside the overall, the NBA win percentage and
          games back, the NHL games played, its three-number record and the
          points it's actually ranked on. */}
      <div
        aria-hidden="true"
        className="flex items-center gap-3 px-4 pb-2 pt-3 type-row-meta-medium text-text-secondary"
      >
        <span className="w-4 shrink-0 text-right">#</span>
        <span className="w-5 shrink-0" />
        <span className="min-w-0 flex-1">TEAM</span>
        {columns.map((column) => (
          <span
            key={column.field}
            style={{ width: column.width }}
            className="shrink-0 text-right"
          >
            {column.caption}
          </span>
        ))}
      </div>
      {entries.map((standing, index) => {
        const isHighlighted = standing.team.id === highlightTeamId;
        const qualifies = cutIsVisible && index < 2;
        // The row speaks its own sentence, since the captions above are
        // decoration — and it says "in the championship game" out loud,
        // because a screen reader reads no edges.
        const label =
          standingSentence(standing, league, index + 1) +
          (qualifies ? ", in the championship game" : "");
        return (
          <Fragment key={standing.team.id}>
            {index > 0 && <div className="ml-4 border-t border-divider" />}
            <Link
              ref={isHighlighted ? highlightRef : undefined}
              href={teamPath(standing.team)}
              aria-label={label}
              className={cn(
                "relative flex items-center gap-3 py-2.5 pl-4 pr-4 transition-colors hover:bg-bg-header",
                isHighlighted && "bg-bg-header"
              )}
            >
              {/* The championship cut: a bar down the qualifying rows'
                  leading edge, FotMob's promotion mechanism. A divider
                  could only say where the line fell; the bar says which
                  teams are in, and survives a scroll that leaves the line
                  off screen. Ink, not colour — the budget stays at three. */}
              {qualifies && (
                <span
                  aria-hidden="true"
                  className="absolute inset-y-0 left-0 w-[3px] bg-text-primary"
                />
              )}
              <span className="w-4 shrink-0 text-right tnum type-meta-em text-text-secondary">
                {index + 1}
              </span>
              <Image
                src={standing.team.logoUrl}
                alt=""
                width={20}
                height={20}
                className="h-5 w-5 shrink-0 object-contain"
                unoptimized
              />
              <span className="min-w-0 flex-1 truncate type-team-name text-text-primary">
                {standing.team.school}
              </span>
              {columns.map((column) => (
                <span
                  key={column.field}
                  style={{ width: column.width }}
                  className="shrink-0 text-right tnum type-team-name text-text-primary"
                >
                  {standingValue(standing, column) ?? "—"}
                </span>
              ))}
            </Link>
          </Fragment>
        );
      })}
      {cutIsVisible && (
        // The legend keys the bar. Without it the mark is decoration.
        <p className="flex items-center gap-2 px-4 py-2 type-meta text-text-secondary">
          <span
            aria-hidden="true"
            className="inline-block h-3 w-[3px] shrink-0 bg-text-primary"
          />
          Championship game
        </p>
      )}
    </div>
  );
}
