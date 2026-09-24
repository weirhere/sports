/**
 * The smallest possible Redis client: Upstash's REST API over `fetch`.
 *
 * Here for one job — the Live Activity service's gameId → channel map
 * (2026-09-24, E12 blocker 3). Upstash through the Vercel Marketplace sets
 * `KV_REST_API_URL` / `KV_REST_API_TOKEN` (or the `UPSTASH_REDIS_REST_*`
 * pair, depending on how the integration was added); either works.
 *
 * No package: a command is a JSON array POSTed to the base URL and the
 * answer is `{ result }` or `{ error }`, which is less code than a
 * dependency conversation. Keeps CLAUDE.md's zero-dependency line intact
 * for the same reason `apns.ts` signs its own JWTs.
 */

export interface Kv {
  command<T = unknown>(args: (string | number)[]): Promise<T>;
}

export class KvError extends Error {}

export function kvFromEnv(
  env: NodeJS.ProcessEnv = process.env,
  fetchImpl: typeof fetch = fetch,
): Kv | null {
  const url = env.KV_REST_API_URL ?? env.UPSTASH_REDIS_REST_URL;
  const token = env.KV_REST_API_TOKEN ?? env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) return null;
  return {
    async command<T>(args: (string | number)[]): Promise<T> {
      const response = await fetchImpl(url, {
        method: "POST",
        headers: { authorization: `Bearer ${token}`, "content-type": "application/json" },
        body: JSON.stringify(args),
        cache: "no-store",
      });
      const payload = (await response.json().catch(() => ({}))) as {
        result?: T;
        error?: string;
      };
      if (!response.ok || payload.error) {
        throw new KvError(`kv ${String(args[0])} failed: ${payload.error ?? response.status}`);
      }
      return payload.result as T;
    },
  };
}
