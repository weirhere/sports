import { NextResponse } from "next/server";
import { getAllRankings as getMockAllRankings } from "@/lib/mock";
import { getAllRankings as getEspnAllRankings } from "@/lib/espn";
import { useEspnApi } from "@/lib/data-source";

export async function GET() {
  try {
    if (useEspnApi()) {
      const rankings = await getEspnAllRankings();
      return NextResponse.json(rankings);
    }

    const rankings = getMockAllRankings();
    return NextResponse.json(rankings);
  } catch (err) {
    console.error("Rankings fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch rankings" },
      { status: 500 }
    );
  }
}
