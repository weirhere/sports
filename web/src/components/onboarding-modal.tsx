"use client";

// The first-launch moment — the web twin of the iOS `OnboardingScreen`:
// pick your teams so Saturday starts personal. Entirely skippable, and it
// never comes back either way (the Teams tab does the same job later).
// Rows toggle follows with the WHOLE row (a bigger first-launch target),
// so the list must never reorder under the pointer — conference rosters
// are fixed and the search filter skips the follow boost.

import { useMemo, useState } from "react";
import { Star } from "lucide-react";
import {
  Dialog,
  DialogContent,
  DialogDescription,
  DialogHeader,
  DialogTitle,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { TeamLogo } from "@/components/team-logo";
import { ConferenceLogo } from "@/components/theme/conference-logo";
import { SearchField } from "@/components/search-field";
import { Skeleton } from "@/components/ui/skeleton";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { useFirstVisit } from "@/lib/hooks/use-first-visit";
import { useTeamDirectory } from "@/lib/hooks/use-team-directory";
import { searchTeams } from "@/lib/search-ranking";
import { conferenceLogoUrl } from "@/lib/conferences";
import { cn } from "@/lib/utils";
import type { ConferenceTeams, Team } from "@/lib/types";

export function OnboardingModal() {
  const { isFirstVisit, isLoaded: visitLoaded, markVisited } = useFirstVisit();
  const { favorites, isLoaded: favLoaded } = useFavoritesContext();
  const { conferences, isLoading, error, retry } = useTeamDirectory();
  const [query, setQuery] = useState("");

  const isOpen = visitLoaded && favLoaded && isFirstVisit;

  // No follow boost: rows toggle follows, and a followed-first sort would
  // reorder the list under the user's finger.
  const results = useMemo(
    () => searchTeams(query, conferences),
    [query, conferences]
  );

  if (!isOpen) return null;

  const trimmed = query.trim();

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && markVisited()}>
      <DialogContent
        showCloseButton={false}
        className="flex h-dvh max-h-dvh w-full max-w-full flex-col gap-0 rounded-none p-0 sm:h-[85vh] sm:max-h-[85vh] sm:max-w-lg sm:rounded-lg"
      >
        <DialogHeader className="px-4 pb-2 pt-4">
          <DialogTitle>Pick your teams</DialogTitle>
          <DialogDescription>
            Your teams lead the Scores screen every Saturday. You can always
            change them from the Teams tab.
          </DialogDescription>
        </DialogHeader>

        <div className="px-4 pb-3">
          <SearchField
            value={query}
            onChange={setQuery}
            placeholder="Find a team"
          />
        </div>

        <div className="flex-1 space-y-2 overflow-y-auto px-4 pb-4">
          {conferences.length === 0 ? (
            isLoading ? (
              <OnboardingSkeleton />
            ) : (
              <div className="flex flex-col items-center gap-3 py-16">
                <p className="type-team-name text-text-secondary">
                  {error ?? "No teams"}
                </p>
                <button
                  type="button"
                  onClick={retry}
                  className="type-team-name-em text-text-primary"
                >
                  Retry
                </button>
              </div>
            )
          ) : trimmed.length === 0 ? (
            conferences.map((conference) => (
              <ConferenceSection
                key={conference.id ?? conference.name}
                conference={conference}
              />
            ))
          ) : results.length > 0 ? (
            <div className="card-surface py-1">
              {results.map((team) => (
                <OnboardingTeamRow key={team.id} team={team} />
              ))}
            </div>
          ) : (
            <p className="py-16 text-center type-team-name text-text-secondary">
              No teams match &ldquo;{trimmed}&rdquo;
            </p>
          )}
        </div>

        <div className="flex items-center justify-between gap-3 border-t border-divider px-4 py-3 pb-[max(0.75rem,env(safe-area-inset-bottom))]">
          <Button variant="ghost" onClick={markVisited}>
            Skip
          </Button>
          <Button onClick={markVisited} disabled={favorites.length === 0}>
            Done
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}

function ConferenceSection({ conference }: { conference: ConferenceTeams }) {
  const numericId = conference.id !== undefined ? Number(conference.id) : NaN;
  return (
    <section className="card-surface pb-1">
      <h2 className="flex items-center gap-2 bg-bg-header px-4 py-2.5 type-section-header text-text-primary">
        <ConferenceLogo
          src={Number.isFinite(numericId) ? conferenceLogoUrl(numericId) : null}
          name=""
        />
        {conference.name}
      </h2>
      {conference.teams.map((team) => (
        <OnboardingTeamRow key={team.id} team={team} />
      ))}
    </section>
  );
}

/** The whole row is the follow toggle; nothing here navigates. */
function OnboardingTeamRow({ team }: { team: Team }) {
  const { isFavorite, toggleFavorite } = useFavoritesContext();
  const followed = isFavorite(team.id);
  const fullName = [team.school, team.name].filter(Boolean).join(" ");

  return (
    <button
      type="button"
      onClick={() => toggleFavorite(team.id)}
      aria-label={fullName}
      aria-pressed={followed}
      className="flex w-full items-center gap-3 px-4 py-[7px] text-left transition-colors hover:bg-bg-header"
    >
      <TeamLogo espnId={team.espnId} teamName="" size="sm" />
      <span
        className={cn(
          "truncate text-text-primary",
          followed ? "type-row-name-em" : "type-row-name"
        )}
      >
        {team.school}
      </span>
      {team.name && (
        <span className="truncate type-row-name text-text-secondary">
          {team.name}
        </span>
      )}
      <Star
        aria-hidden="true"
        className={cn(
          "ml-auto h-4 w-4 shrink-0 text-text-primary",
          followed && "fill-current"
        )}
      />
    </button>
  );
}

function OnboardingSkeleton() {
  return (
    <div className="space-y-2" aria-hidden="true">
      {Array.from({ length: 3 }).map((_, i) => (
        <div key={i} className="card-surface">
          <div className="bg-bg-header px-4 py-2.5">
            <Skeleton className="h-4 w-24" />
          </div>
          <div className="space-y-2 px-4 py-3">
            <Skeleton className="h-5 w-3/4" />
            <Skeleton className="h-5 w-2/3" />
          </div>
        </div>
      ))}
    </div>
  );
}
