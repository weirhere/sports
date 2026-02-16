import { NextResponse } from "next/server";
import { getRankings as getMockRankings } from "@/lib/mock";
import { getRankings as getEspnRankings } from "@/lib/espn";
import { useEspnApi } from "@/lib/data-source";

export async function GET() {
  try {
    if (useEspnApi()) {
      const rankings = await getEspnRankings();
      return NextResponse.json(rankings);
    }

    const rankings = getMockRankings();
    return NextResponse.json(rankings);
  } catch (err) {
    console.error("Rankings fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch rankings" },
      { status: 500 }
    );
  }
}
