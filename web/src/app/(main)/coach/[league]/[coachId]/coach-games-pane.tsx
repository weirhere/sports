"use client";

// The Games tab — iOS `CoachGamesPane`: a season chip over the seasons the
// coach held the job, and that season's schedule for the team they coached.
//
// **The team's season, not strictly the coach's games.** ESPN keeps no
// per-coach game list, only the coach's season and the team's schedule. The
// two differ in a season with a mid-year change, where the schedule also
// holds the other coach's games; the card title carries the coach's own
// record for the season, which is what tells them apart.

import { useState } from "react";
import { CardHeader } from "@/components/card-header";
import { ScheduleRow } from "@/components/schedule-row";
import { SeasonMenuChip } from "@/components/season-menu-chip";
import { getTeamSeasonSchedule } from "@/lib/api";
import { recordSummary, type CoachCareer } from "@/lib/coach";
import { useOnDemand } from "@/lib/hooks/use-on-demand";
import { seasonLabel, type League } from "@/lib/leagues";

export function CoachGamesPane({ league, career }: { league: League; career: CoachCareer }) {
  const { seasons } = career.profile;
  const [year, setYear] = useState(seasons[0]?.year);
  const season = seasons.find((s) => s.year === year);
  const schedule = useOnDemand(
    season ? `${league}:${season.teamId}:${season.year}` : undefined,
    () => getTeamSeasonSchedule(league, season!.teamId, season!.year)
  );

  if (!season) {
    return (
      <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
        No games on record.
      </section>
    );
  }

  const years = [...new Set(seasons.map((s) => s.year))];
  const team = career.teams[season.teamId]?.name ?? seasonLabel(league, season.year);
  const title = season.record ? `${team} · ${recordSummary(season.record)}` : team;

  return (
    <>
      {years.length > 1 && (
        <div className="flex justify-end">
          <SeasonMenuChip value={season.year} years={years} onSelect={setYear} />
        </div>
      )}
      <section className="card-surface pb-1">
        <CardHeader title={title} />
        {schedule.state.status === "loading" ? (
          <p className="px-4 py-8 text-center type-team-name text-text-secondary">Loading…</p>
        ) : schedule.state.status === "failed" ? (
          <div className="flex flex-col items-center gap-3 px-4 py-8">
            <p className="type-team-name text-text-secondary">Couldn&apos;t load the schedule.</p>
            <button
              type="button"
              onClick={schedule.reload}
              className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
            >
              Retry
            </button>
          </div>
        ) : schedule.state.value.length === 0 ? (
          <p className="px-4 py-8 text-center type-team-name text-text-secondary">
            No games this season
          </p>
        ) : (
          schedule.state.value.map((game, index) => (
            <div key={game.id}>
              {index > 0 && <div className="ml-4 border-t border-divider" />}
              <ScheduleRow game={game} teamId={season.teamId} />
            </div>
          ))
        )}
      </section>
    </>
  );
}
