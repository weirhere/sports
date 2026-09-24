import { NextResponse } from "next/server";
import { apnsConfigFromEnv, createChannel, deleteChannel } from "@/lib/apns";
import { gameSummary } from "@/lib/espn/provider";
import { kvFromEnv } from "@/lib/kv";
import { LEAGUES, type League } from "@/lib/leagues";
import {
  acceptsChannel,
  channelKey,
  ensureChannel,
  kvChannelStore,
  staticChannelDirectory,
} from "@/lib/live-activity-channels";
import { activityPhase } from "@/lib/live-activity-state";

/**
 * Which broadcast channel a game is on, making one if it has none yet.
 *
 * The iOS client asks this once, when a card is started, and subscribes the
 * activity to whatever comes back (`RemoteChannelDirectory`). A 404 is a
 * normal answer, not an error: it means this game gets no channel, and the
 * client starts a local-only card rather than none.
 *
 * **Channels on demand (2026-09-24, E12 blocker 3).** With a store and an
 * APNs key configured, the first pin of a game creates its channel at
 * Apple and records it; every later pin reads it back. Before creating
 * anything the game id is checked against ESPN, so an unauthenticated
 * caller can't mint channels for ids that don't exist (Apple caps an app
 * at 10,000). Without a store it falls back to the hand-made
 * `APNS_CHANNELS` map, which is how it worked before.
 *
 * Holds no user data and takes none — the request carries a game id and a
 * league and nothing else, which is what keeps this path 3 rather than
 * path 2.
 */
export const dynamic = "force-dynamic";

function isLeague(value: string): value is League {
  return (LEAGUES as readonly string[]).includes(value);
}

function found(channelId: string) {
  return NextResponse.json(
    { channelId },
    // A channel id is stable for the life of a game, and the client asks
    // once per card — but a short cache keeps a Saturday's worth of starts
    // off the function.
    { headers: { "cache-control": "public, max-age=300" } },
  );
}

function none(reason: string) {
  // Never cached: "no channel yet" stops being true the moment one is made.
  return NextResponse.json(
    { error: reason },
    { status: 404, headers: { "cache-control": "no-store" } },
  );
}

export async function GET(request: Request) {
  const url = new URL(request.url);
  const gameId = url.searchParams.get("gameId");
  const league = url.searchParams.get("league");
  if (!gameId || !league || !/^\d{1,12}$/.test(gameId) || !isLeague(league)) {
    return NextResponse.json({ error: "gameId and league are required" }, { status: 400 });
  }

  const kv = kvFromEnv();
  const config = apnsConfigFromEnv();
  if (!kv || !config) {
    const channelId = await staticChannelDirectory().channelId(gameId, league);
    return channelId ? found(channelId) : none("no channel for this game");
  }

  const store = kvChannelStore(kv);
  const key = channelKey(gameId, league);
  const existing = await store.get(key);
  if (existing) return found(existing.channelId);

  let game;
  try {
    game = (await gameSummary(league, gameId)).game;
  } catch {
    return none("unknown game");
  }
  if (!acceptsChannel(game, activityPhase(game.status), Math.floor(Date.now() / 1000))) {
    return none("game not eligible for a channel");
  }

  const channelId = await ensureChannel({
    store,
    key,
    kickoff: game.scheduledAt,
    create: async () => (await createChannel(config)).channelId ?? null,
    destroy: async (id) => {
      await deleteChannel(config, id);
    },
  });
  return channelId ? found(channelId) : none("channel could not be created");
}
