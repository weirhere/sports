"use client";

// Who leads the team, category by category — iOS `TeamLeadersCard`
// (2026-09-24). Passing, rushing, receiving and the defence in football;
// points, rebounds and assists in the NBA; points, goals and the goalie in
// the NHL.
//
// The game page's Leaders card answers "who did it tonight"; this answers
// "who has done it all season", in the same row language: headshot disc,
// name, the number that earned the row. A row links to the player's page
// where the page can open them — see `ResolvedTeamLeader.onRoster`.

import { Fragment, use, useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { CardHeader } from "@/components/card-header";
import type { League } from "@/lib/leagues";
import { playerHref } from "@/lib/player-profile";
import {
  leaderValueIsStatLine,
  type ResolvedTeamLeader,
  type TeamLeaders,
} from "@/lib/espn/team-stats";

interface TeamLeadersCardProps {
  league: League;
  teamId: string;
  leaders: Promise<TeamLeaders>;
}

export function TeamLeadersCard({ league, teamId, leaders }: TeamLeadersCardProps) {
  const resolved = use(leaders);
  if (resolved.leaders.length === 0) return null;

  return (
    <section className="card-surface">
      {/* "2025-26" only when the season shown isn't the one in progress. */}
      <CardHeader title="Leaders" subtitle={resolved.seasonLabel} />
      {resolved.leaders.map((leader, index) => (
        <Fragment key={leader.category}>
          {/* Inset past the headshot, to the name. */}
          {index > 0 && <div className="ml-[60px] border-t border-divider" />}
          <LeaderRow leader={leader} league={league} teamId={teamId} />
        </Fragment>
      ))}
    </section>
  );
}

function LeaderRow({
  leader,
  league,
  teamId,
}: {
  leader: ResolvedTeamLeader;
  league: League;
  teamId: string;
}) {
  const statLine = leaderValueIsStatLine(leader);
  const label = `${leader.title} leader, ${leader.name}, ${leader.value}`;
  const body = (
    <>
      <Headshot url={leader.headshotUrl} />
      <span aria-hidden="true" className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="type-row-meta text-text-secondary">{leader.title}</span>
        <span className="truncate type-row-name text-text-primary">
          {leader.name}
        </span>
        {statLine && (
          <span className="truncate tnum type-row-meta text-text-secondary">
            {leader.value}
          </span>
        )}
      </span>
      {!statLine && (
        <span aria-hidden="true" className="shrink-0 tnum type-row-name-em text-text-primary">
          {leader.value}
        </span>
      )}
      {leader.onRoster && (
        <ChevronRight
          aria-hidden="true"
          className="h-3 w-3 shrink-0 text-text-secondary"
        />
      )}
    </>
  );
  const className = "flex items-center gap-3 px-4 py-2";

  if (!leader.onRoster) {
    return (
      <div role="group" aria-label={label} className={className}>
        {body}
      </div>
    );
  }
  return (
    <Link
      href={playerHref(league, teamId, leader.athleteId)}
      aria-label={label}
      className={`${className} transition-colors hover:bg-bg-header focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-inset focus-visible:ring-text-secondary`}
    >
      {body}
    </Link>
  );
}

/** A quiet disc when ESPN has no photo, or the photo 404s. */
function Headshot({ url }: { url?: string }) {
  const [failed, setFailed] = useState(false);
  return (
    <span
      aria-hidden="true"
      className="flex h-8 w-8 shrink-0 overflow-hidden rounded-full bg-bg-elevated"
    >
      {url && !failed && (
        <Image
          src={url}
          alt=""
          width={32}
          height={32}
          unoptimized
          onError={() => setFailed(true)}
          className="h-full w-full object-cover"
        />
      )}
    </span>
  );
}
