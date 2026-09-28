// One team's season, for the browser — what search asks for when a query
// matched a team (iOS `TeamScheduleSearchStore`, 2026-09-21), and, with a
// `year`, the coach page's Games tab (E27, 2026-09-27).
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
  const search = new URL(request.url).searchParams;
  const league = parseLeague(search.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }
  if (!/^\d+$/.test(teamId)) {
    return NextResponse.json({ error: "Unknown team" }, { status: 400 });
  }

  // A season on our opening-year axis, for the coach page's Games tab
  // (E27): the seasons a coach held the job are past ones. Absent, it's the
  // current season, which is all search ever wants.
  const yearParam = search.get("year");
  if (yearParam !== null && !/^\d{4}$/.test(yearParam)) {
    return NextResponse.json({ error: "Unknown season" }, { status: 400 });
  }
  const year = yearParam === null ? undefined : Number(yearParam);

  try {
    const schedule = await teamSchedule(league, teamId, year);
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
