// The Starters field's paint and ink, per league — the web twin of iOS
// `SurfaceColors.ink(for:)`, `.base(for:)` and `.heading(for:)` (2026-10-18).
// CSS values over the tokens in `globals.css`, which carry the light and
// dark pairs. Only the Roster tab's field, its heading strip and the chips
// on them may read these; the cards around them stay monochrome.

import type { League } from "@/lib/leagues";
import type { SurfaceInk } from "@/components/slate-control-row";

/**
 * Each surface's ink: off-white on turf, which is the same deep green in
 * both modes (dark names on it read muddy); fixed dark ink on ice, which
 * stays light in both; the page's text on maple, which deepens in dark mode
 * the way the page does.
 */
export function surfaceInk(league: League): SurfaceInk {
  switch (league) {
    case "cfb":
    case "nfl":
      return { text: "var(--surface-turf-ink)", counter: "var(--surface-ink)" };
    case "nhl":
      return { text: "var(--surface-ink)", counter: "var(--surface-chalk)" };
    case "nba":
      return { text: "var(--text-primary)", counter: "var(--bg-primary)" };
  }
}

/** The surface's unmarked paint. */
export function surfaceBase(league: League): string {
  switch (league) {
    case "cfb":
    case "nfl":
      return "var(--surface-turf)";
    case "nba":
      return "var(--surface-maple)";
    case "nhl":
      return "var(--surface-ice)";
  }
}

/** What the Starters section's title and chips sit on above the field: the
 *  same paint a shade deeper, so the strip reads as the section's heading
 *  and the field starts where the shade changes. */
export function surfaceHeading(league: League): string {
  switch (league) {
    case "cfb":
    case "nfl":
      return "var(--surface-turf-heading)";
    case "nba":
      return "var(--surface-paint)";
    case "nhl":
      return "var(--surface-ice-heading)";
  }
}

/** A translucent run of the ink — the disc ring, the chip row's hairline. */
export function inkAlpha(ink: string, alpha: number): string {
  return `color-mix(in srgb, ${ink} ${Math.round(alpha * 100)}%, transparent)`;
}
