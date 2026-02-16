import { NextRequest, NextResponse } from "next/server";
import { getStandings } from "@/lib/mock";

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
    const standings = getStandings(conferenceId);
    return NextResponse.json(standings);
  } catch {
    return NextResponse.json(
      { error: "Failed to fetch standings" },
      { status: 500 }
    );
  }
}
