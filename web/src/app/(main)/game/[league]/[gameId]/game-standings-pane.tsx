"use client";

// The game page's Standings tab (iOS `GameStandingsPane`, 2026-10-24): the
// tables the two sides sit in, both rows tinted, under the team page's
// scope chip where the league has scopes.
//
// One card per table, headed by its name, so a cross-conference game reads
// as two tables with one highlighted row each and a divisional game as one
// table with two. Conference first, the team page's default: the matchup
// sits mid-hierarchy, and Division and League are one tap either side.

import { useState } from "react";
import { CardHeader } from "@/components/card-header";
import { Skeleton } from "@/components/ui/skeleton";
import { StandingsList } from "@/components/standings-list";
import { StandingsScopeChip } from "@/components/standings-scope-chip";
import { conferenceName, isKnownConference } from "@/lib/conferences";
import type { OnDemand } from "@/lib/hooks/use-on-demand";
import { gameStandingsScopes, gameStandingsTables } from "@/lib/game-standings";
import type { League } from "@/lib/leagues";
import type { StandingsScope } from "@/lib/standings-scope";
import type { ConferenceStandingsGroup, GameStandings } from "@/lib/types";

interface GameStandingsPaneProps {
  league: League;
  awayId: string;
  homeId: string;
  state: OnDemand<GameStandings>;
  onRetry: () => void;
}

export function GameStandingsPane({
  league,
  awayId,
  homeId,
  state,
  onRetry,
}: GameStandingsPaneProps) {
  const scopes = gameStandingsScopes(league);
  const [scope, setScope] = useState<StandingsScope>("conference");
  const shownScope = scopes.length === 0 ? undefined : scope;

  return (
    <div className="flex flex-col gap-2">
      {/* The pane's one control, above the cards it shapes. Absent in
          college sports, which have nothing to scope. */}
      {scopes.length > 1 && (
        <div className="flex items-center px-2">
          <StandingsScopeChip
            scopes={scopes}
            selection={scope}
            base="conference"
            onSelect={setScope}
          />
        </div>
      )}
      {state.status === "loading" ? (
        <StandingsSkeleton />
      ) : state.status === "failed" ? (
        <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
          <p className="type-team-name text-text-secondary">
            Couldn&apos;t load standings.
          </p>
          <button
            type="button"
            onClick={onRetry}
            className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
          >
            Retry
          </button>
        </section>
      ) : (
        <Tables
          league={league}
          year={state.value.year}
          tables={gameStandingsTables(
            state.value.groups,
            league,
            awayId,
            homeId,
            shownScope
          )}
          highlighted={[awayId, homeId]}
        />
      )}
    </div>
  );
}

function Tables({
  league,
  year,
  tables,
  highlighted,
}: {
  league: League;
  year: number;
  tables: ConferenceStandingsGroup[];
  highlighted: string[];
}) {
  if (tables.length === 0) {
    return (
      <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
        Standings TBA
      </section>
    );
  }
  return tables.map((table) => (
    <section key={`${table.league}-${table.id}`} className="card-surface pb-1">
      <CardHeader title={title(table)} />
      <StandingsList
        league={league}
        entries={table.entries}
        conferenceId={Number(table.id)}
        year={year}
        // A division's top two are not the conference's, and only college
        // football's conferences play a top-two title game.
        showsCut={table.parentId === undefined && !table.spansDivisions}
        highlightTeamIds={highlighted}
        highlightFill="elevated"
      />
    </section>
  ));
}

/**
 * The registry's name where it knows the table — "SEC", "NFC South" — and
 * ESPN's own otherwise, so a realigned or unknown group still says what it is.
 */
function title(table: ConferenceStandingsGroup): string {
  const id = Number(table.id);
  return isKnownConference(id, table.league)
    ? conferenceName(id, table.league)
    : table.name;
}

/** A table's shape while it loads: a header and a few rows. */
function StandingsSkeleton() {
  return (
    <section aria-busy="true" className="card-surface pb-1">
      <div className="p-3">
        <Skeleton className="h-4 w-24" />
      </div>
      <div className="border-t border-divider" />
      {[0, 1, 2, 3, 4].map((row) => (
        <div key={row} className="flex items-center gap-3 px-4 py-2.5">
          <Skeleton className="h-5 w-5 rounded-full" />
          <Skeleton className="h-3.5 flex-1" />
          <Skeleton className="h-3.5 w-12" />
        </div>
      ))}
    </section>
  );
}
