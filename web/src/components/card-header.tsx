// The bordered header row the entity-page cards share ("Next game",
// "Schedule", "Record", "Week 1"): title over a full-bleed hairline — the
// iOS `CardHeader` (Theme/CardHeader.swift) table-header treatment.

interface CardHeaderProps {
  title: string;
  /** Trailing context in meta type — e.g. a column legend. */
  subtitle?: string;
}

export function CardHeader({ title, subtitle }: CardHeaderProps) {
  return (
    <div>
      <div className="flex items-center justify-between gap-2 p-3">
        <h3 className="type-section-header text-text-primary">{title}</h3>
        {subtitle && (
          <span className="type-meta text-text-secondary">{subtitle}</span>
        )}
      </div>
      <div className="border-t border-divider" />
    </div>
  );
}
