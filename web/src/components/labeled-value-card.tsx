// A card of label/value rows — iOS `LabeledValueCard`, and the treatment the
// Record card already gives a team, so a fact about a player, a coach and a
// team read in one language. The player's Profile card and every Stats tab
// card are this, and so are the coach page's Record and Profile (E27).

import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { CardHeader } from "@/components/card-header";

export interface LabeledValueRow {
  label: string;
  value: string;
  /** What a screen reader says in place of `label`, where the visible one
   *  is an abbreviation. */
  spokenLabel?: string;
  /** Where the row goes — a pro's college, when the school has a page
   *  (2026-11-02). Absent leaves the row as it was. */
  href?: string;
}

interface LabeledValueCardProps {
  title: string;
  subtitle?: string;
  rows: LabeledValueRow[];
}

export function LabeledValueCard({ title, subtitle, rows }: LabeledValueCardProps) {
  return (
    <section className="card-surface pb-1">
      <CardHeader title={title} subtitle={subtitle} />
      {rows.map((row, index) => {
        const label = `${row.spokenLabel ?? row.label} ${row.value}`;
        const content = (
          <>
            <span
              aria-hidden="true"
              className="min-w-0 truncate type-row-name text-text-secondary"
            >
              {row.label}
            </span>
            <span className="flex shrink-0 items-center gap-2">
              <span
                aria-hidden="true"
                className="tnum type-row-name-em text-text-primary"
              >
                {row.value}
              </span>
              {row.href && (
                // The coach career row's chevron, so a row that goes
                // somewhere says so the way the others do.
                <ChevronRight aria-hidden="true" className="h-3 w-3 shrink-0 text-text-secondary" />
              )}
            </span>
          </>
        );
        const rowClass = "flex items-center justify-between gap-2 px-4 py-3";
        return (
          <div key={`${row.label}-${index}`}>
            {index > 0 && <div className="ml-4 border-t border-divider" />}
            {row.href ? (
              <Link
                href={row.href}
                aria-label={label}
                className={`${rowClass} transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none`}
              >
                {content}
              </Link>
            ) : (
              <div className={rowClass} aria-label={label}>
                {content}
              </div>
            )}
          </div>
        );
      })}
    </section>
  );
}
