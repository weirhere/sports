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

   **The step-by-step is in § Creating the provider key below**, because
   "Andy has to create this" was the whole instruction for five days and it
   turns out the key is step 2 of 5, not step 1 of 1.

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

## Creating the provider key

Written down 2026-09-15 because the blocker above named the credential and
not the sequence, and the sequence has a step before the key that is easy to
miss: **the App ID does not have Push Notifications turned on.**
`Config/sports.entitlements` says so in a comment and explains why —
`aps-environment` was removed because it broke the archive against an App ID
with no push capability. So the entitlement and the capability go back
together, in the same change that ships this service.

Everything here is done once, by the account holder, and none of it is code.

**1. Turn on Push Notifications for the App ID.**
[developer.apple.com/account](https://developer.apple.com/account) →
Certificates, Identifiers & Profiles → **Identifiers** → `com.andyryanweir.sports`
→ tick **Push Notifications** → Save. Xcode's automatic signing regenerates
the profile on the next build; nothing has to be downloaded by hand.

**2. Create the key.** Same portal → **Keys** → the **+** button.

- Name it something a future person can identify (`StatSide APNs`).
- Tick **Apple Push Notification service (APNs)**.
- If the page offers an environment restriction (Sandbox / Production /
  both), take **both** — one key for both environments is what the transport
  assumes, and a sandbox-only key fails against production with an auth
  error rather than an obvious one.
- Continue → Register → **Download**.

**The `.p8` downloads exactly once.** Apple keeps the Key ID forever and the
private key never. Lose the file and the only move is to revoke the key and
make another. An account holds at most **2** APNs auth keys, so "make another
whenever" is not a plan.

**3. Collect three values.**

| Value | Where |
|---|---|
| **Key ID** | On the key's page after registering, and in the filename: `AuthKey_<KEYID>.p8` |
| **Team ID** | Portal top-right, or Membership details |
| **Private key** | The contents of the `.p8`, `-----BEGIN PRIVATE KEY-----` and `-----END PRIVATE KEY-----` lines included |

The `.p8` is a plain text file that **macOS has no default application for**,
so double-clicking it does nothing and it looks unreadable. It isn't. The
clean way to move it is straight onto the clipboard, which also keeps it out
of terminal scrollback:

```bash
cat ~/Downloads/AuthKey_*.p8 | pbcopy
```

To read it instead: `open -a TextEdit ~/Downloads/AuthKey_*.p8`, and don't
save from there — TextEdit can turn it into RTF. Store the file somewhere
durable afterwards (a password manager), because Apple will not hand it over
a second time.

**4. Put them on Vercel.** Project → Settings → Environment Variables:
`APNS_KEY_ID`, `APNS_TEAM_ID`, `APNS_PRIVATE_KEY`. Two optional ones exist
and both default correctly today: `APNS_BUNDLE_ID` (defaults to
`com.andyryanweir.sports`) and `APNS_ENVIRONMENT` (**defaults to sandbox**,
and anything other than the literal `production` is sandbox).

On the PEM specifically: paste it either way. Real newlines survive
untouched, and a flattened single line with literal `\n` sequences is
restored by `apnsConfigFromEnv`'s `replace(/\\n/g, "\n")`. What does not
survive is a missing BEGIN/END line.

**5. Restore the entitlement.** ~~Put `aps-environment` back into
`Config/sports.entitlements`.~~ **Done 2026-09-15** — the key is in the file
as `development`, which is correct for both configurations because Xcode
substitutes `production` when exporting for App Store distribution.

This one is code, so it is the one step not done in a browser. It depends on
**step 1**: if the App ID's Push Notifications capability is off, a device
build or an archive fails to sign with a profile-mismatch error naming the
entitlement. The fix is step 1, never deleting the key again — deleting it is
how the sequence got lost the first time. CI is unaffected either way; it
passes `CODE_SIGNING_ALLOWED=NO`.

### Sandbox first, and what that means for testing

A build Xcode installs on a device talks to **sandbox** APNs. TestFlight and
App Store builds talk to **production**. They are separate namespaces with
separate channels, so a channel provisioned in one is invisible to the other.
First light is therefore: debug build on a real device (the simulator cannot
receive pushes), `APNS_ENVIRONMENT` unset, channels created in the Push
Notification Console's sandbox environment.

### What the key does not unblock

Blockers 2 and 3 above — a scheduler that can tick faster than once a day,
and channel provisioning at :2196 — are untouched by any of this. The key
makes a *single hand-driven broadcast* possible, which is what first light
should be. It does not make a season possible.

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
