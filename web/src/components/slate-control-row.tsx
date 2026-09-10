"use client";

// The Games tab's control row, on every page that has one — iOS
// `SlateControlRow` (Features/Conference/SlateFilterChip.swift): two view
// toggles and a team dropdown, so a conference, a league and the Top 25 all
// shape their slate the same way.
//
// "Weeks" and "Date" are on/off, with no chevron, because there is no menu
// behind them and a chevron would promise one. They are two answers to one
// question — every game is in the list either way, under one heading or the
// other — so turning one on turns the other off, and turning the on one off
// leaves the season as one chronological card. **Team** is the only
// narrowing control, which is why it is the only dropdown and the only one
// that fills when it is doing something (iOS, 2026-09-05).
//
// A plain row, not a scroller: three short chips fit, and a horizontal
// scroller clips the chips' own shadows at its bounds.

import type { SlateGrouping } from "@/lib/conference-slate";
import type { Team } from "@/lib/types";
import { MenuChip } from "./menu-chip";
import { cn } from "@/lib/utils";

export function SlateToggleChip({
  title,
  isOn,
  hint,
  onToggle,
}: {
  title: string;
  isOn: boolean;
  hint?: string;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onToggle}
      aria-pressed={isOn}
      title={hint}
      className={cn(
        "inline-flex min-h-9 items-center whitespace-nowrap rounded-full px-3 py-1.5 type-chip transition-colors",
        isOn
          ? "bg-text-primary text-bg-primary"
          : "bg-bg-elevated text-text-primary hover:bg-divider"
      )}
    >
      {title}
    </button>
  );
}

export function SlateControlRow({
  grouping,
  onToggle,
  teams = [],
  teamSelection,
  onSelectTeam,
  hasWeeks = true,
}: {
  grouping: SlateGrouping;
  onToggle: (grouping: SlateGrouping) => void;
  /**
   * The filter's roster. Fewer than two names hides the chip — one team is
   * nothing to choose between, and none is nothing to choose from.
   */
  teams?: Team[];
  teamSelection?: string;
  onSelectTeam?: (teamId: string | undefined) => void;
  /**
   * Whether this league has weeks at all. The NBA and NHL ship `week: null`
   * on every event, so a Weeks toggle there would file a whole season under
   * one unheaded card.
   */
  hasWeeks?: boolean;
}) {
  const selected = teams.find((team) => team.id === teamSelection);
  return (
    <div className="flex flex-1 items-center gap-2">
      {hasWeeks && (
        <SlateToggleChip
          title="Weeks"
          isOn={grouping === "week"}
          hint="Groups the games by week"
          onToggle={() => onToggle("week")}
        />
      )}
      <SlateToggleChip
        title="Date"
        isOn={grouping === "day"}
        hint="Groups the games by day"
        onToggle={() => onToggle("day")}
      />
      {teams.length > 1 && (
        <MenuChip
          // At rest the label is the control's own name; selected, it fills
          // and names the team, so a narrowed slate is never a mystery
          // state (the labelled-chip rule, iOS 2026-08-29).
          label={selected?.school ?? "Team"}
          isActive={selected !== undefined}
          ariaLabel={
            selected ? `Team, ${selected.school}` : "Team, all teams"
          }
          options={[
            {
              id: "all",
              label: "All teams",
              onSelect: () => onSelectTeam?.(undefined),
            },
            ...teams.map((team) => ({
              id: team.id,
              label: team.school,
              onSelect: () => onSelectTeam?.(team.id),
            })),
          ]}
        />
      )}
    </div>
  );
}

/**
 * Turning a grouping on turns the other off — they're two answers to one
 * question. Turning the on one off leaves the slate ungrouped.
 */
export function toggledGrouping(
  current: SlateGrouping,
  value: SlateGrouping
): SlateGrouping {
  return current === value ? "none" : value;
}
