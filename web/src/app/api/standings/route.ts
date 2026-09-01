import { NextRequest, NextResponse } from "next/server";
import { getStandings as getMockStandings } from "@/lib/mock";
import { getStandings as getEspnStandings } from "@/lib/espn";
import { useEspnApi } from "@/lib/data-source";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const conferenceId = searchParams.get("conferenceId");

  try {
    if (!conferenceId) {
      return NextResponse.json(
        { error: "conferenceId is required" },
        { status: 400 }
      );
    }

    if (useEspnApi()) {
      const standings = await getEspnStandings({ conferenceId });
      return NextResponse.json(standings);
    }

    const standings = getMockStandings(conferenceId);
    return NextResponse.json(standings);
  } catch (err) {
    console.error("Standings fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch standings" },
      { status: 500 }
    );
  }
}
