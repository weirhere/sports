# The Live Activity broadcast service

**Status:** code written and unit-tested 2026-09-10; **never once run against
Apple.** It cannot be, until a provider key exists — see "What's blocked".

Path 3 of [`live-activities.md`](./live-activities.md), decided 2026-09-10:
one APNs broadcast channel per *game*, one push to that channel, Apple does
the fan-out. The service holds channel ids for live games and **no user data
of any kind**. The moment it needs a per-device token store it has become
path 2, which was rejected on economics rather than on taste.

## Where it lives

`web/`, on Vercel, rather than the Cloudflare Worker the original doc
sketched. Not a reversal of anything — the Worker was a sketch from E8, and
`web/` is already deployed, already the project's web home, and needs no new
account. The transport (`src/lib/apns.ts`) has no framework in it, so moving
it is an entrypoint change rather than a rewrite.

| Piece | File |
|---|---|
| APNs transport — JWT, headers, payload, send | `web/src/lib/apns.ts` |
| The wire contract — ESPN game → `content-state` | `web/src/lib/live-activity-state.ts` |
| gameId → channel id | `web/src/lib/live-activity-channels.ts` |
| Client asks which channel a game is on | `web/src/app/api/live-activity/channel/route.ts` |
| The poll loop | `web/src/app/api/live-activity/broadcast/route.ts` |
| Client side | `sports/Stores/LiveActivityChannels.swift` |

## The wire format, verified

Verified 2026-09-10 against Apple's published broadcast specification. Quoted
here because getting any one of these wrong produces a failure with no useful
error.

**Send** — `POST https://api.push.apple.com/4/broadcasts/apps/<bundleId>`
(sandbox: `api.sandbox.push.apple.com`), **port 443**, which is why an
ordinary serverless runtime can do this at all.

| Header | Value |
|---|---|
| `authorization` | `bearer <ES256 JWT>` |
| `apns-push-type` | `liveactivity` |
| `apns-topic` | `<bundleId>.push-type.liveactivity` |
| `apns-channel-id` | the channel |
| `apns-priority` | `10` for a score, `5` for a routine tick |

**The path takes the bare bundle id; the topic takes the suffix.** Swapping
them is the classic 400, and there's a test pinning it.

```json
{ "aps": { "timestamp": 1705560370, "event": "update",
           "content-state": { … }, "stale-date": 1705567570 } }
```

### The date trap, worth its own heading

`content-state` is decoded by **ActivityKit**, not by any decoder we
configure — and Swift's default strategy for `Date` is *seconds since the
2001 reference date*, not Unix epoch. A server helpfully sending ISO-8601,
or Unix epoch against a decoder expecting 2001, fails the entire update
**silently**: no error, no log, just a card that never changes on somebody's
lock screen.

So `ContentState.asOf` has explicit `CodingKeys` and encodes epoch seconds,
and the TypeScript side asserts a 10-digit value. Both files say why.

## What's blocked, and on whom

1. **An APNs provider key.** A `.p8` from the Apple Developer portal, plus
   its Key ID and the Team ID. **Andy has to create this** — it is a
   credential, and it is not mine to make or hold. Then three environment
   variables on Vercel: `APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`
   (the PEM; the parser restores the newlines a dashboard paste flattens).
   Without them `apnsConfigFromEnv()` returns null and the route reports
   `apns-not-configured` rather than failing — the normal state today.

2. **A scheduler that can actually tick.** Vercel Cron on the Hobby plan is
   **once a day**, which is useless for a 30-second cadence; minute-level
   crons need Pro. A minute is also not 30 seconds. Options, none free and
   none decided: Vercel Pro, an external pinger, or accepting a coarser
   cadence and leaning on the card's stale state. **This is a real decision
   and it is not made.**

3. **Channel creation.** Channels are made on APNs' *management* host at
   **port 2196** — a non-standard port a serverless runtime can't be assumed
   to reach. Apple's Push Notification Console creates them by hand, which
   is a supported workflow, so the first cut reads a static
   `APNS_CHANNELS` map (`{"cfb:401":"<channel>"}`) from the environment and
   creates nothing. That means **channels must be provisioned ahead of a
   slate**, which is fine for a test and not fine for a season. Doing it
   properly needs either a durable store or a box that can reach :2196 —
   another infrastructure conversation, deliberately not smuggled in here.

   Apple caps an app at **10,000 channels** per environment, so they also
   have to be reaped. Nothing does that yet.

## What is *not* verified

Everything above the transport. No request in this code has ever reached
Apple. Specifically untested against reality:

- that the JWT is accepted (the ES256 DER→JOSE conversion is unit-tested for
  shape — 64 raw bytes — but never against APNs);
- that `content-state` decodes into `GameActivityAttributes.ContentState` on
  a real device;
- that a channel created in the Console is subscribable by
  `Activity.request(pushType: .channel(...))`;
- anything about delivery latency, which is the entire product promise.

Treat the first live run as a spike, not a deploy.

## What this costs the privacy posture

`PRIVACY.md` said "no server of its own" and that stops being true the day
this deploys. It now says what the service does and does not hold. The claim
that matters — no accounts, no analytics, no tracking, nothing about a
person — survives, because the only thing this stores is which channel a
*game* is on.
