// The poll itself, one level under the Rankings hub (iOS PollScreen): AP by
// default, Coaches and CFP as chips — CFP only when ESPN returned it.

import { rankings } from "@/lib/espn/provider";
import { displayedPolls } from "@/lib/polls";
import type { Poll } from "@/lib/types";
import { PollView } from "./poll-view";

export const metadata = {
  title: "Top 25 | College Football Hub",
};

export default async function PollPage() {
  let polls: Poll[] = [];
  try {
    polls = displayedPolls(await rankings());
  } catch {
    // A rankings miss renders the empty state, never a crash.
  }
  return <PollView polls={polls} />;
}
