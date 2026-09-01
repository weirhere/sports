import { NextResponse } from "next/server";
import { fbsConferences } from "@/lib/espn";

// The FBS directory moves on realignment timescales; one fetch a day is
// plenty (the provider's own fetch cache matches).
export const revalidate = 86400;

export async function GET() {
  try {
    const conferences = await fbsConferences();
    return NextResponse.json({ conferences });
  } catch (err) {
    console.error("Teams fetch error:", err);
    return NextResponse.json(
      { error: "Failed to fetch teams" },
      { status: 502 }
    );
  }
}
