"use client";

// One head coach's page — iOS `CoachPage`, `CoachHero` and `CoachHeadshot`
// (Features/Coaches/, E27): a hero of photo-or-initials, name and team
// badge, over Profile · Career · Games. The role is a Profile row, the way a
// player's position is (Andy, 2026-09-28), so the hero says only who someone
// is and who they work for.
//
// ESPN has a coach photo for 11 of 32 NFL, 9 of 30 NBA, 5 of 32 NHL and no
// college head coaches (probed 2026-09-27), and only as a 65px JPEG. So the
// initials are the design and the photo is the upgrade.

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { HeroHeader } from "@/components/hero-header";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import { coachInitials, type CoachCareer } from "@/lib/coach";
import type { League } from "@/lib/leagues";
import { teamPath } from "@/lib/routes";
import { CoachCareerPane } from "./coach-career-pane";
import { CoachGamesPane } from "./coach-games-pane";
import { CoachProfilePane } from "./coach-profile-pane";

const TABS: HeroTab[] = [
  { id: "profile", label: "Profile" },
  { id: "career", label: "Career" },
  { id: "games", label: "Games" },
];

interface CoachViewProps {
  league: League;
  career: CoachCareer;
}

export function CoachView({ league, career }: CoachViewProps) {
  const [activeTab, setTab] = useState("profile");
  // Latched on the tap that opens the tab: most visits never do, and the
  // schedule is a request of its own.
  const [gamesRequested, setGamesRequested] = useState(false);
  const selectTab = (id: string) => {
    setTab(id);
    if (id === "games") setGamesRequested(true);
  };

  const { profile, teams } = career;
  const teamId = profile.currentTeamId;
  const team = teamId ? teams[teamId] : undefined;

  return (
    <div>
      <span className="sr-only">
        {[profile.name, team?.name].filter(Boolean).join(", ")}
      </span>
      <HeroHeader
        logo={<Headshot name={profile.name} url={profile.headshotUrl} />}
        title={profile.name}
        subtitle={
          teamId && team ? (
            <div className="flex min-w-0">
              <Link
                href={teamPath({ league, id: teamId })}
                className="flex min-w-0 shrink items-center gap-1.5 rounded-full bg-bg-elevated py-1 pl-1 pr-2.5 type-chip-em text-text-secondary transition-colors hover:text-text-primary focus-visible:outline-none focus-visible:ring-1 focus-visible:ring-text-secondary"
              >
                {team.logoUrl && (
                  <Image
                    src={team.logoUrl}
                    alt=""
                    width={16}
                    height={16}
                    unoptimized
                    className="h-4 w-4 shrink-0 object-contain"
                  />
                )}
                <span className="truncate">{team.name}</span>
                <span className="sr-only">, view team page</span>
              </Link>
            </div>
          ) : undefined
        }
        tabs={<HeroTabBar tabs={TABS} selected={activeTab} onSelect={selectTab} />}
      />

      <div
        role="tabpanel"
        id={`panel-${activeTab}`}
        aria-labelledby={`tab-${activeTab}`}
        className="flex flex-col gap-2 py-2"
      >
        {activeTab === "profile" && <CoachProfilePane league={league} profile={profile} />}
        {activeTab === "career" && <CoachCareerPane league={league} career={career} />}
        {/* Mounted once opened and then kept, so flipping back doesn't
            refetch or lose the picked season. */}
        {gamesRequested && (
          <div hidden={activeTab !== "games"} className="flex flex-col gap-2">
            <CoachGamesPane league={league} career={career} />
          </div>
        )}
      </div>
    </div>
  );
}

function Headshot({ name, url }: { name: string; url?: string }) {
  const [failed, setFailed] = useState(false);
  return (
    <span
      aria-hidden="true"
      className="flex h-14 w-14 shrink-0 items-center justify-center overflow-hidden rounded-full bg-bg-elevated"
    >
      {url && !failed ? (
        <Image
          src={url}
          alt=""
          width={56}
          height={56}
          unoptimized
          onError={() => setFailed(true)}
          className="h-full w-full object-cover"
        />
      ) : (
        <span className="text-lg font-semibold text-text-secondary">{coachInitials(name)}</span>
      )}
    </span>
  );
}
