"use client";

// The Starters section as the list the rest of the Roster tab is made of
// (iOS `StartersListCards`, Andy, 2026-10-18): football's starters in an
// Offense, a Defense and a Special teams card, the NBA's and NHL's in one,
// each a two-column card in jersey order — the team Roster tab's order, for
// its reason. Every starter is placed; a football starter at a position the
// unit table doesn't know gets an "Also starting" card rather than a dropped
// row.

import type { League } from "@/lib/leagues";
import { isFootball } from "@/lib/formation";
import {
  sortedByJersey,
  unitGroups,
  unitTitle,
  type GameRoster,
  type GameRosterPerson,
} from "@/lib/game-roster";
import { RosterSidesCard } from "./roster-sides-card";
import { GameRosterCell } from "./roster-cells";

export function StartersListCards({ roster, league }: { roster: GameRoster; league: League }) {
  const football = isFootball(league);
  const groups = unitGroups(
    sortedByJersey(roster.away.starters),
    sortedByJersey(roster.home.starters),
    league
  );
  return (
    <>
      {groups.map((group) => (
        <RosterSidesCard<GameRosterPerson>
          key={group.id}
          title={football ? (group.unit ? unitTitle(group.unit) : "Also starting") : undefined}
          away={roster.away.team}
          home={roster.home.team}
          groups={[{ id: group.id, away: group.away, home: group.home }]}
          itemKey={(person) => person.id}
          cell={(person, team) => <GameRosterCell person={person} team={team} league={league} />}
        />
      ))}
    </>
  );
}
