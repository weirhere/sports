"use client";

import { useState, useMemo } from "react";
import {
  Dialog,
  DialogContent,
  DialogHeader,
  DialogTitle,
  DialogDescription,
} from "@/components/ui/dialog";
import { Button } from "@/components/ui/button";
import { TeamLogo } from "@/components/team-logo";
import { cn } from "@/lib/utils";
import { MOCK_TEAMS } from "@/lib/mock/teams";
import { FBS_CONFERENCES } from "@/config/conferences";
import { useFavoritesContext } from "@/components/providers/favorites-provider";
import { useFirstVisit } from "@/lib/hooks/use-first-visit";
import { Star, Check } from "lucide-react";

export function OnboardingModal() {
  const { isFirstVisit, isLoaded: visitLoaded, markVisited } = useFirstVisit();
  const { favorites, toggleFavorite, isLoaded: favLoaded } = useFavoritesContext();
  const [selectedConference, setSelectedConference] = useState<string | null>(null);

  const isOpen = visitLoaded && favLoaded && isFirstVisit;

  const teams = useMemo(() => {
    if (!selectedConference) return MOCK_TEAMS.filter((t) => t.division === "FBS");
    return MOCK_TEAMS.filter(
      (t) => t.conferenceId === selectedConference && t.division === "FBS"
    );
  }, [selectedConference]);

  if (!isOpen) return null;

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && markVisited()}>
      <DialogContent className="max-h-[85vh] max-w-lg overflow-hidden">
        <DialogHeader>
          <DialogTitle className="flex items-center gap-2">
            <Star className="h-5 w-5 text-yellow-500" />
            Pick Your Teams
          </DialogTitle>
          <DialogDescription>
            Select your favorite teams to see their games highlighted at the top
            of the scoreboard.
          </DialogDescription>
        </DialogHeader>

        {/* Conference filter */}
        <div className="flex flex-wrap gap-1.5">
          <button
            type="button"
            onClick={() => setSelectedConference(null)}
            className={cn(
              "rounded-full px-3 py-1 text-xs font-medium transition-colors",
              !selectedConference
                ? "bg-primary text-primary-foreground"
                : "bg-muted text-muted-foreground hover:text-foreground"
            )}
          >
            All
          </button>
          {FBS_CONFERENCES.map((conf) => (
            <button
              key={conf.id}
              type="button"
              onClick={() => setSelectedConference(conf.id)}
              className={cn(
                "rounded-full px-3 py-1 text-xs font-medium transition-colors",
                selectedConference === conf.id
                  ? "bg-primary text-primary-foreground"
                  : "bg-muted text-muted-foreground hover:text-foreground"
              )}
            >
              {conf.shortName}
            </button>
          ))}
        </div>

        {/* Team grid */}
        <div className="mt-2 max-h-[45vh] overflow-y-auto pr-1">
          <div className="grid grid-cols-2 gap-2">
            {teams.map((team) => {
              const selected = favorites.includes(team.id);
              return (
                <button
                  key={team.id}
                  type="button"
                  onClick={() => toggleFavorite(team.id)}
                  className={cn(
                    "flex items-center gap-2.5 rounded-lg border p-2.5 text-left transition-all",
                    selected
                      ? "border-yellow-500/50 bg-yellow-500/10"
                      : "border-border hover:bg-accent/50"
                  )}
                >
                  <TeamLogo
                    espnId={team.espnId}
                    teamName={team.school}
                    size="sm"
                  />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-medium">
                      {team.school}
                    </p>
                    <p className="truncate text-xs text-muted-foreground">
                      {team.conferenceName}
                    </p>
                  </div>
                  {selected && (
                    <Check className="h-4 w-4 shrink-0 text-yellow-500" />
                  )}
                </button>
              );
            })}
          </div>
        </div>

        {/* Footer */}
        <div className="flex items-center justify-between pt-2">
          <p className="text-xs text-muted-foreground">
            {favorites.length} team{favorites.length !== 1 ? "s" : ""} selected
          </p>
          <Button onClick={markVisited}>
            {favorites.length > 0 ? "Done" : "Skip for now"}
          </Button>
        </div>
      </DialogContent>
    </Dialog>
  );
}
