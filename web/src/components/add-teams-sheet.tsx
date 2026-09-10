"use client";

// The join-a-team sheet — the web twin of iOS `AddTeamsSheet`: a search field
// over the whole directory, with a curated shortlist standing in until the
// first keystroke and the list swapping to results the moment there is one.
//
// **One card per team, and no league headings** (iOS, 2026-09-06). A single
// card holding fifteen teams under a heading reads as *the* list of that
// league's teams, which makes every team it omits look like an oversight;
// separate cards read as suggestions, which is what they are — and the whole
// directory is one keystroke away in the field above.

import { useMemo, useState } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { SearchField } from "@/components/search-field";
import { TeamFollowRow } from "@/components/team-follow-row";
import { Skeleton } from "@/components/ui/skeleton";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { searchTeams } from "@/lib/search-ranking";
import { popularTeams } from "@/lib/popular-teams";
import { followKey } from "@/lib/refs";
import type { ConferenceTeams, Team } from "@/lib/types";

export function AddTeamsSheet({
  open,
  onOpenChange,
  conferences,
  isLoading,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  conferences: ConferenceTeams[];
  isLoading: boolean;
}) {
  const [query, setQuery] = useState("");
  const { favorites } = useFavoritesContext();
  const trimmed = query.trim();

  const shown = useMemo(() => {
    if (trimmed.length === 0) return popularTeams(conferences);
    // No follow boost: rows toggle follows here, and a followed-first sort
    // would reorder the list under the user's finger.
    return searchTeams(trimmed, conferences);
  }, [trimmed, conferences]);

  const spansLeagues = new Set(shown.map((team) => team.league)).size > 1;

  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="flex max-h-[85vh] flex-col gap-0 overflow-hidden p-0 sm:max-w-lg">
        <DialogHeader className="border-b border-divider px-4 py-3">
          <DialogTitle className="type-section-header text-text-primary">
            Add teams
          </DialogTitle>
        </DialogHeader>
        <div className="border-b border-divider px-4 py-3">
          <SearchField
            value={query}
            onChange={setQuery}
            placeholder="Find a team"
            autoFocus
          />
        </div>
        <div className="min-h-0 flex-1 overflow-y-auto bg-bg-recessed p-2">
          {isLoading && conferences.length === 0 ? (
            <div className="flex flex-col gap-2">
              {[0, 1, 2, 3, 4].map((row) => (
                <Skeleton key={row} className="h-14 w-full rounded-[10px]" />
              ))}
            </div>
          ) : shown.length === 0 ? (
            <p className="px-4 py-16 text-center type-team-name text-text-secondary">
              {trimmed.length > 0
                ? `No teams match “${trimmed}”`
                : "No teams to show"}
            </p>
          ) : (
            <div className="flex flex-col gap-2">
              {/* Keyed on the follow key, never the bare id: UCLA and the
                  Seahawks are both team 26. */}
              {shown.map((team: Team) => (
                <div
                  key={followKey({ league: team.league, teamId: team.id })}
                  className="card-surface overflow-hidden"
                >
                  <TeamFollowRow
                    team={team}
                    leagueTag={spansLeagues ? team.league : undefined}
                  />
                </div>
              ))}
            </div>
          )}
        </div>
        <p className="border-t border-divider px-4 py-2 type-meta text-text-secondary">
          {favorites.length === 1
            ? "Following 1 team"
            : `Following ${favorites.length} teams`}
        </p>
      </DialogContent>
    </Dialog>
  );
}
