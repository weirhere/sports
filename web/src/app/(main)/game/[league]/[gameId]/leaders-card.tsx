"use client";

// Passing / rushing / receiving leaders, FotMob two-sided (iOS
// LeadersList): each category is a centered label with the two sides'
// leaders anchored to their header sides — away left-aligned on the left,
// home right-aligned on the right — 40px headshot discs on the outer edges
// wearing a 15px team-mark badge. No headshot → quiet bg-elevated disc.

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import type { League } from "@/lib/leagues";
import { playerHref } from "@/lib/player-profile";
import type { GameLeader, GameTeam, LeaderCategory } from "@/lib/types";
import { cn } from "@/lib/utils";
import { DetailCard } from "./detail-card";

interface LeadersCardProps {
  leaders: LeaderCategory[];
  awayTeam: GameTeam;
  homeTeam: GameTeam;
  league: League;
}

export function LeadersCard({
  leaders,
  awayTeam,
  homeTeam,
  league,
}: LeadersCardProps) {
  return (
    <DetailCard title="Leaders">
      <div className="flex flex-col gap-3 px-4 pb-3 pt-2">
        {leaders.map((category) => (
          <div key={category.id} className="flex flex-col items-center gap-1">
            <h3 className="type-meta uppercase text-text-secondary">
              {category.label}
            </h3>
            <div className="flex w-full items-start gap-3">
              <LeaderSide
                leader={category.away}
                team={awayTeam}
                side="away"
                league={league}
              />
              <LeaderSide
                leader={category.home}
                team={homeTeam}
                side="home"
                league={league}
              />
            </div>
          </div>
        ))}
      </div>
    </DetailCard>
  );
}

/**
 * Half the row, claimed even when a side has no leader so the other side
 * stays anchored to its edge. One element per player — the team location
 * rides in the spoken sentence, since alignment carries it visually.
 *
 * **The whole side is the link**, photo and stat line included, rather than
 * the name alone: this is a two-column card on a phone and a name is a small
 * target. The `aria-label` that was already here becomes the link's own
 * name, which is what it should have been doing all along — it was sitting
 * on a plain `div`, where support for it is uneven.
 *
 * The team in the URL is the side this leader is filed under, which is what
 * `transformLeaders` looked them up by, so it can't disagree with the crest
 * on the photo.
 */
function LeaderSide({
  leader,
  team,
  side,
  league,
}: {
  leader?: GameLeader;
  team: GameTeam;
  side: "away" | "home";
  league: League;
}) {
  if (!leader) {
    return <div className="flex-1" />;
  }
  const away = side === "away";
  const label = [team.team.school, leader.name, leader.statLine]
    .filter(Boolean)
    .join(", ");
  const className = cn(
    "flex min-w-0 flex-1 items-start gap-2",
    !away && "flex-row-reverse"
  );
  const body = (
    <>
      <Headshot leader={leader} team={team} side={side} />
      <div
        aria-hidden="true"
        className={cn(
          "flex min-w-0 flex-col gap-0.5",
          away ? "items-start text-left" : "items-end text-right"
        )}
      >
        <span className="type-team-name text-text-primary">{leader.name}</span>
        <span className="type-meta tnum text-text-secondary">
          {leader.statLine}
        </span>
      </div>
    </>
  );

  if (!leader.athleteId) {
    return (
      <div aria-label={label} className={className}>
        {body}
      </div>
    );
  }

  return (
    <Link
      href={playerHref(league, String(team.team.espnId), leader.athleteId)}
      aria-label={label}
      className={cn(
        className,
        "rounded-md transition-opacity hover:opacity-70 focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-text-secondary"
      )}
    >
      {body}
    </Link>
  );
}

/**
 * The player photo cropped into a quiet disc, wearing a small team mark on
 * its outer bottom corner. Headshots ride the logo exception — content
 * imagery in color, chrome stays mono.
 */
function Headshot({
  leader,
  team,
  side,
}: {
  leader: GameLeader;
  team: GameTeam;
  side: "away" | "home";
}) {
  const [failed, setFailed] = useState(false);
  const showPhoto = leader.headshotUrl !== undefined && !failed;

  return (
    <div aria-hidden="true" className="relative h-10 w-10 shrink-0">
      <div className="h-10 w-10 overflow-hidden rounded-full bg-bg-elevated">
        {showPhoto && (
          <Image
            src={leader.headshotUrl!}
            alt=""
            width={40}
            height={40}
            unoptimized
            onError={() => setFailed(true)}
            className="h-full w-full object-cover"
          />
        )}
      </div>
      <Image
        src={team.team.logoUrl}
        alt=""
        width={15}
        height={15}
        unoptimized
        className={cn(
          "absolute bottom-0 h-[15px] w-[15px] object-contain",
          side === "away" ? "-left-0.5" : "-right-0.5"
        )}
      />
    </div>
  );
}
