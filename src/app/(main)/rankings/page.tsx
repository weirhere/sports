"use client";

import { useEffect, useState } from "react";
import Link from "next/link";
import { getRankings } from "@/lib/api";
import { TeamLogo } from "@/components/team-logo";
import { Tabs, TabsList, TabsTrigger } from "@/components/ui/tabs";
import { cn } from "@/lib/utils";
import { useSwipe } from "@/lib/hooks/use-swipe";
import type { PollType, RankingsData, RankedTeam } from "@/lib/types";

const POLL_ORDER: PollType[] = ["cfp", "ap", "coaches"];
const POLL_LABELS: Record<PollType, string> = {
  cfp: "CFB Playoff",
  ap: "AP Poll",
  coaches: "Coaches'",
};

export default function RankingsPage() {
  const [polls, setPolls] = useState<RankingsData[]>([]);
  const [selectedPoll, setSelectedPoll] = useState<PollType>("ap");
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    getRankings()
      .then((data) => {
        setPolls(data);
      })
      .catch(console.error)
      .finally(() => setLoading(false));
  }, []);

  const activePoll = polls.find((p) => p.type === selectedPoll);
  const teams: RankedTeam[] = activePoll?.teams ?? [];

  // Determine which polls are available from the data
  const availablePolls = POLL_ORDER.filter((type) =>
    polls.some((p) => p.type === type)
  );

  const pollList = availablePolls.length > 0 ? availablePolls : POLL_ORDER;
  const currentPollIndex = pollList.indexOf(selectedPoll);

  // Swipe left/right to change polls
  const { ref: swipeRef } = useSwipe({
    onSwipeLeft: () => {
      if (currentPollIndex < pollList.length - 1) {
        setSelectedPoll(pollList[currentPollIndex + 1]);
      }
    },
    onSwipeRight: () => {
      if (currentPollIndex > 0) {
        setSelectedPoll(pollList[currentPollIndex - 1]);
      }
    },
    enabled: !loading,
  });

  return (
    <div className="space-y-3">
      {/* Segmented control */}
      <Tabs
        value={selectedPoll}
        onValueChange={(v) => setSelectedPoll(v as PollType)}
      >
        <TabsList className="w-full">
          {pollList.map(
            (type) => (
              <TabsTrigger key={type} value={type}>
                {POLL_LABELS[type]}
              </TabsTrigger>
            )
          )}
        </TabsList>
      </Tabs>

      {/* Rankings list */}
      <div ref={swipeRef}>
      {loading ? (
        <div className="flex items-center justify-center py-20">
          <div className="h-6 w-6 animate-spin rounded-full border-2 border-muted-foreground border-t-transparent" />
        </div>
      ) : teams.length === 0 ? (
        <div className="flex items-center justify-center py-20 text-sm text-muted-foreground">
          No rankings available for this poll.
        </div>
      ) : (
        <div className="overflow-hidden rounded-xl border bg-card shadow-card">
          {teams.map((rt, i) => {
            const moved =
              rt.previousRank != null ? rt.previousRank - rt.rank : null;

            return (
              <div key={rt.rank}>
                {i > 0 && <div className="mx-4 border-t" />}
                <Link
                  href={`/team/${rt.team.id}`}
                  className="flex items-center gap-3 px-4 py-3 transition-colors hover:bg-accent/30"
                >
                  {/* Rank */}
                  <span className="w-7 shrink-0 text-center font-score text-sm font-bold text-muted-foreground">
                    {rt.rank}
                  </span>

                  {/* Team */}
                  <TeamLogo
                    espnId={rt.team.espnId}
                    teamName={rt.team.school}
                    size="sm"
                  />
                  <div className="min-w-0 flex-1">
                    <p className="truncate text-sm font-semibold">
                      {rt.team.school}
                    </p>
                    <p className="text-xs text-muted-foreground">{rt.record}</p>
                  </div>

                  {/* Movement indicator */}
                  {moved != null && moved !== 0 && (
                    <span
                      className={cn(
                        "shrink-0 text-xs font-medium",
                        moved > 0 ? "text-green-600" : "text-live"
                      )}
                    >
                      {moved > 0 ? `▲${moved}` : `▼${Math.abs(moved)}`}
                    </span>
                  )}
                </Link>
              </div>
            );
          })}
        </div>
      )}
      </div>
    </div>
  );
}
