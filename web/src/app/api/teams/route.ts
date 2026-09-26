import { NextRequest, NextResponse } from "next/server";
import { conferenceTeams } from "@/lib/espn";
import { divisionGroupId } from "@/lib/conferences";
import { hasCollegeDivisions, parseLeague } from "@/lib/leagues";

// A league's directory moves on realignment timescales; one fetch a day is
// plenty (the provider's own fetch cache matches).
export const revalidate = 86400;

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const league = parseLeague(searchParams.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }
  // College football's second division, on request. The default stays FBS,
  // which is what every browse surface lists; search asks for FCS as well,
  // because its athlete filter keeps FCS players (iOS, 2026-09-21) and a
  // directory that doesn't know Harvard would drop them.
  const division = searchParams.get("division");
  if (division !== null && (division !== "fcs" || !hasCollegeDivisions(league))) {
    return NextResponse.json({ error: "Unknown division" }, { status: 400 });
  }

  try {
    const conferences = await conferenceTeams(
      league,
      division === "fcs" ? { group: divisionGroupId("FCS") } : undefined
    );
    return NextResponse.json({ conferences });
  } catch (err) {
    console.error("Teams fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch teams" },
      { status: 502 }
    );
  }
}
