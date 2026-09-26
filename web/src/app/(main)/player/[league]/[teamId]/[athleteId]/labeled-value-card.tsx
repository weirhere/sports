// A card of label/value rows — iOS `LabeledValueCard`, and the treatment the
// Record card already gives a team, so a fact about a player and the same
// fact about a team read in one language. The Profile card and every Stats
// tab card are this.

import { CardHeader } from "@/components/card-header";

export interface LabeledValueRow {
  label: string;
  value: string;
  /** What a screen reader says in place of `label`, where the visible one
   *  is an abbreviation. */
  spokenLabel?: string;
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
      {rows.map((row, index) => (
        <div key={`${row.label}-${index}`}>
          {index > 0 && <div className="ml-4 border-t border-divider" />}
          <div
            className="flex items-center justify-between gap-2 px-4 py-3"
            aria-label={`${row.spokenLabel ?? row.label} ${row.value}`}
          >
            <span
              aria-hidden="true"
              className="min-w-0 truncate type-row-name text-text-secondary"
            >
              {row.label}
            </span>
            <span
              aria-hidden="true"
              className="shrink-0 tnum type-row-name-em text-text-primary"
            >
              {row.value}
            </span>
          </div>
        </div>
      ))}
    </section>
  );
}
