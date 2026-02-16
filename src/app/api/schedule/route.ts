import { NextRequest, NextResponse } from "next/server";
import { getGamesByWeek } from "@/lib/mock";
import { getScoreboard } from "@/lib/espn";
import { useEspnApi } from "@/lib/data-source";

export async function GET(request: NextRequest) {
  const { searchParams } = new URL(request.url);
  const weekParam = searchParams.get("week");
  const week = weekParam ? Number(weekParam) : 8;

  try {
    if (useEspnApi()) {
      const result = await getScoreboard({ week });
      return NextResponse.json(result);
    }

    const games = getGamesByWeek(week);
    return NextResponse.json({ games, week });
  } catch (err) {
    console.error("Schedule fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch schedule" },
      { status: 500 }
    );
  }
}
