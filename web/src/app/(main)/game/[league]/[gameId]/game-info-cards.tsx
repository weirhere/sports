// The pre-kick pair, split in two (iOS, 2026-09-09): **Game info** —
// when to watch, where to watch, what it'll be like out — and **Venue** —
// the ground itself and the crowd on it.
//
// One card was answering two questions, and the second half only existed
// pre-kick, which is what left the played-game card still titled after a
// card it no longer resembled. The weather rides with the kickoff rather
// than the ground: it is the other thing that stops mattering the moment
// the game starts.

import type { LucideIcon } from "lucide-react";
import { VenueHeadline } from "@/components/venue-headline";
import { Calendar, CloudSun, Tv } from "lucide-react";
import Image from "next/image";
import Link from "next/link";
import {
  conferenceName,
  divisionForTeamId,
  isDivisionRoot,
  leagueWideId,
  parentOf,
  rootAbove,
} from "@/lib/conferences";
import { leagueLogoUrl, type League } from "@/lib/leagues";
import { conferencePath } from "@/lib/routes";
import type { ConferenceRef } from "@/lib/refs";
import type {
  ConferenceStandingsGroup,
  Game,
  GameDetail,
  Team,
} from "@/lib/types";
import { DetailCard } from "./detail-card";
import { kickoffDayText, kickoffTimeText } from "./game-status";

// --- Game info -------------------------------------------------------------

export function gameInfoHasContent(
  game: Game,
  detail: GameDetail,
  standings?: ConferenceStandingsGroup[] | null
): boolean {
  return (
    Boolean(game.scheduledAt) ||
    Boolean(game.broadcast) ||
    weatherLine(detail) !== undefined ||
    leagueDestinations(game, standings).length > 0
  );
}

export function GameInfoCard({
  game,
  detail,
  standings,
}: {
  game: Game;
  detail: GameDetail;
  /** The tables the page already fetched — how a side is placed when the
   *  summary payload ships no conference of its own. */
  standings?: ConferenceStandingsGroup[] | null;
}) {
  if (!gameInfoHasContent(game, detail, standings)) return null;
  const tables = leagueDestinations(game, standings);
  const weather = weatherLine(detail);

  return (
    <DetailCard title="Game info">
      <div className="py-1">
        {tables.length > 0 && (
          <GameLeagueRow league={game.league} destinations={tables} />
        )}
        {game.scheduledAt && (
          <InfoLine
            icon={Calendar}
            text={
              game.timeTBD
                ? `${kickoffDayText(game.scheduledAt)} · Kickoff TBD`
                : `${kickoffDayText(game.scheduledAt)} · ${kickoffTimeText(game.scheduledAt)}`
            }
          />
        )}
        {game.broadcast && <InfoLine icon={Tv} text={game.broadcast} />}
        {weather && <InfoLine icon={CloudSun} text={weather} />}
      </div>
    </DetailCard>
  );
}

function weatherLine(detail: GameDetail): string | undefined {
  const line = [
    detail.weatherTemperature !== undefined
      ? `${detail.weatherTemperature}°`
      : undefined,
    detail.weatherCondition,
  ]
    .filter(Boolean)
    .join(" · ");
  return line || undefined;
}

function InfoLine({ icon: Icon, text }: { icon: LucideIcon; text: string }) {
  return (
    <div className="flex items-center gap-3 px-4 py-[7px]">
      <Icon aria-hidden="true" className="h-4 w-5 shrink-0 text-text-secondary" />
      <span className="type-team-name tnum text-text-primary">{text}</span>
    </div>
  );
}

/**
 * What this game belongs to: the league's mark in the icon gutter the
 * kickoff, network and weather lines use, then a tappable badge per table it
 * counts toward — the league, then each side's conference.
 *
 * The mark stands in for a "League" label — the shield says which
 * competition faster than the word does, and it puts the row on the same x
 * as every line beneath it. A screen reader still hears the words, since a
 * mark reads as nothing at all.
 */
function GameLeagueRow({
  league,
  destinations,
}: {
  league: League;
  destinations: ConferenceRef[];
}) {
  const mark = leagueLogoUrl(league);
  return (
    <div className="flex items-start gap-3 px-4 py-[7px]">
      <span
        aria-hidden="true"
        className="flex h-4 w-5 shrink-0 items-center justify-center"
      >
        {mark && (
          <Image
            src={mark}
            alt=""
            width={18}
            height={18}
            unoptimized
            className="h-[18px] w-[18px] object-contain"
          />
        )}
      </span>
      {/* Two long conference names and a division root don't fit one line at
          every width, so the badges wrap rather than truncating a name the
          badge exists to say. */}
      <div className="flex min-w-0 flex-wrap items-center gap-2">
        {destinations.map((ref) => (
          <Link
            key={`${ref.league}-${ref.id}`}
            href={conferencePath(ref)}
            aria-label={conferenceName(ref.id, ref.league)}
            className="inline-flex items-center rounded-full bg-bg-elevated px-2.5 py-1 type-row-meta-medium text-text-primary transition-colors hover:bg-divider"
          >
            {conferenceName(ref.id, ref.league)}
          </Link>
        ))}
      </div>
    </div>
  );
}

/**
 * The tables above this game, widest first: a pro league's whole-league one
 * or the college-football division its teams play in, then the conference
 * each side plays in.
 *
 * A conference game contributes **one** conference badge, not two: the
 * badges are the tables this game appears in, and both sides share one.
 * Empty where neither side can be placed — an unknown group gets no page, so
 * the row doesn't render at all rather than wearing a dead badge.
 */
export function leagueDestinations(
  game: Game,
  standings?: ConferenceStandingsGroup[] | null
): ConferenceRef[] {
  const place = (team: Team) => conferenceOf(team, standings);
  const tables: ConferenceRef[] = [];
  const sides = [game.awayTeam.team, game.homeTeam.team];
  const wide = leagueTable(game, sides.map(place));
  if (wide) tables.push(wide);
  for (const team of sides) {
    const ref = place(team);
    if (!ref) continue;
    if (tables.some((entry) => entry.id === ref.id)) continue;
    tables.push(ref);
  }
  return tables;
}

function leagueTable(
  game: Game,
  placed: (ConferenceRef | undefined)[]
): ConferenceRef | undefined {
  const league = game.league;
  const wide = leagueWideId(league);
  if (wide !== undefined) return { league, id: wide };
  // College football has no whole-league table — the division its teams play
  // in (FBS, FCS) is the widest page there is.
  for (const ref of placed) {
    if (!ref) continue;
    if (isDivisionRoot(ref.id, league)) return ref;
    const root = rootAbove(ref);
    if (root) return root;
  }
  return undefined;
}

/**
 * The conference rung a team plays in: college football's own group id, or
 * the conference above the division a pro league files it in.
 *
 * The division fold is the whole trick. A pro scoreboard ships no group at
 * all, so the mapper stamps a team with its *division* from the registry —
 * which is why the id in hand is as likely to be "AFC East" as "AFC", and
 * why it gets walked up either way.
 */
function conferenceOf(
  team: Team,
  standings?: ConferenceStandingsGroup[] | null
): ConferenceRef | undefined {
  const league = team.league;
  const own = Number(team.conferenceId);
  // The **summary** payload ships no conference at all — a game-detail
  // team arrives with `conferenceId: "0"` (verified live), which is why the
  // page's own standings are the third place to look. Without them the row
  // renders nothing rather than a wrong badge.
  const id =
    Number.isInteger(own) && own !== 0
      ? own
      : (divisionForTeamId(team.id, league) ?? groupContaining(team, standings));
  if (id === undefined) return undefined;
  if (isDivisionRoot(id, league)) return undefined;
  const conference = parentOf(id, league) ?? id;
  return conferenceName(conference, league) !== "Other"
    ? { league, id: conference }
    : undefined;
}

/** The table this team's row actually sits in. */
function groupContaining(
  team: Team,
  standings?: ConferenceStandingsGroup[] | null
): number | undefined {
  const group = standings?.find((entry) =>
    entry.entries.some((row) => row.team.id === team.id)
  );
  const id = group ? Number(group.id) : Number.NaN;
  return Number.isInteger(id) ? id : undefined;
}

// --- Venue -----------------------------------------------------------------

export function venueHasContent(game: Game, detail: GameDetail): boolean {
  return (
    Boolean(game.venue.name) ||
    detail.attendance !== undefined ||
    detail.venueCapacity !== undefined ||
    surfaceOf(detail) !== undefined
  );
}

/**
 * Grass or turf — and nothing at all for a sport played indoors on a floor
 * or on ice, where ESPN still ships `grass: false` and we were rendering it
 * as "Turf" on a hockey rink. The mapper already gates this per league.
 */
function surfaceOf(detail: GameDetail): string | undefined {
  if (detail.venueSurface === undefined) return undefined;
  return detail.venueSurface === "grass" ? "Grass" : "Turf";
}

export function VenueCard({
  game,
  detail,
}: {
  game: Game;
  detail: GameDetail;
}) {
  if (!venueHasContent(game, detail)) return null;
  const city = [game.venue.city, game.venue.state].filter(Boolean).join(", ");
  const surface = surfaceOf(detail);
  const { attendance, venueCapacity } = detail;
  const hasCrowd =
    attendance !== undefined || venueCapacity !== undefined || surface !== undefined;

  return (
    <DetailCard title="Venue">
      <div className="py-1">
        {game.venue.name && (
          <VenueHeadline name={game.venue.name} city={city || undefined} />
        )}
        {game.venue.name && hasCrowd && (
          <div className="my-1 ml-4 border-t border-divider" />
        )}
        {/* Once attendance is public it takes the leading slot and capacity
            becomes its context, with the meter saying how full that made the
            place. Before then, capacity leads on its own beside the surface.
            ESPN ships no capacity on any surface we can reach today, so in
            practice this is attendance beside the surface. */}
        {attendance !== undefined ? (
          <>
            <div
              className="flex flex-col gap-2 px-4 py-[7px]"
              aria-label={crowdSentence(attendance, venueCapacity)}
            >
              <div aria-hidden="true" className="flex items-center gap-3">
                <Metric label="Attendance" value={attendance.toLocaleString("en-US")} />
                {venueCapacity !== undefined && (
                  <span className="ml-auto">
                    <Metric
                      label="Capacity"
                      value={venueCapacity.toLocaleString("en-US")}
                    />
                  </span>
                )}
              </div>
              {venueCapacity !== undefined && venueCapacity > 0 && (
                <FillMeter attendance={attendance} capacity={venueCapacity} />
              )}
            </div>
            {surface && <PairRow label="Surface" value={surface} />}
          </>
        ) : venueCapacity !== undefined ? (
          <div className="flex items-center gap-3 px-4 py-[7px]">
            <Metric label="Capacity" value={venueCapacity.toLocaleString("en-US")} />
            {surface && (
              <span className="ml-auto">
                <Metric label="Surface" value={surface} />
              </span>
            )}
          </div>
        ) : (
          surface && <PairRow label="Surface" value={surface} />
        )}
      </div>
    </DetailCard>
  );
}

function PairRow({ label, value }: { label: string; value: string }) {
  return (
    <div className="flex items-center gap-3 px-4 py-[7px]">
      <Metric label={label} value={value} />
    </div>
  );
}

/** The team-page cards' label/value language: gray label, ink value. */
function Metric({ label, value }: { label: string; value: string }) {
  return (
    <span className="flex items-baseline gap-2">
      <span className="type-row-name text-text-secondary">{label}</span>
      <span className="tnum type-row-name-em text-text-primary">{value}</span>
    </span>
  );
}

/**
 * Ink on a hairline track — a meter is chrome, so the colour budget holds.
 * An overflowing crowd (standing room beats the printed capacity) clamps the
 * fill and still reports its real percentage.
 */
function FillMeter({
  attendance,
  capacity,
}: {
  attendance: number;
  capacity: number;
}) {
  const fraction = Math.min(attendance / capacity, 1);
  return (
    <div aria-hidden="true" className="flex items-center gap-2">
      <div className="h-1.5 min-w-0 flex-1 overflow-hidden rounded-full bg-divider">
        <div
          className="h-full rounded-full bg-text-primary"
          style={{ width: `${Math.max(fraction * 100, 1)}%` }}
        />
      </div>
      <span className="shrink-0 tnum type-row-meta-medium text-text-secondary">
        {fillPercent(attendance, capacity)}%
      </span>
    </div>
  );
}

export function fillPercent(attendance: number, capacity: number): number {
  if (capacity <= 0) return 0;
  return Math.round((attendance / capacity) * 100);
}

function crowdSentence(attendance: number, capacity?: number): string {
  const crowd = attendance.toLocaleString("en-US");
  if (capacity === undefined || capacity <= 0) return `Attendance ${crowd}`;
  return `Attendance ${crowd} of ${capacity.toLocaleString("en-US")} capacity, ${fillPercent(attendance, capacity)} percent full`;
}
