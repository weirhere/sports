// The game page's standings slice (iOS MatchupStandings): just the two
// competing teams — each with its conference, place, and records so far.
// Same conference → one caption and both rows in place order; a
// cross-conference matchup gets a caption per side. Rows push the full
// conference table.

import Link from "next/link";
import type {
  ConferenceStanding,
  ConferenceStandingsGroup,
  Team,
} from "@/lib/types";
import { TeamLogo } from "@/components/team-logo";
import { DetailCard } from "./detail-card";

interface Slot {
  group: ConferenceStandingsGroup;
  /** 1-based place in the displayed order. */
  position: number;
  standing: ConferenceStanding;
}

function slotFor(
  team: Team,
  standings: ConferenceStandingsGroup[]
): Slot | undefined {
  for (const group of standings) {
    const index = group.entries.findIndex(
      (entry) => entry.team.id === team.id
    );
    if (index !== -1) {
      return { group, position: index + 1, standing: group.entries[index] };
    }
  }
  return undefined;
}

/**
 * Whether either side has a row worth showing. Preseason hides the card
 * entirely — the place numbers are last season's carried-over order — but
 * "preseason" is a property of the SEASON, not the matchup: once anyone
 * anywhere has played, the tables are live. The underway check reads the
 * OVERALL record; a September team legitimately sits 0-0 in conference.
 */
export function matchupStandingsHasContent(
  away: Team,
  home: Team,
  standings: ConferenceStandingsGroup[]
): boolean {
  const knowsASide = standings.some((group) =>
    group.entries.some(
      (entry) => entry.team.id === away.id || entry.team.id === home.id
    )
  );
  const seasonUnderway = standings.some((group) =>
    group.entries.some(
      (entry) =>
        entry.overallRecord !== undefined && entry.overallRecord !== "0-0"
    )
  );
  return knowsASide && seasonUnderway;
}

interface MatchupStandingsCardProps {
  away: Team;
  home: Team;
  standings: ConferenceStandingsGroup[];
}

export function MatchupStandingsCard({
  away,
  home,
  standings,
}: MatchupStandingsCardProps) {
  const awaySlot = slotFor(away, standings);
  const homeSlot = slotFor(home, standings);

  const sameConference =
    awaySlot !== undefined &&
    homeSlot !== undefined &&
    awaySlot.group.id === homeSlot.group.id;

  return (
    <DetailCard title="Standings">
      <div className="pb-1">
        <ColumnCaptions />
        {sameConference ? (
          <>
            <ConferenceCaption name={awaySlot.group.name} />
            {[awaySlot, homeSlot]
              .sort((a, b) => a.position - b.position)
              .map((slot) => (
                <StandingRow key={slot.standing.team.id} slot={slot} />
              ))}
          </>
        ) : (
          <>
            {awaySlot && (
              <>
                <ConferenceCaption name={awaySlot.group.name} />
                <StandingRow slot={awaySlot} />
              </>
            )}
            {homeSlot && (
              <>
                <ConferenceCaption name={homeSlot.group.name} />
                <StandingRow slot={homeSlot} />
              </>
            )}
          </>
        )}
      </div>
    </DetailCard>
  );
}

/** Mirrors the row's column metrics so captions align with the numbers. */
function ColumnCaptions() {
  return (
    <div
      aria-hidden="true"
      className="flex items-center gap-3 px-4 pb-1 pt-2 type-meta text-text-secondary"
    >
      <span className="w-4 text-right">#</span>
      <span className="flex-1">TEAM</span>
      <span className="w-11 text-right">CONF</span>
      <span className="w-11 text-right">OVR</span>
    </div>
  );
}

function ConferenceCaption({ name }: { name: string }) {
  return (
    <h3 className="px-4 pb-1 pt-2 type-meta text-text-secondary">{name}</h3>
  );
}

/**
 * One team's line: place, logo, school, then conference and overall
 * records in aligned trailing columns — a link to the conference table.
 * One spoken sentence: "Number 3, Georgia, 7 and 1 in conference, 13 and 2
 * overall".
 */
function StandingRow({ slot }: { slot: Slot }) {
  const { standing, position, group } = slot;
  return (
    <Link
      href={`/conference/${group.id}`}
      aria-label={spokenSummary(slot)}
      className="flex items-center gap-3 px-4 py-2.5 transition-colors hover:bg-bg-header"
    >
      <span
        aria-hidden="true"
        className="w-4 shrink-0 text-right type-meta-em tnum text-text-secondary"
      >
        {position}
      </span>
      <TeamLogo
        espnId={standing.team.espnId}
        teamName=""
        size="sm"
        className="h-5 w-5 shrink-0"
      />
      <span
        aria-hidden="true"
        className="min-w-0 flex-1 truncate type-team-name text-text-primary"
      >
        {standing.team.school}
      </span>
      <span
        aria-hidden="true"
        className="w-11 shrink-0 text-right type-team-name tnum text-text-primary"
      >
        {standing.conferenceRecord ?? "–"}
      </span>
      <span
        aria-hidden="true"
        className="w-11 shrink-0 text-right type-team-name tnum text-text-primary"
      >
        {standing.overallRecord ?? "–"}
      </span>
    </Link>
  );
}

function spokenSummary({ standing, position }: Slot): string {
  const spoken = (record: string) => record.replaceAll("-", " and ");
  const parts = [`Number ${position}`, standing.team.school];
  if (standing.conferenceRecord) {
    parts.push(`${spoken(standing.conferenceRecord)} in conference`);
  }
  if (standing.overallRecord) {
    parts.push(`${spoken(standing.overallRecord)} overall`);
  }
  return parts.join(", ");
}
