"use client";

// One row of a Roster tab column (iOS `GameRosterCell`, `GameCoachCell`,
// `GameInjuryCell`): disc, name, and the facts under it. Half a card wide,
// so one line each and the name truncates. At 10px vertical padding — a
// 52px pitch around the 32px disc (Andy, 2026-10-18: "a little dense, these
// need a little space on top and bottom in between each row to breathe").
// A link to the person's page, as every name in the app is, where ESPN sent
// a real id.

import Link from "next/link";
import type { League } from "@/lib/leagues";
import type { GameInjury, Team } from "@/lib/types";
import type { GameRosterPerson } from "@/lib/game-roster";
import type { GameCoachLine } from "@/lib/coach-staff";
import { playerHref } from "@/lib/player-profile";
import { coachPath } from "@/lib/routes";
import { InitialsDisc, PersonDisc } from "./person-disc";

const ROW = "flex items-center gap-2 px-4 py-2.5";
const LINK =
  "transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none";

export function GameRosterCell({
  person,
  team,
  league,
}: {
  person: GameRosterPerson;
  team: Team;
  league: League;
}) {
  const meta = [person.jersey ? `#${person.jersey}` : undefined, person.position, person.note]
    .filter((part): part is string => Boolean(part))
    .join(" · ");
  const spoken = [
    person.jersey ? `Number ${person.jersey}` : undefined,
    person.name,
    person.positionName ?? person.position,
    person.note,
  ]
    .filter((part): part is string => Boolean(part))
    .join(", ");
  return (
    <Link
      href={playerHref(league, team.id, person.id)}
      aria-label={spoken}
      className={`${ROW} ${LINK}`}
    >
      <PersonDisc jersey={person.jersey} headshotUrl={person.headshotUrl} />
      <span aria-hidden="true" className="min-w-0 flex-1">
        <span className="block truncate type-team-name text-text-primary">{person.name}</span>
        {meta && <span className="block truncate type-meta text-text-secondary">{meta}</span>}
      </span>
    </Link>
  );
}

export function GameCoachCell({
  coach,
  team,
  league,
}: {
  coach: GameCoachLine;
  team: Team;
  league: League;
}) {
  const content = (
    <>
      <InitialsDisc name={coach.name} />
      <span className="min-w-0 flex-1">
        <span className="block truncate type-team-name text-text-primary">{coach.name}</span>
        {/* Wraps, and breaks inside "coordinator/quarterbacks" rather than
            running out of a half-width column. */}
        <span className="block break-words type-meta text-text-secondary">{coach.role}</span>
      </span>
    </>
  );
  return coach.coachId ? (
    <Link href={coachPath(league, coach.coachId, team.id)} className={`${ROW} ${LINK}`}>
      {content}
    </Link>
  ) : (
    <div className={ROW}>{content}</div>
  );
}

/** "Oct 25" out of ESPN's bare `yyyy-MM-dd`, or undefined when it doesn't
 *  parse. Built from the parts, not `Date.parse`, so the day doesn't slip a
 *  timezone. */
export function returnDateText(returnDate: string | undefined): string | undefined {
  if (!returnDate) return undefined;
  const parts = returnDate.split("-").map(Number);
  if (parts.length !== 3 || parts.some((part) => !Number.isInteger(part))) return undefined;
  const [year, month, day] = parts as [number, number, number];
  const date = new Date(year, month - 1, day);
  if (Number.isNaN(date.getTime())) return undefined;
  return date.toLocaleDateString("en-US", { month: "short", day: "numeric" });
}

export function GameInjuryCell({
  injury,
  team,
  league,
}: {
  injury: GameInjury;
  team: Team;
  league: League;
}) {
  // "CB · Neck · Oct 25": the position, the ailment and the return date
  // ESPN gives, each dropping out on its own.
  const detail = [injury.position, injury.detail, returnDateText(injury.returnDate)]
    .filter((part): part is string => Boolean(part))
    .join(" · ");
  const content = (
    <>
      <PersonDisc jersey={injury.jersey} headshotUrl={injury.headshotUrl} />
      <span className="min-w-0 flex-1">
        <span className="block truncate type-team-name text-text-primary">{injury.name}</span>
        <span className="block truncate type-meta-em text-text-secondary">{injury.status}</span>
        {detail && <span className="block type-meta text-text-secondary">{detail}</span>}
      </span>
    </>
  );
  // A synthesized id (`teamId-name`, no athlete behind it) must never become
  // a navigation target — the box score's rule (2026-09-24).
  const linkable = /^\d+$/.test(injury.id);
  return linkable ? (
    <Link href={playerHref(league, team.id, injury.id)} className={`${ROW} items-start ${LINK}`}>
      {content}
    </Link>
  ) : (
    <div className={`${ROW} items-start`}>{content}</div>
  );
}
