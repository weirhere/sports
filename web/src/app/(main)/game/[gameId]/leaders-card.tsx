"use client";

// Passing / rushing / receiving leaders, FotMob two-sided (iOS
// LeadersList): each category is a centered label with the two sides'
// leaders anchored to their header sides — away left-aligned on the left,
// home right-aligned on the right — 40px headshot discs on the outer edges
// wearing a 15px team-mark badge. No headshot → quiet bg-elevated disc.

import { useState } from "react";
import Image from "next/image";
import type { GameLeader, GameTeam, LeaderCategory } from "@/lib/types";
import { cn } from "@/lib/utils";
import { DetailCard } from "./detail-card";

interface LeadersCardProps {
  leaders: LeaderCategory[];
  awayTeam: GameTeam;
  homeTeam: GameTeam;
}

export function LeadersCard({ leaders, awayTeam, homeTeam }: LeadersCardProps) {
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
              />
              <LeaderSide
                leader={category.home}
                team={homeTeam}
                side="home"
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
 */
function LeaderSide({
  leader,
  team,
  side,
}: {
  leader?: GameLeader;
  team: GameTeam;
  side: "away" | "home";
}) {
  if (!leader) {
    return <div className="flex-1" />;
  }
  const away = side === "away";
  return (
    <div
      aria-label={[team.team.school, leader.name, leader.statLine]
        .filter(Boolean)
        .join(", ")}
      className={cn(
        "flex min-w-0 flex-1 items-start gap-2",
        !away && "flex-row-reverse"
      )}
    >
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
    </div>
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
