// The Trophies tab's card: one row per trophy, the count on the right and the
// years beneath it — the web twin of iOS `TeamTrophiesCard`.
//
// The table language the team-page cards already speak: a `CardHeader` over
// hairline-divided rows, the count in tabular figures so a column of them lines
// up. What it deliberately is **not** is a grid of trophy artwork — the app has
// no such assets, the color budget would not pay for them, and the answer a fan
// wants here is a number and a list of years.
//
// Rows are **not links**, for `RosterRow`'s reason and one of their own: there
// is no trophy page anywhere in the app, and a row spanning four seasons has no
// single game to open — a chevron would promise one.

import { Fragment } from "react";
import { CardHeader } from "@/components/card-header";
import { Skeleton } from "@/components/ui/skeleton";
import {
  coverageFloor,
  trophyGroupTitle,
  type TrophyCase,
  type TrophyGroup,
} from "@/lib/trophies";

/** "2025, 2022 and 2017" — read as a list, not as a run of digits. */
function spokenList(values: string[]): string {
  if (values.length <= 1) return values[0] ?? "";
  return `${values.slice(0, -1).join(", ")} and ${values[values.length - 1]}`;
}

/**
 * Said out loud, never implied. A shelf that only knows the seasons ESPN can
 * reach has to say so — an eighteen-time champion showing six with no caption
 * is the omission the whole feature is built against. Undefined when every row
 * is all-time, which is the only case where silence is the truth.
 */
export function trophyFootnote(shelf: TrophyCase): string | undefined {
  const floor = coverageFloor(shelf);
  if (floor === undefined) return undefined;
  const scoped = shelf.groups.filter((group) => group.coverage.kind !== "allTime");
  if (scoped.length === shelf.groups.length) return `Since ${floor}`;
  return `${spokenList(scoped.map(trophyGroupTitle))} since ${floor}`;
}

export function TeamTrophiesCard({ trophyCase }: { trophyCase: TrophyCase }) {
  const footnote = trophyFootnote(trophyCase);

  return (
    <section className="card-surface pb-1">
      <CardHeader title="Trophies" />
      {trophyCase.groups.map((group, index) => (
        <Fragment key={group.id}>
          {index > 0 && <div className="ml-4 border-t border-divider" />}
          <TrophyRow group={group} />
        </Fragment>
      ))}
      {footnote && (
        <p
          // Spoken once, at the foot of the card, rather than repeated into
          // every row's sentence.
          aria-label={`Coverage: ${footnote}`}
          className="px-4 pt-1 pb-2 type-row-meta text-text-secondary"
        >
          {footnote}
        </p>
      )}
    </section>
  );
}

/** "3 SEC Championships, 2025, 2022 and 2017" — the count leads, because it is
 * the answer, and the years are read as a list. */
function trophySentence(group: TrophyGroup): string {
  return `${group.years.length} ${trophyGroupTitle(group)}, ${spokenList(
    group.years.map(String)
  )}`;
}

function TrophyRow({ group }: { group: TrophyGroup }) {
  return (
    <div
      // One sentence rather than three fragments, the GameRow rule. `img` is
      // what makes a non-interactive block announce its label and collapse
      // its children into it.
      role="img"
      aria-label={trophySentence(group)}
      className="flex items-baseline gap-2 px-4 py-2"
    >
      <div className="flex min-w-0 flex-col gap-0.5">
        <span className="type-row-name-em text-text-primary">
          {trophyGroupTitle(group)}
        </span>
        <span className="type-row-meta tnum text-text-secondary">
          {group.years.join(", ")}
        </span>
      </div>
      <span className="ml-auto shrink-0 type-row-name-em tnum text-text-primary">
        {group.years.length}
      </span>
    </div>
  );
}

/** The tab's waiting state: a dozen seasons is a dozen pairs of requests, and
 * the shelf is only built once every one of them has landed — a case that
 * fills in season by season shows a count that changes under the reader. */
export function TeamTrophiesCardSkeleton() {
  return (
    <section className="card-surface pb-1">
      <CardHeader title="Trophies" />
      {[0, 1].map((row) => (
        <div key={row} className="flex items-center gap-2 px-4 py-2">
          <div className="flex flex-col gap-1.5">
            <Skeleton className="h-3.5 w-36" />
            <Skeleton className="h-2.5 w-24" />
          </div>
          <Skeleton className="ml-auto h-3.5 w-4" />
        </div>
      ))}
    </section>
  );
}
