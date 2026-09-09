import { NextRequest, NextResponse } from "next/server";
import { conferenceTeams } from "@/lib/espn";
import { parseLeague } from "@/lib/leagues";

// A league's directory moves on realignment timescales; one fetch a day is
// plenty (the provider's own fetch cache matches).
export const revalidate = 86400;

export async function GET(request: NextRequest) {
  const league = parseLeague(new URL(request.url).searchParams.get("league"));
  if (!league) {
    return NextResponse.json({ error: "Unknown league" }, { status: 400 });
  }

  try {
    const conferences = await conferenceTeams(league);
    return NextResponse.json({ conferences });
  } catch (err) {
    console.error("Teams fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch teams" },
      { status: 502 }
    );
  }
}
