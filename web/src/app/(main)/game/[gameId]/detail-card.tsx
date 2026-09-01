// One content card (iOS GameDetailScreen.card + Theme/CardHeader): an
// optional bordered header — title over a full-bleed hairline, trailing
// context in meta type — then the section's own rows.

interface DetailCardProps {
  title?: string;
  /** Trailing context in meta type — e.g. Team stats' "UGA · USC" legend. */
  subtitle?: string;
  children: React.ReactNode;
}

export function DetailCard({ title, subtitle, children }: DetailCardProps) {
  return (
    <section className="card-surface pb-1">
      {title && (
        <div className="border-b border-divider">
          <div className="flex items-center gap-2 p-3">
            <h2 className="type-section-header text-text-primary">{title}</h2>
            {subtitle && (
              <span className="ml-auto type-meta text-text-secondary">
                {subtitle}
              </span>
            )}
          </div>
        </div>
      )}
      <div className="pt-1">{children}</div>
    </section>
  );
}
