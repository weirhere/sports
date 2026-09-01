"use client";

import { useState, useEffect, useMemo, useCallback, useRef } from "react";
import { createPortal } from "react-dom";
import type { Game, DayGames, ConferenceGameGroup, Conference } from "@/lib/types";
import { WeekSelector } from "@/components/week-selector";
import { DayGroup } from "@/components/day-group";
import { ConferenceGroupSkeleton } from "@/components/game-card-skeleton";
import { EmptyState } from "@/components/empty-state";
import { Separator } from "@/components/ui/separator";
import { getSchedule } from "@/lib/api";
import { ALL_CONFERENCES } from "@/config/conferences";
import { MyTeamsSection } from "@/components/my-teams-section";
import { OnboardingModal } from "@/components/onboarding-modal";
import { useLiveScores } from "@/lib/hooks/use-live-scores";
import { useSwipe } from "@/lib/hooks/use-swipe";
import { SeasonSelector } from "@/components/season-selector";
import { CURRENT_SEASON_YEAR, SEASONS, WEEKS } from "@/lib/constants";

interface ScoresViewProps {
  initialGames: Game[];
  initialWeek: number;
  initialYear?: number;
}

function groupGamesByDay(games: Game[]): DayGames[] {
  const dayMap = new Map<string, Game[]>();

  for (const game of games) {
    const date = new Date(game.scheduledAt);
    const dateKey = date.toISOString().split("T")[0];
    if (!dayMap.has(dateKey)) dayMap.set(dateKey, []);
    dayMap.get(dateKey)!.push(game);
  }

  const days: DayGames[] = [];
  const sortedDates = [...dayMap.keys()].sort();

  for (const dateKey of sortedDates) {
    const dayGames = dayMap.get(dateKey)!;
    const date = new Date(dateKey + "T12:00:00Z");
    const label = date.toLocaleDateString("en-US", {
      weekday: "long",
      month: "long",
      day: "numeric",
    });

    // Group by conference within this day
    const confMap = new Map<string, Game[]>();
    for (const game of dayGames) {
      // Use home team's conference as the grouping key
      const confId = game.homeTeam.team.conferenceId;
      if (!confMap.has(confId)) confMap.set(confId, []);
      confMap.get(confId)!.push(game);
    }

    const conferenceGroups: ConferenceGameGroup[] = [];
    for (const [confId, confGames] of confMap) {
      const conference = ALL_CONFERENCES.find((c) => c.id === confId) || {
        id: confId,
        name: confGames[0]?.homeTeam.team.conferenceName || "Unknown",
        shortName: confGames[0]?.homeTeam.team.conferenceName || "Unknown",
        division: confGames[0]?.homeTeam.team.division || "FBS" as const,
      };
      conferenceGroups.push({ conference: conference as Conference, games: confGames });
    }

    // Sort: Power 4 conferences first, then Group of 5, then others
    conferenceGroups.sort((a, b) => {
      const power4 = ["8", "5", "1", "4"]; // SEC, Big Ten, ACC, Big 12
      const aIsPower4 = power4.includes(a.conference.id);
      const bIsPower4 = power4.includes(b.conference.id);
      if (aIsPower4 && !bIsPower4) return -1;
      if (!aIsPower4 && bIsPower4) return 1;
      return a.conference.name.localeCompare(b.conference.name);
    });

    days.push({ date: dateKey, label, conferenceGroups });
  }

  return days;
}

export function ScoresView({ initialGames, initialWeek, initialYear = CURRENT_SEASON_YEAR }: ScoresViewProps) {
  const [selectedWeek, setSelectedWeek] = useState(initialWeek);
  const [selectedYear, setSelectedYear] = useState(initialYear);
  const [games, setGames] = useState(initialGames);
  const [loading, setLoading] = useState(false);

  // Live score polling
  const handleLiveUpdate = useCallback((updatedGames: Game[]) => {
    setGames(updatedGames);
  }, []);

  useLiveScores(selectedWeek, selectedYear, games, handleLiveUpdate);

  const handleWeekChange = useCallback(async (week: number) => {
    setSelectedWeek(week);
    setLoading(true);
    try {
      const data = await getSchedule(week, selectedYear);
      setGames(data.games);
    } catch {
      // Keep existing games on error
    } finally {
      setLoading(false);
    }
  }, [selectedYear]);

  const handleYearChange = useCallback(async (year: number) => {
    setSelectedYear(year);
    setSelectedWeek(1);
    setLoading(true);
    try {
      const data = await getSchedule(1, year);
      setGames(data.games);
    } catch {
      // Keep existing games on error
    } finally {
      setLoading(false);
    }
  }, []);

  // Separate FBS and FCS
  const fbsGames = useMemo(
    () => games.filter((g) => g.homeTeam.team.division === "FBS"),
    [games]
  );
  const fcsGames = useMemo(
    () => games.filter((g) => g.homeTeam.team.division === "FCS"),
    [games]
  );

  const fbsDays = useMemo(() => groupGamesByDay(fbsGames), [fbsGames]);
  const fcsDays = useMemo(() => groupGamesByDay(fcsGames), [fcsGames]);

  // Swipe left/right to change weeks
  const maxWeek = WEEKS[WEEKS.length - 1].number;
  const { ref: swipeRef } = useSwipe({
    onSwipeLeft: () => {
      if (selectedWeek < maxWeek) handleWeekChange(selectedWeek + 1);
    },
    onSwipeRight: () => {
      if (selectedWeek > 0) handleWeekChange(selectedWeek - 1);
    },
    enabled: !loading,
  });

  // Portal the season selector into the navbar right slot
  const [portalTarget, setPortalTarget] = useState<HTMLElement | null>(null);
  useEffect(() => {
    setPortalTarget(document.getElementById("navbar-right-slot"));
    return () => setPortalTarget(null);
  }, []);

  return (
    <div>
      {portalTarget &&
        createPortal(
          <SeasonSelector
            selectedYear={selectedYear}
            onYearChange={handleYearChange}
            seasons={SEASONS}
          />,
          portalTarget
        )}

      <WeekSelector
        selectedWeek={selectedWeek}
        onWeekChange={handleWeekChange}
        currentWeek={initialWeek}
      />

      <OnboardingModal />

      <div ref={swipeRef} className="mt-8 space-y-6">
        {loading ? (
          <div className="space-y-3">
            {Array.from({ length: 4 }).map((_, i) => (
              <ConferenceGroupSkeleton key={i} rows={i === 0 ? 4 : 3} />
            ))}
          </div>
        ) : games.length === 0 ? (
          <EmptyState
            title="No games this week"
            description="Check back later or select a different week."
          />
        ) : (
          <>
            {/* My Teams */}
            <MyTeamsSection games={games} />

            {/* FBS Games */}
            {fbsDays.map((day) => (
              <DayGroup key={day.date} dayGames={day} />
            ))}

            {/* FCS Separator */}
            {fcsDays.length > 0 && (
              <>
                <Separator className="my-6" />
                <h2 className="text-lg font-semibold text-muted-foreground">
                  FCS Games
                </h2>
                {fcsDays.map((day) => (
                  <DayGroup
                    key={day.date}
                    dayGames={day}
                    defaultOpen={false}
                  />
                ))}
              </>
            )}
          </>
        )}
      </div>
    </div>
  );
}
