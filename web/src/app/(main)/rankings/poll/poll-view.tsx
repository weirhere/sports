"use client";

// The poll list (iOS PollScreen + RankRow): chip picker, headline, then 25
// rank rows in one card. Movement spends the color budget's third
// exception — green up, red down — with arrows so color is never the only
// signal.

import { useEffect, useState } from "react";
import Link from "next/link";
import { pollLabel } from "@/lib/polls";
import type { Poll, RankedTeam } from "@/lib/types";
import { TeamLogo } from "@/components/team-logo";
import { cn } from "@/lib/utils";

/** Mirrors the iOS `UIStateStore.pollChoice` preference. */
const POLL_CHOICE_KEY = "statside.ui.pollChoice";

export function PollView({ polls }: { polls: Poll[] }) {
  const [choice, setChoice] = useState<string>("ap");

  useEffect(() => {
    // localStorage is read post-hydration on purpose: a lazy initializer
    // would diverge from the server-rendered markup.
    try {
      const stored = localStorage.getItem(POLL_CHOICE_KEY);
      if (stored) {
        // eslint-disable-next-line react-hooks/set-state-in-effect
        setChoice(stored);
      }
    } catch {
      // Ignore localStorage errors
    }
  }, []);

  const selected = polls.find((poll) => poll.type === choice) ?? polls[0];

  if (!selected) {
    return (
      <p className="py-20 text-center type-team-name text-text-secondary">
        No rankings right now
      </p>
    );
  }

  const select = (poll: Poll) => {
    const type = poll.type ?? "ap";
    setChoice(type);
    try {
      localStorage.setItem(POLL_CHOICE_KEY, type);
    } catch {
      // Ignore localStorage errors
    }
  };

  return (
    <div className="flex flex-col gap-2">
      {polls.length > 1 && (
        <div className="flex items-center gap-2 px-1 py-1">
          {polls.map((poll) => {
            const isSelected = poll.id === selected.id;
            return (
              <button
                key={poll.id}
                type="button"
                onClick={() => select(poll)}
                aria-pressed={isSelected}
                className={cn(
                  "rounded-full px-4 py-1.5 type-chip transition-colors",
                  isSelected
                    ? "bg-text-primary text-bg-primary"
                    : "text-text-secondary hover:text-text-primary"
                )}
              >
                {pollLabel(poll)}
              </button>
            );
          })}
        </div>
      )}
      <div className="py-1 card-surface">
        {selected.headline && (
          <p className="px-4 py-2 type-meta text-text-secondary">
            {selected.headline}
          </p>
        )}
        {/* Keyed by team, not rank — polls can tie two teams at one rank
            (the 2026 Coaches preseason had two No. 14s). */}
        {selected.ranks.map((ranked, index) => (
          <div key={ranked.team.id}>
            {index > 0 && <div className="ml-4 border-t border-divider" />}
            <RankRow ranked={ranked} />
          </div>
        ))}
      </div>
    </div>
  );
}

/**
 * One ranked team: rank, logo, name, first-place votes, record, movement.
 * One link, one spoken sentence: "4. Georgia, 11 and 1, up 2".
 */
function RankRow({ ranked }: { ranked: RankedTeam }) {
  // ESPN sends previous 0 (or nothing) for a team unranked last week.
  const isNew = ranked.previousRank == null || ranked.previousRank === 0;
  const delta = isNew ? 0 : ranked.previousRank! - ranked.rank;

  return (
    <Link
      href={`/team/${ranked.team.id}`}
      aria-label={accessibilitySummary(ranked, isNew, delta)}
      className="flex items-center gap-2 px-4 py-[7px] transition-colors hover:bg-bg-header"
    >
      {/* Rank gutter — right-aligned so 1 and 25 share an edge. */}
      <span className="w-6 shrink-0 text-right type-row-name-em tnum text-text-primary">
        {ranked.rank}
      </span>
      <TeamLogo
        espnId={ranked.team.espnId}
        teamName={ranked.team.school}
        size="sm"
        className="shrink-0"
      />
      <span className="truncate type-row-name text-text-primary">
        {ranked.team.school}
      </span>
      {ranked.firstPlaceVotes != null && ranked.firstPlaceVotes > 0 && (
        <span className="shrink-0 type-row-meta text-text-secondary">
          ({ranked.firstPlaceVotes})
        </span>
      )}
      <span className="ml-auto shrink-0 type-row-meta text-text-secondary">
        {ranked.record}
      </span>
      <span className="w-9 shrink-0 text-right">
        {isNew ? (
          <span className="type-row-meta-medium text-text-secondary">NEW</span>
        ) : delta > 0 ? (
          <span className="type-row-meta-medium text-rank-up">▲ {delta}</span>
        ) : delta < 0 ? (
          <span className="type-row-meta-medium text-rank-down">
            ▼ {-delta}
          </span>
        ) : (
          <span className="type-row-meta text-text-secondary">–</span>
        )}
      </span>
    </Link>
  );
}

function accessibilitySummary(
  ranked: RankedTeam,
  isNew: boolean,
  delta: number
): string {
  const parts = [`${ranked.rank}. ${ranked.team.school}`];
  if (ranked.firstPlaceVotes != null && ranked.firstPlaceVotes > 0) {
    parts.push(`${ranked.firstPlaceVotes} first-place votes`);
  }
  if (ranked.record) {
    parts.push(ranked.record.replaceAll("-", " and "));
  }
  if (isNew) {
    parts.push("newly ranked");
  } else if (delta > 0) {
    parts.push(`up ${delta}`);
  } else if (delta < 0) {
    parts.push(`down ${-delta}`);
  } else {
    parts.push("no change");
  }
  return parts.join(", ");
}
