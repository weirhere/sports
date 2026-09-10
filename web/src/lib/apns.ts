/**
 * APNs broadcast pushes for Live Activities.
 *
 * Path 3 of `docs/live-activities.md`: one channel per *game*, one push to
 * that channel, Apple does the fan-out. The service therefore holds channel
 * ids for live games and no user data of any kind — the moment it needs a
 * per-device token store it has become path 2, which was rejected on
 * economics rather than on taste.
 *
 * Wire format verified 2026-09-10 against Apple's published broadcast
 * specification. Endpoints and headers are quoted in
 * `docs/live-activities-service.md` alongside what could NOT be verified
 * without a provider key.
 *
 * No new dependency: ES256 is signed with Node's built-in `crypto`, which
 * keeps CLAUDE.md's "no third-party packages without a conversation" intact
 * for a feature that already needed one conversation.
 */
import { createSign, createPrivateKey, type KeyObject } from "node:crypto";

export type ApnsEnvironment = "sandbox" | "production";

export interface ApnsConfig {
  /** The .p8 key's Key ID (10 chars). */
  keyId: string;
  /** The Apple Developer Team ID (10 chars). */
  teamId: string;
  /** Contents of the AuthKey_XXXX.p8, PEM. Never logged, never returned. */
  privateKeyPem: string;
  /** The app's bundle id, WITHOUT the `.push-type.liveactivity` suffix. */
  bundleId: string;
  environment: ApnsEnvironment;
}

const HOSTS: Record<ApnsEnvironment, string> = {
  production: "https://api.push.apple.com",
  sandbox: "https://api.sandbox.push.apple.com",
};

/** Broadcast sends go to :443, so an ordinary serverless runtime can reach
 *  them. Channel *creation* lives on the management host at :2196 and is
 *  deliberately out of scope here — see the service doc. */
export function broadcastUrl(config: ApnsConfig): string {
  return `${HOSTS[config.environment]}/4/broadcasts/apps/${config.bundleId}`;
}

function base64url(input: Buffer | string): string {
  return Buffer.from(input)
    .toString("base64")
    .replace(/\+/g, "-")
    .replace(/\//g, "_")
    .replace(/=+$/, "");
}

/**
 * DER (what Node emits) → JOSE raw r||s (what JWT requires).
 *
 * Worth spelling out because getting it wrong produces a token APNs
 * rejects with a generic error, which is a miserable thing to debug.
 */
function derToJose(der: Buffer): Buffer {
  let offset = 2;
  if (der[1] & 0x80) offset += der[1] & 0x7f;
  const readInt = () => {
    const length = der[offset + 1];
    let start = offset + 2;
    const end = start + length;
    while (der[start] === 0x00 && start < end - 1) start += 1;
    offset = end;
    const value = der.subarray(start, end);
    const padded = Buffer.alloc(32);
    value.copy(padded, 32 - value.length);
    return padded;
  };
  const r = readInt();
  const s = readInt();
  return Buffer.concat([r, s]);
}

let cachedKey: { pem: string; key: KeyObject } | null = null;

function privateKey(pem: string): KeyObject {
  if (cachedKey?.pem === pem) return cachedKey.key;
  const key = createPrivateKey(pem);
  cachedKey = { pem, key };
  return key;
}

interface TokenCache {
  token: string;
  issuedAt: number;
}
let cachedToken: TokenCache | null = null;

/**
 * A provider token, cached.
 *
 * APNs rejects tokens older than an hour and also rejects a provider that
 * mints them too often, so this refreshes on a comfortable interval rather
 * than per request — which matters when the poll loop fires once per live
 * game every 30 seconds.
 */
export function providerToken(config: ApnsConfig, now = Date.now()): string {
  const nowSeconds = Math.floor(now / 1000);
  if (cachedToken && nowSeconds - cachedToken.issuedAt < 45 * 60) {
    return cachedToken.token;
  }
  const header = base64url(JSON.stringify({ alg: "ES256", kid: config.keyId }));
  const claims = base64url(JSON.stringify({ iss: config.teamId, iat: nowSeconds }));
  const signer = createSign("SHA256");
  signer.update(`${header}.${claims}`);
  signer.end();
  const signature = base64url(derToJose(signer.sign(privateKey(config.privateKeyPem))));
  const token = `${header}.${claims}.${signature}`;
  cachedToken = { token, issuedAt: nowSeconds };
  return token;
}

/** Only for tests — the module-level caches are deliberate in production. */
export function resetApnsCaches(): void {
  cachedToken = null;
  cachedKey = null;
}

export type LiveActivityEvent = "update" | "end";

export interface BroadcastPayloadInput {
  /** Must match GameActivityAttributes.ContentState exactly, including its
   *  epoch-seconds `asOf` — a mismatch fails the update silently. */
  contentState: Record<string, unknown>;
  event: LiveActivityEvent;
  /** Seconds. When the card should stop claiming to be current. */
  staleDate?: number;
  /** Seconds. When the card should disappear entirely (`end` only). */
  dismissalDate?: number;
  timestamp?: number;
}

export function broadcastPayload(input: BroadcastPayloadInput, now = Date.now()) {
  const aps: Record<string, unknown> = {
    timestamp: input.timestamp ?? Math.floor(now / 1000),
    event: input.event,
    "content-state": input.contentState,
  };
  if (input.staleDate !== undefined) aps["stale-date"] = input.staleDate;
  if (input.dismissalDate !== undefined) aps["dismissal-date"] = input.dismissalDate;
  return { aps };
}

export interface BroadcastRequest extends BroadcastPayloadInput {
  channelId: string;
  /** 10 for a score change a fan is waiting on, 5 for routine ticks. */
  priority?: 5 | 10;
  expiration?: number;
}

export interface BroadcastResult {
  ok: boolean;
  status: number;
  /** APNs' own id, useful for chasing a delivery with Apple. */
  apnsId?: string;
  /** APNs' `reason` string on failure — the only useful diagnostic. */
  reason?: string;
}

export function broadcastHeaders(config: ApnsConfig, request: BroadcastRequest,
                                 now = Date.now()): Record<string, string> {
  const headers: Record<string, string> = {
    authorization: `bearer ${providerToken(config, now)}`,
    "apns-push-type": "liveactivity",
    "apns-topic": `${config.bundleId}.push-type.liveactivity`,
    "apns-channel-id": request.channelId,
    "apns-priority": String(request.priority ?? 10),
    "content-type": "application/json",
  };
  if (request.expiration !== undefined) {
    headers["apns-expiration"] = String(request.expiration);
  }
  return headers;
}

export async function sendBroadcast(
  config: ApnsConfig,
  request: BroadcastRequest,
  fetchImpl: typeof fetch = fetch,
  now = Date.now(),
): Promise<BroadcastResult> {
  const response = await fetchImpl(broadcastUrl(config), {
    method: "POST",
    headers: broadcastHeaders(config, request, now),
    body: JSON.stringify(broadcastPayload(request, now)),
  });
  const apnsId = response.headers.get("apns-id") ?? undefined;
  if (response.ok) return { ok: true, status: response.status, apnsId };
  let reason: string | undefined;
  try {
    reason = ((await response.json()) as { reason?: string }).reason;
  } catch {
    reason = undefined;
  }
  return { ok: false, status: response.status, apnsId, reason };
}

/** Reads config from the environment, or null when it isn't configured —
 *  which is the normal state until the provider key exists. */
export function apnsConfigFromEnv(
  env: NodeJS.ProcessEnv = process.env,
): ApnsConfig | null {
  const keyId = env.APNS_KEY_ID;
  const teamId = env.APNS_TEAM_ID;
  const privateKeyPem = env.APNS_PRIVATE_KEY?.replace(/\\n/g, "\n");
  const bundleId = env.APNS_BUNDLE_ID ?? "com.andyryanweir.sports";
  if (!keyId || !teamId || !privateKeyPem) return null;
  return {
    keyId,
    teamId,
    privateKeyPem,
    bundleId,
    environment: env.APNS_ENVIRONMENT === "production" ? "production" : "sandbox",
  };
}
