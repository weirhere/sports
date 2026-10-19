// A card with the two teams side by side — away on the left, home on the
// right, the order American sports list them in (Andy, 2026-10-18) — each
// column a run of the caller's cells under the team's own mark. FotMob's
// bench, coach and injuries cards share this shape (iOS `RosterSidesCard`).
//
// The columns can be cut into captioned groups: a football bench reads
// Offense, Defense, Special teams, each caption a row across the whole card
// with the two columns under it, so the two sides' kickers sit level instead
// of wherever their numbers fell. The team marks stay at the top, once; a
// card with one uncaptioned group is the plain two-column card.

import { Fragment } from "react";
import type { Team } from "@/lib/types";
import { CardHeader } from "@/components/card-header";
import { TeamMark } from "../team-mark";
import { teamShortName } from "@/lib/game-roster";

export interface SidesGroup<Item> {
  id: string;
  /** Undefined for a run that is the card's whole body. */
  caption?: string;
  away: Item[];
  home: Item[];
}

export function RosterSidesCard<Item>({
  title,
  subtitle,
  away,
  home,
  groups,
  itemKey,
  cell,
}: {
  /** Undefined for a card whose team columns are its whole header — the
   *  NBA's and NHL's one starters card under the section's own title. */
  title?: string;
  subtitle?: string;
  away: Team;
  home: Team;
  groups: SidesGroup<Item>[];
  itemKey: (item: Item) => string;
  cell: (item: Item, team: Team) => React.ReactNode;
}) {
  const column = (items: Item[], team: Team) => (
    <div className="min-w-0 flex-1">
      {items.length === 0 ? (
        <p className="px-4 py-2 type-meta text-text-secondary">None</p>
      ) : (
        items.map((item) => <Fragment key={itemKey(item)}>{cell(item, team)}</Fragment>)
      )}
    </div>
  );
  const shown = groups.length > 0 ? groups : [{ id: "all", away: [], home: [] } as SidesGroup<Item>];
  return (
    <section className="card-surface pb-1">
      {title && <CardHeader title={title} subtitle={subtitle} />}
      <div className="flex items-start">
        <Mark team={away} />
        <Mark team={home} />
      </div>
      {shown.map((group, index) => (
        <Fragment key={group.id}>
          {group.caption && (
            <>
              {index > 0 && <div className="mx-4 border-t border-divider" />}
              <h4 className="px-4 pb-1 pt-2 type-meta uppercase text-text-secondary">
                {group.caption}
              </h4>
            </>
          )}
          <div className="flex items-start">
            {column(group.away, away)}
            {column(group.home, home)}
          </div>
        </Fragment>
      ))}
    </section>
  );
}

function Mark({ team }: { team: Team }) {
  return (
    <div
      className="flex min-w-0 flex-1 items-center gap-1 px-4 pb-1 pt-4"
      aria-label={team.school}
    >
      <TeamMark logoUrl={team.logoUrl} alt="" size={16} className="h-4 w-4 shrink-0" />
      <span className="truncate type-meta-em text-text-secondary">{teamShortName(team)}</span>
    </div>
  );
}
