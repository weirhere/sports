/**
 * gameId → APNs broadcast channel id.
 *
 * This is the *only* state path 3 has, and its shape is the whole reason
 * path 3 was chosen over path 2: it holds channel ids for live games, so
 * what it stores is a function of the slate rather than of the install
 * base. The moment this maps devices, it has become path 2.
 *
 * **First cut deliberately reads a static map from the environment**, for
 * two reasons. Channel *creation* lives on APNs' management host at
 * :2196 — a non-standard port that a serverless runtime can't be assumed
 * to reach — and Apple's Push Notification Console creates channels by
 * hand, so out-of-band creation is a supported workflow rather than a
 * workaround. And a durable store (KV, a database) is another
 * infrastructure decision, which CLAUDE.md says to have a conversation
 * about rather than smuggle in under a feature that already had one.
 *
 * What that costs: channels have to be provisioned ahead of a slate rather
 * than on demand. See `docs/live-activities-service.md`.
 */

export interface ChannelDirectory {
  channelId(gameId: string, league: string): Promise<string | null>;
}

/** `APNS_CHANNELS` is a JSON object keyed `"<league>:<gameId>"`. Malformed
 *  JSON resolves to an empty directory rather than throwing: a bad env var
 *  should degrade to "no channel", not take the route down. */
export function parseChannelMap(raw: string | undefined): Record<string, string> {
  if (!raw) return {};
  try {
    const parsed: unknown = JSON.parse(raw);
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) return {};
    const out: Record<string, string> = {};
    for (const [key, value] of Object.entries(parsed as Record<string, unknown>)) {
      if (typeof value === "string" && value) out[key] = value;
    }
    return out;
  } catch {
    return {};
  }
}

export function channelKey(gameId: string, league: string): string {
  return `${league}:${gameId}`;
}

export function staticChannelDirectory(
  env: NodeJS.ProcessEnv = process.env,
): ChannelDirectory {
  const map = parseChannelMap(env.APNS_CHANNELS);
  return {
    async channelId(gameId, league) {
      return map[channelKey(gameId, league)] ?? null;
    },
  };
}
