"use client";

// The ConferencePage client shell — Standings leads (the iOS 2026-08-31
// order), Games carries the season's full slate one card per week with the
// postseason last. Season flips navigate `?year=` so the server refetch is
// the per-year cache.

import { useMemo, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { conferenceLogoUrl } from "@/lib/conferences";
import { cfbSeasonYear, seasonYears } from "@/lib/season";
import type { ConferenceStandingsGroup, Game } from "@/lib/types";
import { HeroHeader } from "@/components/hero-header";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import { SeasonMenuChip } from "@/components/season-menu-chip";
import { FollowPill } from "@/components/follow-pill";
import { CardHeader } from "@/components/card-header";
import { StandingsList } from "@/components/standings-list";
import { GameMatchupRow, gameRowLabel } from "@/components/next-game-card";
import { ConferenceLogo } from "@/components/theme/conference-logo";

// Ordered — Standings first and the entry default (FotMob's Leagues order).
const TABS: HeroTab[] = [
  { id: "standings", label: "Standings" },
  { id: "games", label: "Games" },
];

interface WeekGroup {
  id: string;
  title: string;
  games: Game[];
}

/**
 * The season slate's grouping — iOS `ConferenceSlate.groups`: regular-season
 * weeks ascending, then a dateless bucket, then the postseason — whose week
 * numbers restart at 1 and must never land a title game in "Week 1". Games
 * sort chronologically within a group.
 */
export function groupSeasonSlate(games: Game[]): WeekGroup[] {
  const time = (game: Game) => {
    const parsed = Date.parse(game.scheduledAt);
    return Number.isNaN(parsed) ? Number.POSITIVE_INFINITY : parsed;
  };
  const sorted = [...games].sort((a, b) => time(a) - time(b));

  const regular = new Map<number, Game[]>();
  const postseason: Game[] = [];
  const undated: Game[] = [];
  for (const game of sorted) {
    if (game.seasonType === 3) {
      postseason.push(game);
    } else if (game.week >= 1) {
      const bucket = regular.get(game.week);
      if (bucket) bucket.push(game);
      else regular.set(game.week, [game]);
    } else {
      undated.push(game);
    }
  }

  const groups: WeekGroup[] = [...regular.keys()]
    .sort((a, b) => a - b)
    .map((week) => ({
      id: `week-${week}`,
      title: `Week ${week}`,
      games: regular.get(week) ?? [],
    }));
  if (undated.length > 0) {
    groups.push({ id: "week-other", title: "More games", games: undated });
  }
  if (postseason.length > 0) {
    groups.push({ id: "week-postseason", title: "Postseason", games: postseason });
  }
  return groups;
}

interface ConferenceViewProps {
  conferenceId: number;
  name: string;
  /** This conference's standings group; null = the fetch failed. */
  standings: ConferenceStandingsGroup | null;
  /** The season's full conference slate; null = the fetch failed. */
  games: Game[] | null;
  displayYear: number;
  /** Anchor this team's row — standings pushes from other pages. */
  highlightTeamId?: string;
}

export function ConferenceView({
  conferenceId,
  name,
  standings,
  games,
  displayYear,
  highlightTeamId,
}: ConferenceViewProps) {
  const router = useRouter();
  const [tab, setTab] = useState("standings");

  const weekGroups = useMemo(() => groupSeasonSlate(games ?? []), [games]);
  const teamCount = standings?.entries.length ?? 0;
  const logoUrl = conferenceLogoUrl(conferenceId);

  const selectYear = (year: number) => {
    const query = year === cfbSeasonYear() ? "" : `?year=${year}`;
    router.push(`/conference/${conferenceId}${query}`);
  };

  const seasonRow = (
    <div className="flex justify-end">
      <SeasonMenuChip
        value={displayYear}
        years={seasonYears()}
        onSelect={selectYear}
      />
    </div>
  );

  const retryRow = (message: string) => (
    <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
      <p className="type-team-name text-text-secondary">{message}</p>
      <button
        type="button"
        onClick={() => router.refresh()}
        className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
      >
        Retry
      </button>
    </section>
  );

  return (
    <div>
      <HeroHeader
        logo={
          logoUrl ? (
            // The conference mark keeps the logo-backing disc — navy marks
            // (Big Ten, ACC) vanish on black, and ESPN serves no dark
            // conference variants. The disc is chrome, not color.
            <span className="inline-flex items-center justify-center rounded-full bg-logo-backing p-1.5">
              <Image
                src={logoUrl}
                alt=""
                width={44}
                height={44}
                className="h-11 w-11 object-contain"
                unoptimized
              />
            </span>
          ) : (
            <ConferenceLogo src={undefined} name="" />
          )
        }
        title={name}
        subtitle={
          teamCount > 0 ? (
            <span className="type-chip-em text-text-secondary">
              {teamCount} teams
            </span>
          ) : undefined
        }
        trailing={
          <FollowPill id={String(conferenceId)} kind="conference" name={name} />
        }
      >
        <HeroTabBar tabs={TABS} selected={tab} onSelect={setTab} />
      </HeroHeader>

      <div
        role="tabpanel"
        id={`panel-${tab}`}
        aria-labelledby={`tab-${tab}`}
        className="flex flex-col gap-2 py-2"
      >
        {tab === "standings" && (
          <>
            {seasonRow}
            {standings === null ? (
              retryRow("Couldn't load standings.")
            ) : (
              <section className="card-surface pb-1">
                <StandingsList
                  entries={standings.entries}
                  conferenceId={conferenceId}
                  year={displayYear}
                  highlightTeamId={highlightTeamId}
                />
              </section>
            )}
          </>
        )}

        {tab === "games" && (
          <>
            {seasonRow}
            {games === null ? (
              retryRow("Couldn't load the schedule.")
            ) : weekGroups.length === 0 ? (
              <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
                Schedule TBA
              </section>
            ) : (
              weekGroups.map((group) => (
                <section key={group.id} className="card-surface pb-1">
                  <CardHeader title={group.title} />
                  {group.games.map((game, index) => (
                    <div key={game.id}>
                      {index > 0 && (
                        <div className="ml-4 border-t border-divider" />
                      )}
                      <Link
                        href={`/game/${game.id}`}
                        aria-label={gameRowLabel(game)}
                        className="block transition-colors hover:bg-bg-header"
                        suppressHydrationWarning
                      >
                        <GameMatchupRow game={game} />
                      </Link>
                    </div>
                  ))}
                </section>
              ))
            )}
          </>
        )}
      </div>
    </div>
  );
}
