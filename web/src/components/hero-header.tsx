import type { ReactNode } from "react";

interface HeroHeaderProps {
  /**
   * The entity mark in a 56px footprint. Teams pass a bare logo (no disc —
   * the iOS 2026-08-31 call); conferences pass their mark on the
   * `logo-backing` disc.
   */
  logo: ReactNode;
  title: string;
  /** Current AP rank — renders a quiet "#4" before the name when present. */
  rank?: number;
  /** Team: conference link. Conference: "N teams". */
  subtitle?: ReactNode;
  /**
   * The toolbar row's trailing controls — the season chip and the follow
   * pill. The season chip lives here rather than above the pane's first
   * card (iOS, 2026-09-05) because it scopes *every* tab, so it belongs
   * beside the page's identity rather than over one pane's cards.
   */
  trailing?: ReactNode;
  /** The tab row. Pinned. */
  tabs?: ReactNode;
  /**
   * The pane's own control strip — the scope chip, the team filter, the
   * week/date toggles. Pinned with the tabs, and it renders its gap
   * whether or not this tab has a chip: a collapsed strip would merge a
   * bg-card card into the bg-card tab row.
   */
  controls?: ReactNode;
}

/**
 * The entity pages' hero — iOS TeamPage/ConferencePage's card-color header
 * (bgCard, FotMob-style: "all headers should have the same color as the
 * cards").
 *
 * It splits in two (iOS, 2026-09-05). The **identity block** scrolls away;
 * the **tab row and its control strip pin** beneath the nav bar, because a
 * conference season is ~150 games and a team's is a full schedule —
 * switching tab, team or year shouldn't cost a scroll back to the top.
 *
 * The negative margins cancel the app shell's `px-4 pt-3` so the surface
 * runs edge-to-edge against the nav bar; the page content below stays on
 * bg-recessed.
 */
export function HeroHeader({
  logo,
  title,
  rank,
  subtitle,
  trailing,
  tabs,
  controls,
}: HeroHeaderProps) {
  return (
    // A fragment, not one wrapper: `position: sticky` only sticks inside
    // its **parent's** box, and a header that ends where the hero ends
    // gives the strip a few pixels of travel before it scrolls away with
    // it. As siblings, the strip's parent is the page's own container,
    // which spans the content it has to pin over.
    <>
      <header className="-mx-4 -mt-3 bg-bg-card px-4 pt-4">
        <div className="flex items-center gap-3">
          <span className="flex h-14 w-14 shrink-0 items-center justify-center">
            {logo}
          </span>
          <div className="min-w-0 flex-1">
            <h1 className="flex min-w-0 items-baseline gap-2 type-hero-title text-text-primary">
              {rank !== undefined && (
                <span className="shrink-0 tnum type-chip-em text-text-secondary">
                  #{rank}
                </span>
              )}
              <span className="truncate">{title}</span>
            </h1>
            {subtitle && <div className="mt-0.5">{subtitle}</div>}
          </div>
          {trailing && (
            <div className="flex shrink-0 items-center gap-2">{trailing}</div>
          )}
        </div>
      </header>

      {tabs && (
        // Pinned under the fixed nav bar. The tab row keeps the card
        // colour and the control strip sits on the recessed ground, so the
        // seam between them is the same one the page has everywhere else.
        <div className="sticky top-14 z-20 -mx-4 sm:top-16">
          <div className="bg-bg-card px-4">{tabs}</div>
          <div className="bg-bg-recessed px-4 pb-2 pt-2">
            {/* The gap renders whether or not this tab has a chip. */}
            <div className="flex min-h-9 items-center justify-end gap-2">
              {controls}
            </div>
          </div>
        </div>
      )}
    </>
  );
}
