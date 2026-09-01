// Away vs home stats as opposing monochrome bars growing out from the
// center (iOS TeamStatsCompare) — length carries the comparison, not
// color. The card header carries the "UGA · USC" column legend.

import type { GameTeam, TeamStats } from "@/lib/types";
import { DetailCard } from "./detail-card";

interface TeamStatsCardProps {
  awayTeam: GameTeam;
  homeTeam: GameTeam;
  awayStats: TeamStats;
  homeStats: TeamStats;
}

interface StatRow {
  key: string;
  label: string;
  away: string;
  home: string;
  /** Numeric magnitudes for the bar; omitted → no bar for that row. */
  awayValue?: number;
  homeValue?: number;
}

/** "32:15" → seconds; undefined for anything unparseable. */
function possessionSeconds(value: string): number | undefined {
  const match = /^(\d+):(\d{2})$/.exec(value.trim());
  if (!match) return undefined;
  return Number(match[1]) * 60 + Number(match[2]);
}

/** "5-12" → conversion rate; undefined when attempts are unknown/zero. */
function conversionRate(value: string): number | undefined {
  const match = /^(\d+)-(\d+)$/.exec(value.trim());
  if (!match) return undefined;
  const attempts = Number(match[2]);
  if (attempts === 0) return undefined;
  return Number(match[1]) / attempts;
}

function buildRows(away: TeamStats, home: TeamStats): StatRow[] {
  return [
    {
      key: "totalYards",
      label: "Total yards",
      away: `${away.totalYards}`,
      home: `${home.totalYards}`,
      awayValue: away.totalYards,
      homeValue: home.totalYards,
    },
    {
      key: "passingYards",
      label: "Passing",
      away: `${away.passingYards}`,
      home: `${home.passingYards}`,
      awayValue: away.passingYards,
      homeValue: home.passingYards,
    },
    {
      key: "rushingYards",
      label: "Rushing",
      away: `${away.rushingYards}`,
      home: `${home.rushingYards}`,
      awayValue: away.rushingYards,
      homeValue: home.rushingYards,
    },
    {
      key: "firstDowns",
      label: "First downs",
      away: `${away.firstDowns}`,
      home: `${home.firstDowns}`,
      awayValue: away.firstDowns,
      homeValue: home.firstDowns,
    },
    {
      key: "thirdDown",
      label: "3rd down",
      away: away.thirdDownEfficiency,
      home: home.thirdDownEfficiency,
      awayValue: conversionRate(away.thirdDownEfficiency),
      homeValue: conversionRate(home.thirdDownEfficiency),
    },
    {
      key: "turnovers",
      label: "Turnovers",
      away: `${away.turnovers}`,
      home: `${home.turnovers}`,
      awayValue: away.turnovers,
      homeValue: home.turnovers,
    },
    {
      key: "possession",
      label: "Possession",
      away: away.timeOfPossession,
      home: home.timeOfPossession,
      awayValue: possessionSeconds(away.timeOfPossession),
      homeValue: possessionSeconds(home.timeOfPossession),
    },
  ];
}

/** Whether the payload carried anything worth a card — pre-game box scores
 * arrive as all-zero shells. */
export function hasTeamStats(away: TeamStats, home: TeamStats): boolean {
  return [away, home].some(
    (s) =>
      s.totalYards > 0 ||
      s.passingYards > 0 ||
      s.rushingYards > 0 ||
      s.firstDowns > 0
  );
}

export function TeamStatsCard({
  awayTeam,
  homeTeam,
  awayStats,
  homeStats,
}: TeamStatsCardProps) {
  const rows = buildRows(awayStats, homeStats);
  const legend = `${awayTeam.team.abbreviation || "AWAY"} · ${
    homeTeam.team.abbreviation || "HOME"
  }`;

  return (
    <DetailCard title="Team stats" subtitle={legend}>
      <ul className="pb-2">
        {rows.map((row) => (
          <li
            key={row.key}
            className="flex flex-col gap-1 px-4 py-[5px]"
            aria-label={`${row.label}: ${awayTeam.team.school} ${row.away}, ${homeTeam.team.school} ${row.home}`}
          >
            <div aria-hidden="true" className="flex items-baseline">
              <span className="min-w-16 whitespace-nowrap text-left type-meta tnum text-text-primary">
                {row.away}
              </span>
              <span className="flex-1 text-center type-meta text-text-secondary">
                {row.label}
              </span>
              <span className="min-w-16 whitespace-nowrap text-right type-meta tnum text-text-primary">
                {row.home}
              </span>
            </div>
            <CenterOutBars away={row.awayValue} home={row.homeValue} />
          </li>
        ))}
      </ul>
    </DetailCard>
  );
}

/**
 * The opposing bars: each half is a bg-elevated track whose text-primary
 * fill grows from the center, sized by that side's share of the total.
 */
function CenterOutBars({ away, home }: { away?: number; home?: number }) {
  if (away === undefined || home === undefined || away + home <= 0) {
    return null;
  }
  const awayShare = away / (away + home);
  const homeShare = home / (away + home);

  return (
    <div aria-hidden="true" className="flex h-[3px] gap-[2px]">
      <div className="flex flex-1 justify-end overflow-hidden rounded-full bg-bg-elevated">
        <div
          className="h-full rounded-full bg-text-primary"
          style={{ width: `${Math.max(awayShare * 100, 2)}%` }}
        />
      </div>
      <div className="flex flex-1 overflow-hidden rounded-full bg-bg-elevated">
        <div
          className="h-full rounded-full bg-text-primary"
          style={{ width: `${Math.max(homeShare * 100, 2)}%` }}
        />
      </div>
    </div>
  );
}
