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
  /** Trailing control beside the identity — the follow pill. */
  trailing?: ReactNode;
  /** The tab row, rendered inside the card-color surface. */
  children?: ReactNode;
}

/**
 * The entity pages' hero — iOS TeamPage/ConferencePage's card-color header
 * (bgCard, FotMob-style: "all headers should have the same color as the
 * cards"). The negative margins cancel the app shell's `px-4 pt-3` so the
 * surface runs edge-to-edge against the nav bar; the page content below
 * stays on bg-recessed.
 */
export function HeroHeader({
  logo,
  title,
  rank,
  subtitle,
  trailing,
  children,
}: HeroHeaderProps) {
  return (
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
        {trailing && <div className="shrink-0">{trailing}</div>}
      </div>
      {children && <div className="mt-1">{children}</div>}
    </header>
  );
}
