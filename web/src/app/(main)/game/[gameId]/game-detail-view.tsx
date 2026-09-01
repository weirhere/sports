"use client";

// The game page (iOS GameDetailScreen): header on the card surface, then
// the cards in exactly the iOS order — pre-game info, line score, scoring,
// team stats, leaders, matchup standings, drives, venue info. Live games
// poll every 30s through useLiveGame; a pre-game summary never demotes a
// live snapshot (the merge lives in the hook).

import type { ConferenceStandingsGroup, GameDetail } from "@/lib/types";
import { useLiveGame } from "@/lib/hooks/use-live-game";
import { cfbSeasonYear } from "@/lib/season";
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
  const isCurrentSeason =
    game.scheduledAt !== "" &&
    cfbSeasonYear(new Date(game.scheduledAt)) === cfbSeasonYear();
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
    <div className="mx-auto flex w-full max-w-2xl flex-col gap-2">
      <GameHeader game={game} />
      {/* Pre-kick the sections below are all empty — the info card carries
          the "what do I need to know" load. */}
      {!scores && <GameInfoCard game={game} detail={data} mode="pre" />}
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
      {standingsVisible && (
        <MatchupStandingsCard
          away={game.awayTeam.team}
          home={game.homeTeam.team}
          standings={standings}
        />
      )}
      {drives.length > 0 && <DrivesCard drives={drives} game={game} />}
      {/* Pre-game the info card already places the game; once scores exist
          it returns as the venue card. */}
      {venueVisible && <GameInfoCard game={game} detail={data} mode="venue" />}
    </div>
  );
}
