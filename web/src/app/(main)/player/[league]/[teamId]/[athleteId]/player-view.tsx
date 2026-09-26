"use client";

// One player's page — iOS `PlayerPage` (Features/Players/): Profile, Games,
// Stats and Career.
//
// **The tab row appears when there is a second tab to fill** — the rule this
// page shipped under (2026-09-20), when it was Profile alone because ESPN's
// athlete endpoints were unprobed. They answer from `site.web.api` now, so a
// player with a stats line gets all four tabs; a player ESPN has no numbers
// for — a walk-on, a practice-squad name — still gets Profile alone, with no
// row of dead tabs over it. `HeroHeader` handed no `tabs` renders exactly
// that.
//
// The hero is a name and a club (2026-09-21). The number and the position
// are Profile rows, and printing them in the hero as well put the same two
// facts on screen twice within a hundred pixels.

import { useState } from "react";
import Image from "next/image";
import Link from "next/link";
import { HeroHeader } from "@/components/hero-header";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import { SeasonMenuChip } from "@/components/season-menu-chip";
import { getPlayerGameLog } from "@/lib/api";
import { useOnDemand } from "@/lib/hooks/use-on-demand";
import {
  espnSeason,
  seasonYearFromEspn,
  type League,
} from "@/lib/leagues";
import { teamPath } from "@/lib/routes";
import { playerProfileRows, playerSpokenSummary } from "@/lib/player-profile";
import {
  seasonHeadlines,
  seasonLabelFor,
  type PlayerStats,
} from "@/lib/player-stats";
import type { RosterPlayer } from "@/lib/types";
import { LabeledValueCard } from "./labeled-value-card";
import { PlayerCareerPane } from "./player-career-pane";
import { PlayerGamesPane } from "./player-games-pane";
import { PlayerStatsPane } from "./player-stats-pane";
import { ThisSeasonCard } from "./this-season-card";

const TABS: HeroTab[] = [
  { id: "profile", label: "Profile" },
  { id: "games", label: "Games" },
  { id: "stats", label: "Stats" },
  { id: "career", label: "Career" },
];

interface PlayerViewProps {
  league: League;
  athleteId: string;
  player: RosterPlayer;
  /** The club he plays for now, off the athlete payload. */
  team?: { id: string; name?: string; logoUrl?: string };
  stats: PlayerStats;
  /** ESPN's season year "now" belongs to, for the This season card. */
  currentEspnSeason: number;
}

export function PlayerView({
  league,
  athleteId,
  player,
  team,
  stats,
  currentEspnSeason,
}: PlayerViewProps) {
  const [tab, setTab] = useState("profile");
  const hasTabs = stats.categories.length > 0;
  const activeTab = hasTabs ? tab : "profile";

  // The game log waits for the Games tab — most visits never open it — and
  // is then keyed by season, ESPN's numbering; undefined asks for ESPN's
  // current one. Latched on the tap that opens the tab.
  const [gamesRequested, setGamesRequested] = useState(false);
  const [logSeason, setLogSeason] = useState<number | undefined>();
  const selectTab = (id: string) => {
    setTab(id);
    if (id === "games") setGamesRequested(true);
  };
  const log = useOnDemand(
    gamesRequested ? `${league}:${athleteId}:${logSeason ?? "current"}` : undefined,
    () => getPlayerGameLog(league, athleteId, logSeason)
  );

  const headlines = seasonHeadlines(stats, currentEspnSeason);
  const seasonLabel = seasonLabelFor(stats, currentEspnSeason);
  const profileRows = playerProfileRows(player, league);

  // The season menu, from ESPN's own list of seasons it will answer for.
  // `SeasonMenuChip` speaks the app's season years and ESPN's log speaks
  // its own (the ending year, for the NBA and NHL), so it converts both
  // ways at this edge. One season is no choice, so no chip.
  const loadedLog = log.state.status === "loaded" ? log.state.value : undefined;
  const seasonChip =
    activeTab === "games" &&
    loadedLog?.season !== undefined &&
    loadedLog.availableSeasons.length > 1 ? (
      <SeasonMenuChip
        value={seasonYearFromEspn(league, loadedLog.season)}
        years={loadedLog.availableSeasons.map((year) =>
          seasonYearFromEspn(league, year)
        )}
        onSelect={(year) => setLogSeason(espnSeason(league, year))}
      />
    ) : undefined;

  return (
    <div>
      {/* The hero speaks one sentence — name and club, exactly what it
          draws. The badge below is a link and speaks for itself. */}
      <span className="sr-only">{playerSpokenSummary(player, team?.name)}</span>
      <HeroHeader
        logo={<Headshot player={player} />}
        title={player.name}
        subtitle={team?.name ? <TeamBadge league={league} team={team} /> : undefined}
        trailing={seasonChip}
        tabs={
          hasTabs ? (
            <HeroTabBar tabs={TABS} selected={activeTab} onSelect={selectTab} />
          ) : undefined
        }
      />

      <div
        {...(hasTabs
          ? {
              role: "tabpanel",
              id: `panel-${activeTab}`,
              "aria-labelledby": `tab-${activeTab}`,
            }
          : {})}
        className={hasTabs ? "flex flex-col gap-2 py-2" : "mt-4 flex flex-col gap-2"}
      >
        {activeTab === "profile" && (
          <>
            {headlines.length > 0 && seasonLabel && (
              <ThisSeasonCard seasonLabel={seasonLabel} headlines={headlines} />
            )}
            {profileRows.length > 0 && (
              <LabeledValueCard title="Profile" rows={profileRows} />
            )}
          </>
        )}
        {activeTab === "games" && (
          <PlayerGamesPane
            league={league}
            log={log.state}
            category={stats.categories[0]?.id}
            onRetry={log.reload}
          />
        )}
        {activeTab === "stats" && <PlayerStatsPane stats={stats} />}
        {activeTab === "career" && <PlayerCareerPane stats={stats} />}
      </div>
    </div>
  );
}

/**
 * The team as a badge on the elevated ground, crest and name together — the
 * one part of the hero that goes somewhere, so the one part that looks like
 * it does.
 *
 * Named off the fetched team (2026-09-21), never off the link that opened
 * the page, so every door shows the same club spelled the same way.
 */
function TeamBadge({
  league,
  team,
}: {
  league: League;
  team: { id: string; name?: string; logoUrl?: string };
}) {
  return (
    <div className="flex min-w-0">
      <Link
        href={teamPath({ league, id: team.id })}
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
  );
}

/**
 * The full press photo, which is the one place in the app it is the right
 * asset: a roster shows a hundred of these discs and asks the CDN combiner
 * for thumbnails, a page shows one.
 */
function Headshot({ player }: { player: RosterPlayer }) {
  const [failed, setFailed] = useState(false);

  return (
    <span
      aria-hidden="true"
      className="flex h-14 w-14 shrink-0 overflow-hidden rounded-full bg-bg-elevated"
    >
      {player.headshotUrl && !failed && (
        <Image
          src={player.headshotUrl}
          alt=""
          width={56}
          height={56}
          unoptimized
          onError={() => setFailed(true)}
          className="h-full w-full object-cover"
        />
      )}
    </span>
  );
}
