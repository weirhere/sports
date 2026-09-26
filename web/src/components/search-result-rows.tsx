"use client";

// The search page's rows — iOS `SearchTeamRow`, `SearchConferenceRow` and
// `SearchPlayerRow` (sports/Features/Search/, 2026-09-21). One shape for
// all three so a mixed list reads as peers: a 26px mark, a name over a
// quiet second line, every row the Leagues accordion header's height.
//
// Each is a link, and each takes an `onSelect` that runs before the
// navigation — that is how a tap becomes a recent search.

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { UserRound } from "lucide-react";
import { TeamLogo } from "@/components/team-logo";
import { ConferenceLogo } from "@/components/theme/conference-logo";
import {
  conferenceLogoUrl,
  conferenceName,
  divisionForTeamId,
} from "@/lib/conferences";
import { displayName, shortName, type League } from "@/lib/leagues";
import { conferencePath, teamPath } from "@/lib/routes";
import { playerHref } from "@/lib/player-profile";
import { teamDisplayName } from "@/lib/athlete-search";
import type { ConferenceRef } from "@/lib/search-ranking";
import type { Team } from "@/lib/types";

/**
 * The Leagues accordion header's height (iOS `SearchScreen.cardHeight`: 34pt
 * of content plus 7pt and 4pt paddings each side = 56). A minimum, never a
 * fixed height, so a row at a large text size can outgrow it rather than
 * clip.
 */
export const SEARCH_CARD_MIN_HEIGHT = "min-h-14";

const ROW =
  "flex min-w-0 flex-1 items-center gap-3 px-4 py-3 transition-colors hover:bg-bg-header focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-inset focus-visible:ring-ring";

/** The shared 26px box every row's mark sits in, so a narrow conference
 *  mark can't pull its text off the rail the other rows share. */
function MarkBox({ children }: { children: React.ReactNode }) {
  return (
    <span
      aria-hidden="true"
      className="flex h-[26px] w-[26px] shrink-0 items-center justify-center"
    >
      {children}
    </span>
  );
}

function TwoLines({ title, subtitle }: { title: string; subtitle?: string }) {
  return (
    <span aria-hidden="true" className="flex min-w-0 flex-col gap-0.5">
      <span className="truncate type-team-name text-text-primary">{title}</span>
      {subtitle && (
        <span className="truncate type-meta text-text-secondary">{subtitle}</span>
      )}
    </span>
  );
}

/**
 * The group a team plays in — the **division** for the NFL, where the
 * directory files every team under its conference and so could only ever
 * say AFC or NFC. Undefined rather than "Other" when nothing is known: a row
 * that says nothing beats one that says the wrong thing confidently.
 */
function teamGroupName(team: Team): string | undefined {
  if (team.league === "nfl") {
    const division = divisionForTeamId(team.id, "nfl");
    if (division !== undefined) {
      const name = conferenceName(division, "nfl");
      if (name !== "Other") return name;
    }
  }
  const id = Number(team.conferenceId);
  if (!Number.isInteger(id)) return undefined;
  const name = conferenceName(id, team.league);
  return name === "Other" ? undefined : name;
}

/**
 * "NFL • AFC East", "NCAAF • Big Ten" — league first (Andy, 2026-09-21),
 * because the conference alone doesn't name the sport: "Eastern" is the
 * Lightning's and the Bucks'. Wide-to-narrow, the way an address reads.
 */
function teamSubtitle(team: Team, league: string, separator = " • "): string {
  const group = teamGroupName(team);
  return group ? `${league}${separator}${group}` : league;
}

export function SearchTeamRow({
  team,
  onSelect,
}: {
  team: Team;
  onSelect: () => void;
}) {
  // The full name — "Tampa Bay Buccaneers", not "Tampa Bay".
  const name = teamDisplayName(team) || team.school;
  return (
    <Link
      href={teamPath(team)}
      onClick={onSelect}
      // Spoken with the league as a phrase: an initialism is a caption, not
      // a word, and "N-C-A-A-F" letter by letter is worse than the name.
      // A comma where the eye gets a bullet, which some readers announce.
      aria-label={`${name}, ${teamSubtitle(team, displayName(team.league), ", ")}`}
      className={ROW}
    >
      <MarkBox>
        <TeamLogo
          team={team}
          teamName=""
          size="sm"
          className="h-[26px] w-[26px] object-contain"
        />
      </MarkBox>
      <TwoLines title={name} subtitle={teamSubtitle(team, shortName(team.league))} />
    </Link>
  );
}

export function SearchConferenceRow({
  conference,
  onSelect,
}: {
  conference: ConferenceRef;
  onSelect: () => void;
}) {
  // The league under the name, not a team count: a conference only means
  // something inside one — "NFC West" and "Big Ten" are the same kind of
  // row, and the sport is what separates them.
  return (
    <Link
      href={conferencePath(conference)}
      onClick={onSelect}
      aria-label={`${conference.name}, ${displayName(conference.league)}`}
      className={ROW}
    >
      <MarkBox>
        <ConferenceLogo
          src={conferenceLogoUrl(conference.id, conference.league)}
          name=""
        />
      </MarkBox>
      <TwoLines title={conference.name} subtitle={shortName(conference.league)} />
    </Link>
  );
}

export interface SearchPlayer {
  athleteId: string;
  league: League;
  name: string;
  teamId: string;
  teamName?: string;
  headshotUrl?: string;
}

export function SearchPlayerRow({
  player,
  onSelect,
}: {
  player: SearchPlayer;
  onSelect: () => void;
}) {
  return (
    <Link
      href={playerHref(player.league, player.teamId, player.athleteId)}
      onClick={onSelect}
      aria-label={
        player.teamName ? `${player.name}, ${player.teamName}` : player.name
      }
      className={ROW}
    >
      <MarkBox>
        <Headshot url={player.headshotUrl} />
      </MarkBox>
      {/* The club under the name, not beside it: a person and their team
          are one fact read top-down. */}
      <TwoLines title={player.name} subtitle={player.teamName} />
    </Link>
  );
}

/**
 * A photograph, so it clips to a circle. The fallback is a monochrome
 * silhouette rather than an empty disc — plenty of athletes have no
 * portrait on file, and a blank circle reads as a failed load.
 */
function Headshot({ url }: { url?: string }) {
  const [failed, setFailed] = useState(false);
  return (
    <span className="flex h-[26px] w-[26px] items-center justify-center overflow-hidden rounded-full bg-bg-elevated">
      {url && !failed ? (
        <Image
          src={url}
          alt=""
          width={26}
          height={26}
          unoptimized
          onError={() => setFailed(true)}
          className="h-full w-full object-cover"
        />
      ) : (
        <UserRound className="h-4 w-4 text-text-secondary opacity-60" />
      )}
    </span>
  );
}
