// Chronological scoring plays with quarter markers (iOS ScoringPlaysList):
// a narrow type/clock gutter, the play text, and the running score against
// the trailing edge.

import type { ScoringPlayItem } from "@/lib/types";
import { DetailCard } from "./detail-card";
import { quarterMarkerLabel } from "./game-status";

export function ScoringPlaysCard({ plays }: { plays: ScoringPlayItem[] }) {
  return (
    <DetailCard title="Scoring">
      <ul className="pb-2">
        {plays.map((play, index) => {
          const marker =
            index === 0 || play.quarter !== plays[index - 1].quarter;
          return (
            <li key={play.id}>
              {marker && (
                <p
                  className={`px-4 pb-1 type-meta text-text-secondary ${
                    index === 0 ? "" : "pt-2"
                  }`}
                >
                  {quarterMarkerLabel(play.quarter)}
                </p>
              )}
              <div className="flex items-start gap-3 px-4 py-[5px]">
                <div className="flex min-w-10 flex-col gap-0.5">
                  <span className="type-meta-em text-text-primary">
                    {play.typeAbbreviation ?? "–"}
                  </span>
                  {play.clock && (
                    <span className="whitespace-nowrap type-meta tnum text-text-secondary">
                      {play.clock}
                    </span>
                  )}
                </div>
                <p className="flex-1 type-meta text-text-primary">
                  {play.text}
                </p>
                {play.awayScore !== undefined &&
                  play.homeScore !== undefined && (
                    <span className="whitespace-nowrap type-meta tnum text-text-secondary">
                      {play.awayScore}–{play.homeScore}
                    </span>
                  )}
              </div>
            </li>
          );
        })}
      </ul>
    </DetailCard>
  );
}
