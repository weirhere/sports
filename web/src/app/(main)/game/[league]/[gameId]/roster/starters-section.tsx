"use client";

// The Roster tab's Starters section in whichever layout the reader chose
// (iOS `StartersSection`, Andy, 2026-10-18): the painted field, full bleed
// with its title row on the paint, or the list cards, inset like every other
// card on the tab with the title row on the page above them. The choice is
// one chip tap on the section and persists (`useStartersLayout`).

import type { League } from "@/lib/leagues";
import type { StartersLayout } from "@/lib/hooks/use-starters-layout";
import type { GameRoster } from "@/lib/game-roster";
import { FormationCard } from "./formation-card";
import { StartersHeader } from "./starters-header";
import { StartersListCards } from "./starters-list-cards";

export function StartersSection({
  roster,
  league,
  layout,
  onLayoutChange,
  offenseTeamId,
  onOffenseChange,
}: {
  roster: GameRoster;
  league: League;
  layout: StartersLayout;
  onLayoutChange: (layout: StartersLayout) => void;
  offenseTeamId?: string;
  onOffenseChange: (teamId: string) => void;
}) {
  if (layout === "field") {
    return (
      <FormationCard
        roster={roster}
        league={league}
        offenseTeamId={offenseTeamId}
        onOffenseChange={onOffenseChange}
        layout={layout}
        onLayoutChange={onLayoutChange}
      />
    );
  }
  return (
    <div className="flex flex-col gap-2">
      <div className="py-2">
        <StartersHeader roster={roster} league={league} layout={layout} onLayoutChange={onLayoutChange} />
      </div>
      <StartersListCards roster={roster} league={league} />
    </div>
  );
}
