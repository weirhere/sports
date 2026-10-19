// What the Scores slate is narrowed to (Andy, 2026-10-19) — the web twin
// of iOS `SlateFocus`: the whole day, the live games, or the tight ones.
// One menu where Live and Tight were two pills; the two were already
// exclusive, so a three-way choice is what they were.

export type SlateFocus = "all" | "live" | "tight";

export const SLATE_FOCUSES: readonly SlateFocus[] = ["all", "live", "tight"];

export function slateFocusTitle(focus: SlateFocus): string {
  return focus === "all" ? "All games" : focus === "live" ? "Live" : "Tight";
}

/** The focus the two stored filters amount to. */
export function slateFocus(liveOnly: boolean, tightOnly: boolean): SlateFocus {
  return liveOnly ? "live" : tightOnly ? "tight" : "all";
}

/** The line under a choice in the menu, for the one row that needs it
 *  (Andy, 2026-10-19): Tight is a coined word; All games and Live say what
 *  they are. */
export function slateFocusDescription(focus: SlateFocus): string | undefined {
  return focus === "tight" ? "Live and close, late in the game, or an upset brewing" : undefined;
}
