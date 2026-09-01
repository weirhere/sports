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

interface StandingsListProps {
  /** ESPN's standings order — tiebreaker-aware, never re-sorted. */
  entries: ConferenceStanding[];
  /** Numeric conference group id, for the championship-cut gate. */
  conferenceId: number;
  /** The season the table describes, for the championship-cut gate. */
  year: number;
  /** Highlight (and scroll to) this team's own row. */
  highlightTeamId?: string;
}

function record(summary: string | undefined, wins: number, losses: number) {
  return summary ?? `${wins}-${losses}`;
}

/** "7-1" reads as "7 and 1" — a bare dash is swallowed or read as "minus". */
function spoken(recordText: string): string {
  return recordText.replaceAll("-", " and ");
}

export function StandingsList({
  entries,
  conferenceId,
  year,
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
  const leaderRecord = entries[0]?.conferenceRecord;
  const cutIsVisible =
    titleGameIsTopTwo(conferenceId, year) &&
    entries.length > 2 &&
    entries[0].playoffSeed === 1 &&
    entries[1].playoffSeed === 2 &&
    leaderRecord !== undefined &&
    leaderRecord !== "0-0";

  return (
    <div>
      {/* Visual-only captions — rows speak themselves as sentences. */}
      <div
        aria-hidden="true"
        className="flex items-center gap-3 px-4 pb-2 pt-3 type-row-meta-medium text-text-secondary"
      >
        <span className="w-4 shrink-0 text-right">#</span>
        <span className="w-5 shrink-0" />
        <span className="min-w-0 flex-1">TEAM</span>
        <span className="w-11 shrink-0 text-right">CONF</span>
        <span className="w-11 shrink-0 text-right">OVR</span>
      </div>
      {entries.map((standing, index) => {
        const conf = record(
          standing.conferenceRecord,
          standing.conferenceWins,
          standing.conferenceLosses
        );
        const overall = record(
          standing.overallRecord,
          standing.overallWins,
          standing.overallLosses
        );
        const isHighlighted = standing.team.id === highlightTeamId;
        // One sentence: "Number 3, Georgia, 7 and 1 in conference, 13 and
        // 2 overall" — the iOS row's VoiceOver summary.
        const label = `Number ${index + 1}, ${standing.team.school}, ${spoken(
          conf
        )} in conference, ${spoken(overall)} overall`;
        return (
          <Fragment key={standing.team.id}>
            {index > 0 &&
              (cutIsVisible && index === 2 ? (
                // Full-bleed where every other divider is inset — that
                // difference is the whole mark. Chrome, not color.
                <div className="border-t border-divider" />
              ) : (
                <div className="ml-4 border-t border-divider" />
              ))}
            <Link
              ref={isHighlighted ? highlightRef : undefined}
              href={`/team/${standing.team.id}`}
              aria-label={label}
              className={cn(
                "flex items-center gap-3 px-4 py-2.5 transition-colors hover:bg-bg-header",
                isHighlighted && "bg-bg-header"
              )}
            >
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
              <span className="w-11 shrink-0 text-right tnum type-team-name text-text-primary">
                {conf}
              </span>
              <span className="w-11 shrink-0 text-right tnum type-team-name text-text-primary">
                {overall}
              </span>
            </Link>
          </Fragment>
        );
      })}
      {cutIsVisible && (
        <p className="px-4 py-2 type-meta text-text-secondary">
          Top two reach the championship game
        </p>
      )}
    </div>
  );
}
