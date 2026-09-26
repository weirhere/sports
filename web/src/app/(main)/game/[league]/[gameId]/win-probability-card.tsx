// Who's likely to win, as ESPN models it (iOS WinProbabilityCard): one row,
// FotMob's "Who will win?" card without the vote. Each side's crest with its
// percentage, centred in half of the row — away on the left, home on the
// right, as in the header. The favorite's number is the one in ink and
// weight; there's no draw column and no chart, and it spends no color.
//
// The caption naming the moment lives in the card header's trailing slot;
// `win-probability.ts` decides both it and the number.

import type { GameTeam, WinProbability } from "@/lib/types";
import { teamLogoSrc } from "@/components/team-logo";
import { cn } from "@/lib/utils";
import { DetailCard } from "./detail-card";
import { TeamMark } from "./team-mark";
import {
  winProbabilityReading,
  winProbabilitySplit,
  winProbabilitySpokenLabel,
} from "./win-probability";

interface WinProbabilityCardProps {
  probability: WinProbability;
  isFinal: boolean;
  awayTeam: GameTeam;
  homeTeam: GameTeam;
}

export function WinProbabilityCard({
  probability,
  isFinal,
  awayTeam,
  homeTeam,
}: WinProbabilityCardProps) {
  const reading = winProbabilityReading(probability, isFinal);
  const { away, home } = winProbabilitySplit(reading);

  return (
    <DetailCard title="Win probability" subtitle={reading.caption}>
      <p className="sr-only">
        {winProbabilitySpokenLabel(
          probability,
          isFinal,
          awayTeam.team.school,
          homeTeam.team.school
        )}
      </p>
      {/* Two equal halves, each group centred in its own (FotMob's layout),
          so the numbers sit apart from the card's edges. */}
      <div aria-hidden="true" className="flex px-4 py-3">
        <Side side={awayTeam} percent={away} leads={away > home} />
        <Side side={homeTeam} percent={home} leads={home > away} />
      </div>
    </DetailCard>
  );
}

function Side({
  side,
  percent,
  leads,
}: {
  side: GameTeam;
  percent: number;
  leads: boolean;
}) {
  return (
    <div className="flex flex-1 items-center justify-center gap-2">
      <TeamMark
        logoUrl={teamLogoSrc(side.team)}
        alt=""
        size={24}
        className="h-6 w-6 shrink-0 object-contain"
      />
      <span
        className={cn(
          leads
            ? "type-score text-text-primary"
            : "type-score-muted text-text-secondary"
        )}
      >
        {percent}%
      </span>
    </div>
  );
}
