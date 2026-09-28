// The Profile tab — iOS `CoachProfilePane`: the career in big numbers, then
// the record lines and the bio, each skipping whatever ESPN didn't send.

import { CardHeader } from "@/components/card-header";
import { LabeledValueCard, type LabeledValueRow } from "@/components/labeled-value-card";
import {
  coachAge,
  RECORD_TITLES,
  recordSummary,
  winPercentText,
  type CoachProfile,
} from "@/lib/coach";
import { seasonLabel, type League } from "@/lib/leagues";

interface Tile {
  label: string;
  spokenLabel: string;
  value: string;
}

export function CoachProfilePane({ league, profile }: { league: League; profile: CoachProfile }) {
  const tiles = headlineTiles(profile);
  const recordRows: LabeledValueRow[] = profile.records.map((record) => ({
    label: RECORD_TITLES[record.kind],
    value: [recordSummary(record), winPercentText(record)].filter(Boolean).join(" · "),
  }));

  // The role leads, as a player's position does in theirs: ESPN only lists
  // head coaches, so it's the one row every coach has.
  const bioRows: LabeledValueRow[] = [{ label: "Position", value: "Head coach" }];
  const age = coachAge(profile.dateOfBirth);
  if (age !== undefined) bioRows.push({ label: "Age", value: String(age) });
  if (profile.birthPlace) bioRows.push({ label: "Born", value: profile.birthPlace });
  if (profile.college) bioRows.push({ label: "College", value: profile.college });
  const first = profile.seasons[profile.seasons.length - 1]?.year;
  if (first !== undefined) bioRows.push({ label: "First season", value: seasonLabel(league, first) });

  return (
    <>
      {tiles.length > 0 && (
        <section className="card-surface">
          <CardHeader title="Head coaching career" />
          <dl className="flex items-start px-2 py-3">
            {tiles.map((tile) => (
              <div key={tile.label} className="flex min-w-0 flex-1 flex-col items-center gap-0.5">
                <dt className="sr-only">{tile.spokenLabel}</dt>
                <dd className="truncate tnum type-score text-text-primary">{tile.value}</dd>
                <dd aria-hidden="true" className="truncate type-row-meta text-text-secondary">
                  {tile.label}
                </dd>
              </div>
            ))}
          </dl>
        </section>
      )}
      {recordRows.length > 0 && <LabeledValueCard title="Record" rows={recordRows} />}
      {bioRows.length > 0 && <LabeledValueCard title="Profile" rows={bioRows} />}
    </>
  );
}

/** Seasons, W-L, win % and — where ESPN splits it out — the playoffs. */
function headlineTiles(profile: CoachProfile): Tile[] {
  const total = profile.records.find((r) => r.kind === "total") ?? profile.records[0];
  if (!total) return [];
  const tiles: Tile[] = [];
  if (profile.seasons.length > 0) {
    const seasons = new Set(profile.seasons.map((s) => s.year)).size;
    tiles.push({ label: "SEASONS", spokenLabel: "Seasons", value: String(seasons) });
  }
  tiles.push({ label: "W-L", spokenLabel: "Record", value: recordSummary(total) });
  const pct = winPercentText(total);
  if (pct) tiles.push({ label: "PCT", spokenLabel: "Win percentage", value: pct });
  const post = profile.records.find((r) => r.kind === "postseason");
  if (post) tiles.push({ label: "PLAYOFFS", spokenLabel: "Playoff record", value: recordSummary(post) });
  return tiles;
}
