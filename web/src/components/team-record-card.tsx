// The Overview tab's record breakdown — iOS `TeamRecordCard`: conference
// and overall W-L as two quiet metric rows. Strings come straight from the
// standings payload (or the schedule's derived record for past seasons) —
// never recomputed here.

import { CardHeader } from "@/components/card-header";

interface TeamRecordCardProps {
  /** Nil hides the row — past seasons and no-conference teams show overall only. */
  conferenceRecord?: string;
  overallRecord?: string;
}

/**
 * Preseason gate: the card says something once the OVERALL line does — a
 * September team legitimately sits 0-0 in conference while its overall
 * record already talks.
 */
export function teamRecordCardHasContent(
  conferenceRecord: string | undefined,
  overallRecord: string | undefined
): boolean {
  return overallRecord !== undefined && overallRecord !== "0-0";
}

function Row({ label, value }: { label: string; value: string }) {
  return (
    <div
      className="flex items-center justify-between gap-2 px-4 py-3"
      aria-label={`${label} record ${value.replaceAll("-", " and ")}`}
    >
      <span aria-hidden="true" className="type-row-name text-text-secondary">
        {label}
      </span>
      <span
        aria-hidden="true"
        className="tnum type-row-name-em text-text-primary"
      >
        {value}
      </span>
    </div>
  );
}

export function TeamRecordCard({
  conferenceRecord,
  overallRecord,
}: TeamRecordCardProps) {
  return (
    <section className="card-surface">
      <CardHeader title="Record" />
      {conferenceRecord !== undefined && (
        <>
          <Row label="Conference" value={conferenceRecord} />
          {overallRecord !== undefined && (
            <div className="ml-4 border-t border-divider" />
          )}
        </>
      )}
      {overallRecord !== undefined && (
        <Row label="Overall" value={overallRecord} />
      )}
    </section>
  );
}
