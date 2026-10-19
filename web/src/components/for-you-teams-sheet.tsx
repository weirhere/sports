"use client";

// Which followed teams get a section on For you — the web twin of iOS
// `ForYouTeamsSheet` (2026-10-19), opened from the filter button on the News
// masthead. FotMob's For you filter sheet, as `docs/news.md` N12 described
// and declined; taken on Andy's call, superseding N12.
//
// A checklist of every followed team in the Teams tab's order — A–Z by
// school, since follows carry no order of their own — and a row to the
// Teams tab, where the follows themselves are managed. Unchecking keeps the
// follow and takes the team off this one page.

import Link from "next/link";
import { ChevronRight, Circle, CircleCheck } from "lucide-react";
import { Dialog, DialogContent, DialogTitle } from "@/components/ui/dialog";
import { TeamLogo } from "@/components/team-logo";
import { teamFullName } from "@/lib/team-name";
import { followKey } from "@/lib/refs";
import type { Team } from "@/lib/types";

export function ForYouTeamsSheet({
  open,
  onOpenChange,
  teams,
  isShown,
  onSetShown,
}: {
  open: boolean;
  onOpenChange: (open: boolean) => void;
  /** The followed teams, already in the Teams tab's order. */
  teams: Team[];
  isShown: (key: string) => boolean;
  onSetShown: (key: string, shown: boolean) => void;
}) {
  return (
    <Dialog open={open} onOpenChange={onOpenChange}>
      <DialogContent className="max-h-[80vh] overflow-y-auto p-0">
        <div className="sticky top-0 z-10 flex items-center justify-between border-b border-divider bg-bg-primary px-4 py-3">
          <DialogTitle className="type-section-header text-text-primary">For you</DialogTitle>
          <button
            type="button"
            onClick={() => onOpenChange(false)}
            className="type-chip-em rounded-full bg-bg-elevated px-3 py-1.5 text-text-primary transition-colors hover:bg-divider"
          >
            Done
          </button>
        </div>

        <div className="flex flex-col gap-2 px-4 py-4">
          {teams.length === 0 ? (
            <>
              <section className="card-surface px-4 py-3 type-team-name text-text-secondary">
                No teams yet
              </section>
              <p className="px-1 type-meta text-text-secondary">
                Follow teams and their stories get a section on For you.
              </p>
            </>
          ) : (
            <>
              <section className="card-surface">
                {teams.map((team, index) => {
                  const key = followKey({ league: team.league, teamId: team.id });
                  const shown = isShown(key);
                  const name = teamFullName(team);
                  return (
                    <div key={key}>
                      {index > 0 && <div className="ml-4 border-t border-divider" />}
                      <button
                        type="button"
                        role="checkbox"
                        aria-checked={shown}
                        aria-label={name}
                        onClick={() => onSetShown(key, !shown)}
                        className="flex w-full items-center gap-3 px-4 py-3 text-left transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none"
                      >
                        <TeamLogo team={team} teamName="" size="sm" className="h-6 w-6 shrink-0" />
                        <span className="min-w-0 flex-1 type-team-name text-text-primary">{name}</span>
                        {/* Ink only: a filled check against an empty ring
                            reads without the green FotMob spends on it. */}
                        {shown ? (
                          <CircleCheck
                            aria-hidden="true"
                            className="h-6 w-6 shrink-0 fill-text-primary text-bg-card"
                          />
                        ) : (
                          <Circle aria-hidden="true" className="h-6 w-6 shrink-0 text-text-secondary" />
                        )}
                      </button>
                    </div>
                  );
                })}
              </section>
              <p className="px-1 type-meta text-text-secondary">
                Unchecked teams keep their follow and leave this page.
              </p>
            </>
          )}

          <section className="card-surface mt-2">
            <Link
              href="/teams"
              onClick={() => onOpenChange(false)}
              className="flex items-center justify-between px-4 py-3 type-team-name text-text-primary transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none"
            >
              Manage teams
              <ChevronRight aria-hidden="true" className="h-4 w-4 text-text-secondary" />
            </Link>
          </section>
        </div>
      </DialogContent>
    </Dialog>
  );
}
