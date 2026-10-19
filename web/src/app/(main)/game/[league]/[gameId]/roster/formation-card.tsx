"use client";

// The Roster tab's lineup section — not a card (iOS `FormationCard`): the
// field runs edge to edge, because eleven across a phone needs every pixel
// it can get and a card's inset was costing it 40 (Andy, 2026-10-18). The
// title and the chips keep the cards' text margin and sit on the surface's
// paint a shade deeper than the field's, with no divider under the title:
// the section is one painted place from its name down to the last row, and
// the shade change is where the field begins.
//
// The two starting units on one field, and in football the chip row that
// decides whose offense is drawn — one team's eleven across the line from
// the other team's eleven, which is the picture a snap makes and the only
// honest one for a sport whose "lineup" changes every change of possession.
// The chips say "HOU offense": a "HOU has the ball" wording was tried and
// reverted the same day — the unit's name felt better (Andy, 2026-10-18).

import type { League } from "@/lib/leagues";
import type { Team } from "@/lib/types";
import { SlateToggleChip } from "@/components/slate-control-row";
import type { StartersLayout } from "@/lib/hooks/use-starters-layout";
import { isFootball, makeFormation, type Formation } from "@/lib/formation";
import {
  teamShortName,
  type GameRoster,
  type GameRosterPerson,
  type GameRosterSide,
} from "@/lib/game-roster";
import { FormationField } from "./formation-field";
import { StartersHeader } from "./starters-header";
import { GameRosterCell } from "./roster-cells";
import { inkAlpha, surfaceBase, surfaceHeading, surfaceInk } from "./surface-ink";

export function FormationCard({
  roster,
  league,
  offenseTeamId,
  onOffenseChange,
  layout,
  onLayoutChange,
}: {
  roster: GameRoster;
  league: League;
  /** Football: the team whose offense is on the field. Owned by the pane so
   *  a chip tap survives this card re-rendering under a poll. */
  offenseTeamId?: string;
  onOffenseChange: (teamId: string) => void;
  layout: StartersLayout;
  onLayoutChange: (layout: StartersLayout) => void;
}) {
  const football = isFootball(league);
  const { away, home } = roster;
  const awayHasBall = offenseTeamId !== home.team.id;
  const ink = surfaceInk(league);

  const formation = (side: GameRosterSide, isOffense: boolean): Formation | undefined =>
    side.starters.length === 0
      ? undefined
      : makeFormation(side.starters, league, football ? (isOffense ? "offense" : "defense") : undefined);
  const unitLabel = (team: Team, isOffense: boolean) =>
    football ? `${teamShortName(team)} ${isOffense ? "offense" : "defense"}` : undefined;

  const awayFormation = formation(away, awayHasBall);
  const homeFormation = formation(home, !awayHasBall);
  const awayUnplaced = awayFormation?.unplaced ?? [];
  const homeUnplaced = homeFormation?.unplaced ?? [];

  return (
    <section className="-mx-4 pb-1 md:mx-0">
      {/* A shade deeper than the field, so the heading reads as the
          section's and the field begins where the shade changes (Andy,
          2026-10-18 — on one green they ran together). */}
      <div style={{ background: surfaceHeading(league) }}>
        {/* The same 8px the pane pads above the list layout's title row, so
            the title sits at one height whichever chip is on. */}
        <div className="px-2 py-2">
          <StartersHeader roster={roster} league={league} layout={layout} onLayoutChange={onLayoutChange} ink={ink} />
        </div>
        {football && (
          <>
            {/* Two rows, not one block: the possession chips keep their own
                8px above and below, with a hairline between them in the
                surface's ink — fainter than the idle chip's outline — so
                they read as their own section under the title. */}
            <div style={{ borderTop: `1px solid ${inkAlpha(ink.text, 0.3)}` }} />
            <div className="flex items-center gap-2 px-6 py-2">
              <SlateToggleChip
                title={`${teamShortName(away.team)} offense`}
                isOn={awayHasBall}
                hint={`Draws ${away.team.school}'s offense against ${home.team.school}'s defense`}
                ink={ink}
                onToggle={() => onOffenseChange(away.team.id)}
              />
              <SlateToggleChip
                title={`${teamShortName(home.team)} offense`}
                isOn={!awayHasBall}
                hint={`Draws ${home.team.school}'s offense against ${away.team.school}'s defense`}
                ink={ink}
                onToggle={() => onOffenseChange(home.team.id)}
              />
            </div>
          </>
        )}
      </div>
      <div style={{ background: surfaceBase(league) }}>
        <FormationField
          league={league}
          top={awayFormation}
          bottom={homeFormation}
          topTeam={away.team}
          bottomTeam={home.team}
          topLabel={unitLabel(away.team, awayHasBall)}
          bottomLabel={unitLabel(home.team, !awayHasBall)}
        />
      </div>
      {/* Starters the layout couldn't place — a position the table doesn't
          know — named under the field rather than dropped. */}
      {(awayUnplaced.length > 0 || homeUnplaced.length > 0) && (
        <div className="flex items-start px-2 pb-1">
          <UnplacedColumn people={awayUnplaced} team={away.team} league={league} />
          <UnplacedColumn people={homeUnplaced} team={home.team} league={league} />
        </div>
      )}
    </section>
  );
}

function UnplacedColumn({
  people,
  team,
  league,
}: {
  people: GameRosterPerson[];
  team: Team;
  league: League;
}) {
  return (
    <div className="min-w-0 flex-1">
      {people.length > 0 && (
        <>
          <p className="px-4 pt-1 type-meta text-text-secondary">Also starting</p>
          {people.map((person) => (
            <GameRosterCell key={person.id} person={person} team={team} league={league} />
          ))}
        </>
      )}
    </div>
  );
}
