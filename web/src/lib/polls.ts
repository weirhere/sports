// Poll selection shared by the Rankings hub and the Poll screen — the web
// twin of the iOS `RankingsScreen.pollTypes` / `PollScreen.label(for:)` pair.

import type { Poll } from "./types";

/**
 * The FBS polls we show, in picker order. ESPN's response also carries FCS
 * and DII/DIII polls — filtered out. CFP appears only when ESPN returns it
 * (from late October).
 */
export const FBS_POLL_TYPES = ["ap", "usa", "cfp"] as const;

/** The displayable polls in picker order — AP, Coaches, then CFP. */
export function displayedPolls(polls: Poll[]): Poll[] {
  return FBS_POLL_TYPES.map((type) =>
    polls.find((poll) => poll.type === type)
  ).filter((poll): poll is Poll => poll !== undefined);
}

export function pollLabel(poll: Poll): string {
  switch (poll.type) {
    case "ap":
      return "AP";
    case "usa":
      return "Coaches";
    case "cfp":
      return "CFP";
    default:
      return poll.shortName ?? poll.name;
  }
}
