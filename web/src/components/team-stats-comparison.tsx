import type { TeamStats, GameTeam } from "@/lib/types";
import { TeamLogo } from "./team-logo";
import { cn } from "@/lib/utils";

interface TeamStatsComparisonProps {
  homeStats: TeamStats;
  awayStats: TeamStats;
  homeTeam: GameTeam;
  awayTeam: GameTeam;
}

function StatRow({
  label,
  homeValue,
  awayValue,
  isPercentage,
}: {
  label: string;
  homeValue: number | string;
  awayValue: number | string;
  isPercentage?: boolean;
}) {
  const homeNum =
    typeof homeValue === "number" ? homeValue : parseFloat(homeValue) || 0;
  const awayNum =
    typeof awayValue === "number" ? awayValue : parseFloat(awayValue) || 0;
  const total = homeNum + awayNum || 1;
  const homePct = (homeNum / total) * 100;
  const awayPct = (awayNum / total) * 100;

  return (
    <div className="py-2">
      <div className="mb-1 flex items-center justify-between text-sm">
        <span className="font-score">{String(awayValue)}</span>
        <span className="text-xs text-muted-foreground">{label}</span>
        <span className="font-score">{String(homeValue)}</span>
      </div>
      <div className="flex h-1.5 gap-0.5 overflow-hidden rounded-full">
        <div
          className={cn(
            "rounded-l-full transition-all",
            awayPct > homePct ? "bg-primary" : "bg-muted-foreground/30"
          )}
          style={{ width: `${awayPct}%` }}
        />
        <div
          className={cn(
            "rounded-r-full transition-all",
            homePct > awayPct ? "bg-primary" : "bg-muted-foreground/30"
          )}
          style={{ width: `${homePct}%` }}
        />
      </div>
    </div>
  );
}

export function TeamStatsComparison({
  homeStats,
  awayStats,
  homeTeam,
  awayTeam,
}: TeamStatsComparisonProps) {
  return (
    <div>
      {/* Team headers */}
      <div className="mb-4 flex items-center justify-between">
        <div className="flex items-center gap-2">
          <TeamLogo
            espnId={awayTeam.team.espnId}
            teamName={awayTeam.team.school}
            size="md"
          />
          <span className="text-sm font-semibold">
            {awayTeam.team.abbreviation}
          </span>
        </div>
        <div className="flex items-center gap-2">
          <span className="text-sm font-semibold">
            {homeTeam.team.abbreviation}
          </span>
          <TeamLogo
            espnId={homeTeam.team.espnId}
            teamName={homeTeam.team.school}
            size="md"
          />
        </div>
      </div>

      {/* Stats */}
      <div className="divide-y">
        <StatRow
          label="Total Yards"
          homeValue={homeStats.totalYards}
          awayValue={awayStats.totalYards}
        />
        <StatRow
          label="Passing Yards"
          homeValue={homeStats.passingYards}
          awayValue={awayStats.passingYards}
        />
        <StatRow
          label="Rushing Yards"
          homeValue={homeStats.rushingYards}
          awayValue={awayStats.rushingYards}
        />
        <StatRow
          label="First Downs"
          homeValue={homeStats.firstDowns}
          awayValue={awayStats.firstDowns}
        />
        <StatRow
          label="3rd Down"
          homeValue={homeStats.thirdDownEfficiency}
          awayValue={awayStats.thirdDownEfficiency}
        />
        <StatRow
          label="Turnovers"
          homeValue={homeStats.turnovers}
          awayValue={awayStats.turnovers}
        />
        <StatRow
          label="Penalties"
          homeValue={`${homeStats.penalties}-${homeStats.penaltyYards}`}
          awayValue={`${awayStats.penalties}-${awayStats.penaltyYards}`}
        />
        <StatRow
          label="Time of Possession"
          homeValue={homeStats.timeOfPossession}
          awayValue={awayStats.timeOfPossession}
        />
        <StatRow
          label="Red Zone"
          homeValue={homeStats.redZoneEfficiency}
          awayValue={awayStats.redZoneEfficiency}
        />
        <StatRow
          label="Sacks"
          homeValue={homeStats.sacks}
          awayValue={awayStats.sacks}
        />
      </div>
    </div>
  );
}
