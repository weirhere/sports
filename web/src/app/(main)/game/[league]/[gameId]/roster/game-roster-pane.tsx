"use client";

// The game page's Roster tab (iOS `GameRosterPane`, E29, 2026-10-18): who is
// in the game, in FotMob's Lineup order — the starters drawn on the field,
// the coaches, the bench, the inactives, and the injured at the bottom —
// with the away side on the left of every card and the home side on the
// right.
//
// The same five cards in every state; only their names move with it. Before
// kickoff the bench card is the roster ("planning to play"), live it is the
// bench, after the final it is everyone else who played.
//
// Assembled here, on every render, from the sources the route served and
// the live summary the page already holds: the box score, the injuries and
// the skaters on the ice ride the 1s poll, so the bench follows the game
// without a second request. A refetch that fails keeps the lists it had
// rather than replacing them with Retry.

import { useEffect, useState } from "react";
import type { League } from "@/lib/leagues";
import type { Game, GameDetail, GameRosterSources } from "@/lib/types";
import type { OnDemand } from "@/lib/hooks/use-on-demand";
import { useStartersLayout } from "@/lib/hooks/use-starters-layout";
import { useCoachStaffFile } from "@/lib/hooks/use-coach-staff";
import { coachLines, staffFor, type GameCoachLine } from "@/lib/coach-staff";
import { isFootball } from "@/lib/formation";
import {
  inactiveTitle,
  makeGameRoster,
  othersTitle,
  rosterIsEmpty,
  rosterPhase,
  unitGroups,
  unitTitle,
  type GameRosterPerson,
} from "@/lib/game-roster";
import type { GameInjury } from "@/lib/types";
import { cn } from "@/lib/utils";
import { StartersSection } from "./starters-section";
import { RosterSidesCard } from "./roster-sides-card";
import { GameCoachCell, GameInjuryCell, GameRosterCell } from "./roster-cells";

export function GameRosterPane({
  league,
  game,
  detail,
  state,
  onRetry,
  possessionTeamId,
}: {
  league: League;
  game: Game;
  /** The page's live summary — its box score, injuries and on-ice list are
   *  sources too. */
  detail: GameDetail;
  state: OnDemand<GameRosterSources>;
  onRetry: () => void;
  /** Live football: whose offense the formation opens on. */
  possessionTeamId?: string;
}) {
  const [layout, setLayout] = useStartersLayout();
  const coachFile = useCoachStaffFile();
  // Football's chip, owned here so it survives the card re-rendering. Opens
  // on the possession team live, the away team otherwise.
  const [offenseTeamId, setOffenseTeamId] = useState<string | undefined>(undefined);
  const chosenOffense = offenseTeamId ?? possessionTeamId ?? game.awayTeam.team.id;

  // The last sources that loaded, so a phase flip's refetch keeps the lists
  // on screen instead of a spinner, and a failed refetch keeps them too.
  const [lastSources, setLastSources] = useState<GameRosterSources | undefined>(undefined);
  useEffect(() => {
    // eslint-disable-next-line react-hooks/set-state-in-effect
    if (state.status === "loaded") setLastSources(state.value);
  }, [state]);
  const sources = state.status === "loaded" ? state.value : lastSources;

  if (!sources) {
    if (state.status === "failed") {
      return (
        <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
          <p className="type-team-name text-text-secondary">Couldn&apos;t load the roster.</p>
          <button
            type="button"
            onClick={onRetry}
            className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
          >
            Retry
          </button>
        </section>
      );
    }
    // A lone spinner gets no card (Andy, 2026-08-31).
    return (
      <div className="flex justify-center py-8" role="status" aria-label="Loading the roster">
        <span className="h-5 w-5 animate-spin rounded-full border-2 border-divider border-t-text-secondary" />
      </div>
    );
  }

  const phase = rosterPhase(game.status);
  const away = game.awayTeam.team;
  const home = game.homeTeam.team;
  const boxFor = (teamId: string) =>
    (detail.boxScore ?? []).find((entry) => entry.teamId === String(teamId));
  const injuriesFor = (teamId: string) =>
    (detail.injuries ?? []).find((entry) => entry.teamId === teamId)?.injuries ?? [];
  const roster = makeGameRoster(
    phase,
    league,
    {
      team: away,
      ...sources.away,
      boxScore: boxFor(away.id),
      injuries: injuriesFor(away.id),
      onIce: detail.onIce?.[away.id] ?? [],
    },
    {
      team: home,
      ...sources.home,
      boxScore: boxFor(home.id),
      injuries: injuriesFor(home.id),
      onIce: detail.onIce?.[home.id] ?? [],
    }
  );

  if (rosterIsEmpty(roster)) {
    return (
      <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
        {phase === "upcoming" ? "Lineups TBA" : "No lineup for this game."}
      </section>
    );
  }

  const hasStarters = roster.away.starters.length > 0 || roster.home.starters.length > 0;
  // Whether the first thing on the pane is the painted field — which then
  // meets the tab row with no gap above it (Andy, 2026-10-18: the 8px of
  // page above it read as a seam).
  const leadsWithField = hasStarters && layout === "field";
  const football = isFootball(league);

  const awayCoaches = coachLines(roster.away.coach, staffFor(coachFile, league, away.id));
  const homeCoaches = coachLines(roster.home.coach, staffFor(coachFile, league, home.id));
  // Grouped by unit in football (Andy, 2026-10-18): the kicker and the
  // punter are never among the 22 ESPN flags as starters, so the bench is
  // where special teams live, and "Special teams" is the caption that gives
  // them a place. The inactives and the injured stay one list each — those
  // cards are about why, not where.
  const otherGroups = unitGroups(roster.away.others, roster.home.others, league);

  return (
    <div className={cn("flex flex-col gap-2", leadsWithField && "-mt-2")}>
      {hasStarters && (
        <StartersSection
          roster={roster}
          league={league}
          layout={layout}
          onLayoutChange={setLayout}
          offenseTeamId={chosenOffense}
          onOffenseChange={setOffenseTeamId}
        />
      )}
      {(awayCoaches.length > 0 || homeCoaches.length > 0) && (
        <RosterSidesCard<GameCoachLine>
          title="Coaches"
          away={away}
          home={home}
          groups={[{ id: "coaches", away: awayCoaches, home: homeCoaches }]}
          itemKey={(coach) => coach.id}
          cell={(coach, team) => <GameCoachCell coach={coach} team={team} league={league} />}
        />
      )}
      {otherGroups.length > 0 && (
        <RosterSidesCard<GameRosterPerson>
          title={othersTitle(roster.phase)}
          away={away}
          home={home}
          groups={otherGroups.map((group) => ({
            id: group.id,
            caption: football ? (group.unit ? unitTitle(group.unit) : "Other") : undefined,
            away: group.away,
            home: group.home,
          }))}
          itemKey={(person) => person.id}
          cell={(person, team) => <GameRosterCell person={person} team={team} league={league} />}
        />
      )}
      {(roster.away.inactive.length > 0 || roster.home.inactive.length > 0) && (
        <RosterSidesCard<GameRosterPerson>
          title={inactiveTitle(league)}
          away={away}
          home={home}
          groups={[{ id: "inactive", away: roster.away.inactive, home: roster.home.inactive }]}
          itemKey={(person) => person.id}
          cell={(person, team) => <GameRosterCell person={person} team={team} league={league} />}
        />
      )}
      {(roster.away.injuries.length > 0 || roster.home.injuries.length > 0) && (
        <RosterSidesCard<GameInjury>
          title="Injuries"
          away={away}
          home={home}
          groups={[{ id: "injuries", away: roster.away.injuries, home: roster.home.injuries }]}
          itemKey={(injury) => injury.id}
          cell={(injury, team) => <GameInjuryCell injury={injury} team={team} league={league} />}
        />
      )}
    </div>
  );
}
