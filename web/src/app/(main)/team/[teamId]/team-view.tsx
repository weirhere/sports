"use client";

// The TeamPage client shell — tab choice is the only client state; season
// flips navigate `?year=` so the server refetch is the per-year cache.

import { useMemo, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import { ChevronRight } from "lucide-react";
import { conferenceName } from "@/lib/conferences";
import { cfbSeasonYear, seasonYears } from "@/lib/season";
import { gameState } from "@/lib/game-state";
import type {
  ConferenceStandingsGroup,
  TeamScheduleData,
} from "@/lib/types";
import { HeroHeader } from "@/components/hero-header";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import { SeasonMenuChip } from "@/components/season-menu-chip";
import { FollowPill } from "@/components/follow-pill";
import { CardHeader } from "@/components/card-header";
import { ScheduleRow } from "@/components/schedule-row";
import { NextGameCard } from "@/components/next-game-card";
import {
  TeamRecordCard,
  teamRecordCardHasContent,
} from "@/components/team-record-card";
import { StandingsList } from "@/components/standings-list";

// Ordered — the ordinal is the tab walk (Overview → Games → Standings).
const TABS: HeroTab[] = [
  { id: "overview", label: "Overview" },
  { id: "games", label: "Games" },
  { id: "standings", label: "Standings" },
];

interface TeamViewProps {
  teamId: string;
  schedule: TeamScheduleData;
  /** All conferences' standings for the requested season; null = fetch failed. */
  standingsGroups: ConferenceStandingsGroup[] | null;
  /** Current AP top-25 rank, when the team holds one. */
  apRank?: number;
  /** The season the payload actually describes — the chip label. */
  displayYear: number;
  /** Whether the requested season is the current one. */
  isCurrentSeason: boolean;
}

export function TeamView({
  teamId,
  schedule,
  standingsGroups,
  apRank,
  displayYear,
  isCurrentSeason,
}: TeamViewProps) {
  const router = useRouter();
  const [tab, setTab] = useState("overview");

  // The schedule payload's conference wins (season-scoped, so a realignment
  // year reads correctly); the standings groups cover entry paths where the
  // payload carries none.
  const conferenceId = useMemo(() => {
    const claimed = schedule.team?.conferenceId;
    if (claimed && claimed !== "0" && conferenceName(Number(claimed)) !== "Other") {
      return Number(claimed);
    }
    const containing = standingsGroups?.find((group) =>
      group.entries.some((entry) => entry.team.id === teamId)
    );
    const id = containing ? Number(containing.id) : Number.NaN;
    return Number.isFinite(id) && conferenceName(id) !== "Other" ? id : undefined;
  }, [schedule.team?.conferenceId, standingsGroups, teamId]);

  const showsStandingsTab = conferenceId !== undefined;
  const visibleTabs = showsStandingsTab ? TABS : TABS.slice(0, 2);
  const activeTab = tab === "standings" && !showsStandingsTab ? "overview" : tab;

  const school =
    schedule.team?.school ??
    // Derive an identity from the slate when the payload ships no team block.
    schedule.games
      .flatMap((game) => [game.homeTeam, game.awayTeam])
      .find((side) => side.team.id === teamId)?.team.school ??
    "Team";
  const logoUrl = schedule.team?.logoUrl;

  // The lead card is pinned to the current season — a past season is
  // history, and its "next game" would be a lie. Soonest upcoming or live
  // game, else the most recent one.
  const leadGame = isCurrentSeason
    ? (schedule.games.find(
        (game) => gameState(game.status) !== "final"
      ) ?? schedule.games[schedule.games.length - 1])
    : undefined;

  // Conference W-L is only knowable from the standings payload, which for
  // the current season describes ESPN's live table; past seasons show the
  // derived record only (tiebreakers make conference records non-derivable).
  const ownStanding =
    conferenceId !== undefined
      ? standingsGroups
          ?.find((group) => group.id === String(conferenceId))
          ?.entries.find((entry) => entry.team.id === teamId)
      : undefined;
  const overviewConferenceRecord = isCurrentSeason
    ? ownStanding?.conferenceRecord
    : undefined;
  const overviewOverallRecord = isCurrentSeason
    ? (ownStanding?.overallRecord ?? schedule.record ?? schedule.derivedRecord)
    : schedule.derivedRecord;

  const standingsEntries =
    conferenceId !== undefined
      ? (standingsGroups?.find((group) => group.id === String(conferenceId))
          ?.entries ?? [])
      : [];

  const selectYear = (year: number) => {
    const query = year === cfbSeasonYear() ? "" : `?year=${year}`;
    router.push(`/team/${teamId}${query}`);
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
            <Image
              src={logoUrl}
              alt=""
              width={56}
              height={56}
              className="h-14 w-14 object-contain"
              unoptimized
            />
          ) : null
        }
        title={school}
        rank={apRank}
        subtitle={
          conferenceId !== undefined ? (
            <Link
              href={`/conference/${conferenceId}?team=${teamId}`}
              className="inline-flex items-center gap-1 type-chip-em text-text-secondary transition-colors hover:text-text-primary"
            >
              {conferenceName(conferenceId)}
              <ChevronRight aria-hidden="true" className="h-3 w-3" />
              <span className="sr-only">, view conference standings</span>
            </Link>
          ) : undefined
        }
        trailing={<FollowPill id={teamId} kind="team" name={school} />}
      >
        <HeroTabBar tabs={visibleTabs} selected={activeTab} onSelect={setTab} />
      </HeroHeader>

      <div
        role="tabpanel"
        id={`panel-${activeTab}`}
        aria-labelledby={`tab-${activeTab}`}
        className="flex flex-col gap-2 py-2"
      >
        {activeTab === "overview" && (
          <>
            {leadGame && <NextGameCard game={leadGame} />}
            {teamRecordCardHasContent(
              overviewConferenceRecord,
              overviewOverallRecord
            ) ? (
              <TeamRecordCard
                conferenceRecord={overviewConferenceRecord}
                overallRecord={overviewOverallRecord}
              />
            ) : (
              !leadGame && (
                <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
                  Season TBA
                </section>
              )
            )}
          </>
        )}

        {activeTab === "games" && (
          <>
            {seasonRow}
            <section className="card-surface pb-1">
              <CardHeader title="Schedule" />
              {schedule.games.length > 0 ? (
                schedule.games.map((game, index) => (
                  <div key={game.id}>
                    {index > 0 && <div className="ml-4 border-t border-divider" />}
                    <ScheduleRow game={game} teamId={teamId} />
                  </div>
                ))
              ) : (
                <p className="px-4 py-8 text-center type-team-name text-text-secondary">
                  Season TBA
                </p>
              )}
            </section>
          </>
        )}

        {activeTab === "standings" && conferenceId !== undefined && (
          <>
            {seasonRow}
            {standingsGroups === null ? (
              retryRow("Couldn't load standings.")
            ) : (
              <section className="card-surface pb-1">
                <StandingsList
                  entries={standingsEntries}
                  conferenceId={conferenceId}
                  year={displayYear}
                  highlightTeamId={teamId}
                />
              </section>
            )}
          </>
        )}
      </div>
    </div>
  );
}
