"use client";

// The game page (iOS GameDetailScreen): header on the card surface, then
// the cards in the iOS order — line score, scoring, team stats, leaders,
// drives. Live games poll every 30s through useLiveGame; a pre-game
// summary never demotes a live snapshot (the merge lives in the hook).
//
// Desktop splits that into two columns: the game itself on the left, and
// the context that surrounds it — where it's played, who showed up, what
// it does to the tables — in a rail on the right. The iPhone's single
// column keeps the same reading order, so the rail's cards land after the
// drives rather than between them; on a phone that's still "the game,
// then the context".

import type { ConferenceStandingsGroup, GameDetail } from "@/lib/types";
import { useLiveGame } from "@/lib/hooks/use-live-game";
import { seasonYear } from "@/lib/leagues";
import { showsScores } from "./game-status";
import { GameHeader } from "./game-header";
import { GameInfoCard } from "./game-info-card";
import { LineScoreCard } from "./line-score-card";
import { ScoringPlaysCard } from "./scoring-plays-card";
import { TeamStatsCard, hasTeamStats } from "./team-stats-card";
import { LeadersCard } from "./leaders-card";
import {
  MatchupStandingsCard,
  matchupStandingsHasContent,
} from "./matchup-standings-card";
import { DrivesCard } from "./drives-card";

interface GameDetailViewProps {
  initialData: GameDetail;
  /** Current-season conference standings; null when the fetch missed —
   * a miss just hides the matchup card. */
  standings: ConferenceStandingsGroup[] | null;
}

export function GameDetailView({
  initialData,
  standings,
}: GameDetailViewProps) {
  const data = useLiveGame(initialData.game.id, initialData);
  const { game } = data;
  const scores = showsScores(game);

  const hasLinescores =
    (game.awayTeam.linescores?.length ?? 0) > 0 ||
    (game.homeTeam.linescores?.length ?? 0) > 0;
  const scoringPlays = data.scoringPlays ?? [];
  const leaders = data.leaders ?? [];
  const drives = data.drives ?? [];

  // Past-season games (reached by direct link) must not wear the current
  // season's standings — the fetch is always the current tables.
  // Read on **this game's league's** clock: a college-football rollover
  // would call June "next season" while the Stanley Cup was still being
  // played for, and February the same for the NFL.
  const isCurrentSeason =
    game.scheduledAt !== "" &&
    seasonYear(game.league, new Date(game.scheduledAt)) ===
      seasonYear(game.league);
  const standingsVisible =
    standings !== null &&
    isCurrentSeason &&
    matchupStandingsHasContent(
      game.awayTeam.team,
      game.homeTeam.team,
      standings
    );

  const venueVisible =
    scores && (Boolean(game.venue.name) || data.attendance !== undefined);

  return (
    <div className="grid w-full gap-2 lg:grid-cols-[minmax(0,1fr)_320px] lg:items-start lg:gap-4">
      <div className="flex min-w-0 flex-col gap-2">
        <GameHeader game={game} />
        {hasLinescores && <LineScoreCard game={game} />}
        {scoringPlays.length > 0 && <ScoringPlaysCard plays={scoringPlays} />}
        {scores && hasTeamStats(data.awayStats, data.homeStats) && (
          <TeamStatsCard
            awayTeam={game.awayTeam}
            homeTeam={game.homeTeam}
            awayStats={data.awayStats}
            homeStats={data.homeStats}
          />
        )}
        {leaders.length > 0 && (
          <LeadersCard
            leaders={leaders}
            awayTeam={game.awayTeam}
            homeTeam={game.homeTeam}
          />
        )}
        {drives.length > 0 && <DrivesCard drives={drives} game={game} />}
      </div>

      <div className="flex min-w-0 flex-col gap-2">
        {/* Pre-kick every section on the left is empty, so this card
            carries the whole "what do I need to know" load; once scores
            exist it returns as the venue card. */}
        {!scores && <GameInfoCard game={game} detail={data} mode="pre" />}
        {venueVisible && (
          <GameInfoCard game={game} detail={data} mode="venue" />
        )}
        {standingsVisible && (
          <MatchupStandingsCard
            away={game.awayTeam.team}
            home={game.homeTeam.team}
            standings={standings}
          />
        )}
      </div>
    </div>
  );
}
