import { NextRequest, NextResponse } from "next/server";
import { getGamesByWeek, MOCK_GAMES } from "@/lib/mock";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const weekParam = searchParams.get("week");
  const week = weekParam ? Number(weekParam) : 8; // Default to week 8 for mock

  try {
    const games = getGamesByWeek(week);
    return NextResponse.json({ games, week });
  } catch {
    return NextResponse.json(
      { error: "Failed to fetch schedule" },
      { status: 500 }
    );
  }
}
