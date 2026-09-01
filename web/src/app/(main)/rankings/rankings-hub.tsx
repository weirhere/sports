"use client";

// The hub's row list (iOS RankingsScreen + Top25Row + ConferenceListRow):
// each row is its own card-surface, one uniform FotMob-tight list. The row
// navigates; the trailing star follows without navigating.

import Link from "next/link";
import { Star, Trophy } from "lucide-react";
import { conferenceLogoUrl, conferenceName, orderedIds } from "@/lib/conferences";
import type { ConferenceStanding, ConferenceStandingsGroup, Poll } from "@/lib/types";
import { ConferenceLogo } from "@/components/theme/conference-logo";
import { useFavoritesContext } from "@/components/providers/favorites-provider";

interface RankingsHubProps {
  /** The FBS polls, filtered and in picker order (AP first when present). */
  polls: Poll[];
  /** All conferences' standings, or null when the fetch failed. */
  conferences: ConferenceStandingsGroup[] | null;
}

interface ConferenceRowData {
  id: number;
  name: string;
  leader?: ConferenceStanding;
}

export function RankingsHub({ polls, conferences }: RankingsHubProps) {
  const { isFavoriteConference } = useFavoritesContext();

  // Registry-driven: every known FBS conference renders in browsing order
  // (P4 → G5 → Independents); the standings only feed the leader teaser.
  // A standings failure (conferences === null) hides the rows entirely —
  // it never errors the poll.
  const rows: ConferenceRowData[] | null =
    conferences === null
      ? null
      : orderedIds.map((id) => ({
          id,
          name: conferenceName(id),
          leader: conferences.find((group) => group.id === String(id))
            ?.entries[0],
        }));

  const followedRows =
    rows?.filter((row) => isFavoriteConference(String(row.id))) ?? [];

  if (polls.length === 0 && rows === null) {
    return (
      <p className="py-20 text-center type-team-name text-text-secondary">
        No rankings right now
      </p>
    );
  }

  return (
    <div className="flex flex-col gap-2">
      {(polls.length > 0 || followedRows.length > 0) && (
        <SectionHeading title="Following" />
      )}
      {polls.length > 0 && <Top25Row polls={polls} />}
      {/* A followed conference appears in BOTH sections — sections stay
          complete, never deduplicated. */}
      {followedRows.map((row) => (
        <ConferenceRow key={`following-${row.id}`} row={row} />
      ))}
      {rows !== null && (
        <>
          <SectionHeading title="All conferences" />
          {rows.map((row) => (
            <ConferenceRow key={`all-${row.id}`} row={row} />
          ))}
        </>
      )}
    </div>
  );
}

function SectionHeading({ title }: { title: string }) {
  return (
    <h2 className="px-3 pt-2 type-team-name-em text-text-primary">{title}</h2>
  );
}

/** The poll's row — same shape as a conference row, leading the list. */
function Top25Row({ polls }: { polls: Poll[] }) {
  // "#1 Ohio State" from the first displayed poll (AP when present). The
  // row doesn't track the picker choice — it's a teaser, not the poll.
  const top = polls[0]?.ranks[0];
  return (
    <Link
      href="/rankings/poll"
      className="flex min-h-12 items-center gap-3 px-4 py-[7px] transition-colors card-surface hover:bg-bg-header"
      aria-label={top ? `Top 25, number 1 ${top.team.school}` : "Top 25"}
    >
      {/* Same trophy footprint as the conference marks (18px + disc pad)
          so the mark column lines up. */}
      <span className="inline-flex h-6 w-6 shrink-0 items-center justify-center">
        <Trophy aria-hidden="true" className="h-[15px] w-[15px] text-text-secondary" />
      </span>
      <span className="type-team-name text-text-primary">Top 25</span>
      {top && (
        <span className="truncate type-meta text-text-secondary">
          #1 {top.team.school}
        </span>
      )}
    </Link>
  );
}

/**
 * One conference: mark, name, leader teaser, follow star. The row
 * navigates to the conference page; the star doesn't.
 */
function ConferenceRow({ row }: { row: ConferenceRowData }) {
  const { isFavoriteConference, toggleFavoriteConference } =
    useFavoritesContext();
  const followed = isFavoriteConference(String(row.id));

  // "Ole Miss · 7-1" — the current leader, only once records exist. A 0-0
  // "leader" is last season's carry-over, so preseason shows no teaser.
  const record = row.leader?.conferenceRecord;
  const teaser =
    row.leader && record && record !== "0-0"
      ? `${row.leader.team.school} · ${record}`
      : undefined;

  const spokenRecord = record?.replaceAll("-", " and ");
  const rowLabel =
    row.leader && teaser
      ? `${row.name}, led by ${row.leader.team.school} at ${spokenRecord}`
      : row.name;

  return (
    <div className="flex min-h-12 items-center gap-3 pr-2 card-surface">
      <Link
        href={`/conference/${row.id}`}
        className="flex min-w-0 flex-1 items-center gap-3 self-stretch px-4 py-[7px] transition-colors hover:bg-bg-header"
        aria-label={rowLabel}
      >
        <ConferenceLogo src={conferenceLogoUrl(row.id)} name="" />
        <span className="type-team-name text-text-primary">{row.name}</span>
        {teaser && (
          <span className="truncate type-meta text-text-secondary">
            {teaser}
          </span>
        )}
      </Link>
      <button
        type="button"
        onClick={() => toggleFavoriteConference(String(row.id))}
        aria-label={followed ? `Unfollow ${row.name}` : `Follow ${row.name}`}
        aria-pressed={followed}
        className="flex h-9 w-9 shrink-0 items-center justify-center rounded-full text-text-secondary transition-colors hover:text-text-primary"
      >
        <Star
          aria-hidden="true"
          className={followed ? "h-4 w-4 fill-current" : "h-4 w-4"}
        />
      </button>
    </div>
  );
}
