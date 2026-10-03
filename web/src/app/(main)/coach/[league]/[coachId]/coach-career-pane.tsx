// The Career tab — iOS `CoachCareerPane` and `CoachStintRow`: every job as a
// row (team, years, record) linking to the team page, then the season-by-
// season table with the career line closing it. "Where they coached
// before" is the first card; the second is the numbers behind it.

import { Fragment } from "react";
import Image from "next/image";
import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { CardHeader } from "@/components/card-header";
import {
  coachStints,
  recordSummary,
  seasonId,
  stintRecord,
  stintSpan,
  winPercentText,
  type CoachCareer,
  type CoachRecord,
} from "@/lib/coach";
import { seasonLabel, shortName, type League } from "@/lib/leagues";
import { teamPath } from "@/lib/routes";

const SPOKEN: Record<string, string> = {
  W: "Wins",
  L: "Losses",
  T: "Ties",
  OTL: "Overtime losses",
  PCT: "Win percentage",
};

export function CoachCareerPane({ league, career }: { league: League; career: CoachCareer }) {
  const { profile, teams } = career;
  if (profile.seasons.length === 0) {
    return (
      <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
        No head coaching seasons on record in the {shortName(league)}.
      </section>
    );
  }

  const stints = coachStints(profile.seasons);
  const lines = profile.seasons.map((s) => s.record).filter((r): r is CoachRecord => !!r);
  const showsTies = lines.some((r) => r.ties > 0);
  const showsOTL = lines.some((r) => r.overtimeLosses > 0);
  const columns = ["W", "L", ...(showsTies ? ["T"] : []), ...(showsOTL ? ["OTL"] : []), "PCT"];
  const values = (record: CoachRecord | undefined): string[] => {
    if (!record) return columns.map(() => "–");
    return [
      String(record.wins),
      String(record.losses),
      ...(showsTies ? [String(record.ties)] : []),
      ...(showsOTL ? [String(record.overtimeLosses)] : []),
      winPercentText(record) ?? "–",
    ];
  };
  // The rows are regular seasons, so the closing line is too where ESPN
  // splits it; college football's only line is its total.
  const footer =
    profile.records.find((r) => r.kind === "regular") ??
    profile.records.find((r) => r.kind === "total");

  return (
    <>
      <section className="card-surface pb-1">
        <CardHeader title="Teams coached" />
        {stints.map((stint, index) => {
          const label = teams[stint.teamId];
          const record = stintRecord(stint);
          return (
            <Fragment key={`${stint.teamId}-${stint.seasons[0]?.year}`}>
              {index > 0 && <div className="ml-4 border-t border-divider" />}
              <Link
                href={teamPath({ league, id: stint.teamId })}
                className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none"
              >
                <span className="flex h-7 w-7 shrink-0 items-center justify-center">
                  {label?.logoUrl && (
                    <Image
                      src={label.logoUrl}
                      alt=""
                      width={28}
                      height={28}
                      unoptimized
                      className="h-7 w-7 object-contain"
                    />
                  )}
                </span>
                <span className="min-w-0 flex-1">
                  <span className="block truncate type-team-name text-text-primary">
                    {label?.name ?? `Team ${stint.teamId}`}
                  </span>
                  <span className="block type-meta text-text-secondary">{stintSpan(stint, league)}</span>
                </span>
                {record && (
                  <span className="shrink-0 tnum type-team-name-em text-text-primary">
                    {recordSummary(record)}
                  </span>
                )}
                <ChevronRight aria-hidden="true" className="h-3 w-3 shrink-0 text-text-secondary" />
              </Link>
            </Fragment>
          );
        })}
      </section>

      <section className="card-surface">
        <CardHeader title="By season" />
        <div className="overflow-x-auto">
          <table className="w-full min-w-max border-collapse">
            <thead>
              <tr className="type-row-meta-medium text-text-secondary">
                <th scope="col" className="sticky left-0 z-10 bg-bg-card px-4 py-2 text-left font-normal">
                  <span className="sr-only">Season</span>
                </th>
                {columns.map((column) => (
                  <th key={column} scope="col" className="px-2 py-2 text-right font-normal last:pr-4">
                    <span aria-hidden="true">{column}</span>
                    <span className="sr-only">{SPOKEN[column]}</span>
                  </th>
                ))}
              </tr>
            </thead>
            <tbody>
              {profile.seasons.map((season) => (
                <tr key={seasonId(season)} className="border-t border-divider align-middle">
                  <th scope="row" className="sticky left-0 z-10 bg-bg-card px-4 py-2 text-left font-normal">
                    <span className="flex items-baseline gap-1.5 whitespace-nowrap">
                      <span className="tnum type-row-name text-text-primary">
                        {seasonLabel(league, season.year)}
                      </span>
                      {teams[season.teamId]?.abbreviation && (
                        <span className="type-row-meta text-text-secondary">
                          {teams[season.teamId]?.abbreviation}
                        </span>
                      )}
                    </span>
                  </th>
                  {values(season.record).map((value, index) => (
                    <td
                      key={index}
                      className="px-2 py-2 text-right tnum type-row-name text-text-primary last:pr-4"
                    >
                      {value}
                    </td>
                  ))}
                </tr>
              ))}
              {footer && (
                <tr className="border-t border-divider">
                  <th
                    scope="row"
                    className="sticky left-0 z-10 bg-bg-card px-4 py-2 text-left type-row-name-em text-text-primary"
                  >
                    Career
                  </th>
                  {values(footer).map((value, index) => (
                    <td
                      key={`career-${index}`}
                      className="px-2 py-2 text-right tnum type-row-name-em text-text-primary last:pr-4"
                    >
                      {value}
                    </td>
                  ))}
                </tr>
              )}
            </tbody>
          </table>
        </div>
      </section>
    </>
  );
}
