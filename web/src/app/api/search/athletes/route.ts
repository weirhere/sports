// The athlete half of search — a thin handler over ESPN's own search
// (iOS `AthleteSearchClient`, 2026-09-21).
//
// Behind a route rather than called from the browser for the reason every
// ESPN call here is: the app talks to ESPN server-side, where Next's fetch
// cache is the politeness throttle. The directory filter (FBS and FCS stay,
// Division II does not) and the team resolution happen in the browser,
// against the directory it has already loaded — see `lib/athlete-search`.

import { NextRequest, NextResponse } from "next/server";
import { searchAthletes } from "@/lib/espn";

/** A query longer than any name is not a search anyone typed. */
const MAX_QUERY_LENGTH = 100;

export async function GET(request: NextRequest) {
  const query = (new URL(request.url).searchParams.get("q") ?? "").trim();
  // A cleared field costs no request and keeps no stale people.
  if (query.length === 0) return NextResponse.json({ athletes: [] });
  if (query.length > MAX_QUERY_LENGTH) {
    return NextResponse.json({ error: "Query too long" }, { status: 400 });
  }

  try {
    const athletes = await searchAthletes(query);
    return NextResponse.json({ athletes });
  } catch (err) {
    console.error("Athlete search error:", err);
    return NextResponse.json(
      { error: "Failed to search athletes" },
      { status: 502 }
    );
  }
}
