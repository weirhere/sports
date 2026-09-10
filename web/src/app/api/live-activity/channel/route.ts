import { NextResponse } from "next/server";
import { staticChannelDirectory } from "@/lib/live-activity-channels";

/**
 * Which broadcast channel a game is on.
 *
 * The iOS client asks this once, when a card is started, and subscribes the
 * activity to whatever comes back (`RemoteChannelDirectory`). A 404 is a
 * normal answer, not an error: it means this game has no channel, and the
 * client starts a local-only card rather than none.
 *
 * Holds no user data and takes none — the request carries a game id and a
 * league and nothing else, which is what keeps this path 3 rather than
 * path 2.
 */
export const dynamic = "force-dynamic";

export async function GET(request: Request) {
  const url = new URL(request.url);
  const gameId = url.searchParams.get("gameId");
  const league = url.searchParams.get("league");
  if (!gameId || !league) {
    return NextResponse.json({ error: "gameId and league are required" }, { status: 400 });
  }
  const channelId = await staticChannelDirectory().channelId(gameId, league);
  if (!channelId) {
    return NextResponse.json({ error: "no channel for this game" }, { status: 404 });
  }
  return NextResponse.json(
    { channelId },
    // A channel id is stable for the life of a game, and the client asks
    // once per card — but a short cache keeps a Saturday's worth of starts
    // off the function.
    { headers: { "cache-control": "public, max-age=300" } },
  );
}
