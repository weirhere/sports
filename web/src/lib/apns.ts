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
import { connect, constants } from "node:http2";

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

/** Broadcast sends go to :443. Channel *management* — creating and deleting
 *  the channel a game broadcasts on — is on its own host, and on a
 *  different port per environment: **:2195 in the sandbox, :2196 in
 *  production** (Apple, "Sending channel management requests to APNs",
 *  checked 2026-09-24; the service doc had said :2196 for both). */
const MANAGEMENT_HOSTS: Record<ApnsEnvironment, string> = {
  production: "https://api-manage-broadcast.push.apple.com:2196",
  sandbox: "https://api-manage-broadcast.sandbox.push.apple.com:2195",
};

export function channelsUrl(config: ApnsConfig): string {
  return `${MANAGEMENT_HOSTS[config.environment]}/1/apps/${config.bundleId}/channels`;
}

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
  /**
   * UNIX seconds. **Required, and required by APNs rather than by us.**
   *
   * A broadcast with no `apns-expiration` is treated as expiration 0, and
   * APNs rejects that with `BadExpirationDate` — which is exactly what the
   * first broadcast that ever reached Apple came back with (2026-09-15).
   * It was optional here, the route never set it, and nothing could catch
   * that because the type allowed the omission.
   *
   * So it is required now: the compiler is the thing that stops this from
   * regressing, since a live APNs round trip is not something CI can do.
   * A channel storing the most recent message caps storage at 8 hours, so
   * anything beyond that is silently the cap.
   */
  expiration: number;
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
  headers["apns-expiration"] = String(request.expiration);
  return headers;
}

/**
 * How a request actually reaches APNs.
 *
 * **APNs speaks HTTP/2 and nothing else, and Node's `fetch` speaks HTTP/1.1
 * and nothing else.** `fetch` against `api.push.apple.com` does not fail
 * politely — undici hands the HTTP/2 binary frames to its HTTP/1.1 parser
 * and throws `TypeError: fetch failed` with an `HTTPParserError` cause,
 * which Vercel then renders as a 500 with an empty body.
 *
 * Found in production logs 2026-09-15, the first time this code ever ran
 * against Apple. The wire format above was verified against Apple's spec on
 * 2026-09-10 and is fine; the transport under it could never have worked,
 * and nothing caught that because nothing had run it.
 *
 * `node:http2` is built in, so this still adds no dependency — which is the
 * same reason the JWT is signed with `node:crypto` rather than a JWT
 * package.
 */
export interface ApnsTransportResult {
  status: number;
  apnsId?: string;
  /** Set only by a channel create: Apple returns the new id as a header. */
  channelId?: string;
  /** Raw body. APNs sends JSON on failure and nothing on success. */
  body: string;
}

export type ApnsTransport = (
  url: string,
  headers: Record<string, string>,
  body: string,
  /** POST for sends and channel creation, DELETE for removing a channel. */
  method?: "POST" | "DELETE",
) => Promise<ApnsTransportResult>;

/** Seconds before an unanswered session is abandoned. Well inside the
 *  route's own `maxDuration = 60`, so a hung APNs connection costs one
 *  game's update rather than the whole tick. */
const REQUEST_TIMEOUT_MS = 10_000;

export const http2Transport: ApnsTransport = (url, headers, body, method = "POST") =>
  new Promise((resolve, reject) => {
    const target = new URL(url);
    const session = connect(target.origin);
    let settled = false;
    const fail = (error: unknown) => {
      if (settled) return;
      settled = true;
      session.close();
      reject(error instanceof Error ? error : new Error(String(error)));
    };

    session.on("error", fail);
    session.setTimeout(REQUEST_TIMEOUT_MS, () =>
      fail(new Error(`apns session timed out after ${REQUEST_TIMEOUT_MS}ms`)),
    );

    // Pseudo-headers are the method and path; everything else is ours, and
    // HTTP/2 requires header names be lowercase — `broadcastHeaders`
    // already writes them that way.
    const request = session.request({
      ...headers,
      [constants.HTTP2_HEADER_METHOD]: method,
      [constants.HTTP2_HEADER_PATH]: target.pathname,
    });

    let status = 0;
    let apnsId: string | undefined;
    let channelId: string | undefined;
    let data = "";

    request.on("response", (responseHeaders) => {
      status = Number(responseHeaders[constants.HTTP2_HEADER_STATUS] ?? 0);
      const id = responseHeaders["apns-id"];
      apnsId = typeof id === "string" ? id : undefined;
      const channel = responseHeaders["apns-channel-id"];
      channelId = typeof channel === "string" ? channel : undefined;
    });
    request.setEncoding("utf8");
    request.on("data", (chunk: string) => {
      data += chunk;
    });
    request.on("error", fail);
    request.on("end", () => {
      if (settled) return;
      settled = true;
      session.close();
      resolve({ status, apnsId, channelId, body: data });
    });
    request.end(body);
  });

/**
 * Why a send blew up before it ever reached Apple.
 *
 * Signing happens inside `broadcastHeaders`, and `createPrivateKey` throws
 * on a PEM it can't decode — so a misconfigured key used to surface as an
 * unhandled exception, which Vercel renders as **HTTP 500 with an empty
 * body**. No reason, no league, nothing.
 *
 * A flattened PEM is one culprit: `apnsConfigFromEnv`'s `\n` restoration
 * only helps when the newlines survived *as the two characters* `\` and
 * `n`. Newlines stripped outright are not recoverable that way.
 */
function sendFailureReason(error: unknown): string {
  const message = error instanceof Error ? error.message : String(error);
  if (/DECODER|asn1|unsupported|PEM|private key/i.test(message)) {
    return `apns-key-unreadable: ${message} — check APNS_PRIVATE_KEY still has its BEGIN/END lines and its line breaks`;
  }
  return `apns-send-threw: ${message}`;
}

export async function sendBroadcast(
  config: ApnsConfig,
  request: BroadcastRequest,
  transport: ApnsTransport = http2Transport,
  now = Date.now(),
): Promise<BroadcastResult> {
  let result: ApnsTransportResult;
  try {
    result = await transport(
      broadcastUrl(config),
      broadcastHeaders(config, request, now),
      JSON.stringify(broadcastPayload(request, now)),
    );
  } catch (error) {
    // Status 0: nothing was ever sent, so there is no HTTP status to
    // report. The route files it under `failed` with a reason instead of
    // dying, which is what the empty-bodied 500 taught us to want.
    return { ok: false, status: 0, reason: sendFailureReason(error) };
  }

  if (result.status >= 200 && result.status < 300) {
    return { ok: true, status: result.status, apnsId: result.apnsId };
  }
  let reason: string | undefined;
  try {
    reason = (JSON.parse(result.body) as { reason?: string }).reason;
  } catch {
    reason = undefined;
  }
  return { ok: false, status: result.status, apnsId: result.apnsId, reason };
}

function failureReason(body: string): string | undefined {
  try {
    return (JSON.parse(body) as { reason?: string }).reason;
  } catch {
    return undefined;
  }
}

export interface ChannelResult {
  ok: boolean;
  status: number;
  /** The new channel's base64 id, on a successful create. */
  channelId?: string;
  reason?: string;
}

/**
 * Creates one broadcast channel for Live Activities.
 *
 * `message-storage-policy: 1` keeps the most recent message, so a phone
 * that was off when the final went out still receives the `end` when it
 * comes back — which is what `FINAL_EXPIRY_SECONDS` on the broadcast route
 * is sized against. Apple answers 201 with the id in `apns-channel-id`.
 */
export async function createChannel(
  config: ApnsConfig,
  transport: ApnsTransport = http2Transport,
  now = Date.now(),
): Promise<ChannelResult> {
  let result: ApnsTransportResult;
  try {
    result = await transport(
      channelsUrl(config),
      {
        authorization: `bearer ${providerToken(config, now)}`,
        "content-type": "application/json",
      },
      JSON.stringify({ "message-storage-policy": 1, "push-type": "LiveActivity" }),
      "POST",
    );
  } catch (error) {
    return { ok: false, status: 0, reason: sendFailureReason(error) };
  }
  if (result.status === 201 && result.channelId) {
    return { ok: true, status: result.status, channelId: result.channelId };
  }
  return {
    ok: false,
    status: result.status,
    reason: failureReason(result.body) ?? (result.status === 201 ? "no-channel-id-header" : undefined),
  };
}

/** Deletes a channel. Apple answers 204. Apps are capped at 10,000
 *  channels per environment, so every channel made has to be unmade. */
export async function deleteChannel(
  config: ApnsConfig,
  channelId: string,
  transport: ApnsTransport = http2Transport,
  now = Date.now(),
): Promise<ChannelResult> {
  let result: ApnsTransportResult;
  try {
    result = await transport(
      channelsUrl(config),
      {
        authorization: `bearer ${providerToken(config, now)}`,
        "apns-channel-id": channelId,
      },
      "",
      "DELETE",
    );
  } catch (error) {
    return { ok: false, status: 0, reason: sendFailureReason(error) };
  }
  if (result.status >= 200 && result.status < 300) return { ok: true, status: result.status };
  return { ok: false, status: result.status, reason: failureReason(result.body) };
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
