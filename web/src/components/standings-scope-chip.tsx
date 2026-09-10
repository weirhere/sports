"use client";

// The Standings pane's scope control: whole league, conference, or division
// (iOS `StandingsScopeChip`, 2026-09-06). A menu capsule — the team
// filter's twin, sitting in the same control strip one tab apart and
// shaping its pane the same way.
//
// It always names its own value, because every scope is a real answer and
// none of them is the absence of one. The **fill is the narrowing signal**:
// at the page's own default the chip sits quiet, and any narrower view
// wears the ink so a table of 16 is never mistaken for a table of 32.

import {
  isNarrower,
  scopeTitle,
  type StandingsScope,
} from "@/lib/standings-scope";
import { MenuChip } from "./menu-chip";

export function StandingsScopeChip({
  scopes,
  selection,
  base,
  onSelect,
}: {
  scopes: readonly StandingsScope[];
  selection: StandingsScope;
  /** The page's own default — what "not narrowed" means here. */
  base: StandingsScope;
  onSelect: (scope: StandingsScope) => void;
}) {
  if (scopes.length < 2) return null;
  return (
    <MenuChip
      label={scopeTitle(selection)}
      isActive={isNarrower(selection, base)}
      ariaLabel={`Standings, ${scopeTitle(selection)}`}
      options={scopes.map((scope) => ({
        id: scope,
        label: scopeTitle(scope),
        onSelect: () => onSelect(scope),
      }))}
    />
  );
}
