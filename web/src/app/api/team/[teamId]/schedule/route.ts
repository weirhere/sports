// One team's current season, for the browser — what search asks for when a
// query matched a team (iOS `TeamScheduleSearchStore`, 2026-09-21).
//
// The team page renders its schedule server-side and needs no route; search
// is a client view whose corpus grows as you type, so it needs one. The
// provider's hour-long fetch cache applies, and it is shared across every
// visitor, so a popular team's season is one upstream round per hour however
// many people search for it.

import { NextRequest, NextResponse } from "next/server";
import { EspnApiError, teamSchedule } from "@/lib/espn";
import { parseLeague } from "@/lib/leagues";

export async function GET(
  request: NextRequest,
  { params }: { params: Promise<{ teamId: string }> }
) {
  const { teamId } = await params;
  // Team ids collide across leagues (5 is UAB and the Browns), so the league
  // rides the request rather than being guessed from the id.
  const league = parseLeague(new URL(request.url).searchParams.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }
  if (!/^\d+$/.test(teamId)) {
    return NextResponse.json({ error: "Unknown team" }, { status: 400 });
  }

  try {
    const schedule = await teamSchedule(league, teamId);
    // The games alone: search draws rows, not a team page, and the rest of
    // the payload would be bytes the browser throws away.
    return NextResponse.json({ games: schedule.games });
  } catch (err) {
    if (err instanceof EspnApiError && err.status < 500) {
      return NextResponse.json({ error: "Team not found" }, { status: 404 });
    }
    console.error("Team schedule fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch the schedule" },
      { status: 502 }
    );
  }
}
