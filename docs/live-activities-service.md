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
   **once a day**. Still not decided — but the problem is smaller than this
   entry made it sound, and **§ The scheduler decision** below is the
   write-up: the 30-second figure was a misread of our own polite-guest
   rule, and first light needs no scheduler at all.

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

## The scheduler decision

Written 2026-09-15, at Andy's ask. Nothing decided here either — but three
things turned up that change what is being decided.

### Three findings first

**1. The 30-second target was a misread of our own rule.** CLAUDE.md says
poll "no faster than every 30s." That is a **speed limit, not a
requirement**, and blocker 2 above had been reading it as a floor for five
days. The service already knows this: `broadcast/route.ts` sets
`STALE_AFTER_SECONDS = 120` and calls it *"two ticks' grace"*, which is only
true at a **60-second** tick. So the cadence to build against is 60 seconds,
the code already assumes it, and "a minute is not 30 seconds" was an
objection to a number nobody needs.

**2. `vercel.json` does not exist.** The route's own header says *"Driven by
Vercel Cron (see vercel.json)"* and there is no such file anywhere in the
repo. No cron is configured on any plan. The Hobby limit is not what is
stopping this today; nothing is scheduled at all, on any cadence.

**3. Hobby is for non-commercial projects.** Vercel's own terms put
commercial projects on Pro. Free today, because StatSide charges nothing —
and **the day E18 ships a membership, statside.co needs Pro regardless of
the scheduler**. That is $20/month the monetization break-even in
`docs/monetization.md` does not currently carry. The two open questions are
the same question wearing different hats.

### And the reframe that follows

**First light needs no scheduler.** One hand-driven broadcast is
`curl -H "authorization: Bearer $LIVE_ACTIVITY_CRON_SECRET"` against the
existing route. The scheduler only bites for an **unattended** slate, which
is a later problem than the device test. This decision can wait, and knowing
that is worth more than making it early.

### The options

`maxDuration = 60` is already set on the route and Hobby permits it, so one
invocation can cover a full minute. Nothing here needs an internal sleep
loop.

| | Cadence | Cost | The catch |
|---|---|---|---|
| **A. Vercel Pro** | 60s, minute precision | **$20/mo** | None technically. Needed anyway the moment the app charges money |
| **B. External pinger** (cron-job.org free) | **60s** | **$0** | A third party with no delivery contract, holding our cron secret in their dashboard |
| **C. GitHub Actions** | 60s *inside* a run | **$0** (public repo) | 5-minute minimum schedule, 5–30 minute delays common, and **public-repo schedules silently disable after 60 days of inactivity** |
| **D. Coarser cadence** | 5 min+ | $0 | Breaks the product |

**On C, because it looks better than it is.** A job runs up to 6 hours, so an
hourly-triggered workflow could loop internally at 60s and cover a whole
Saturday on free minutes. Start-time jitter wouldn't matter, since a run
covers the gap. What kills it is the silent disable: a quiet fortnight in
the repo and the lock screens stop updating with nothing failing anywhere.
A CI system is also not a thing to put production traffic through.

**On D, which is the one that sounds reasonable and isn't.** The card has an
`isStale` state on purpose, and it is the thing **none of the four reference
apps has**. It exists so a card whose updates stop says so rather than
freezing on a wrong score. It does not exist to make a 5-minute-old score
acceptable. A score five minutes stale during a two-minute drill is the
exact failure the app was built against, and shipping it would spend the one
promise — time-to-score — on a $20 saving.

### What the tick actually costs

At 60s across a 12-hour Saturday: **720 ticks**, 4 ESPN requests each
(one per league, whatever the slate), so ~2,880 ESPN requests in a day —
*slower* than the 30s ceiling the polite-guest rule permits. APNs sees one
push per live game per tick, so ~43,200 on a 60-game peak day, which is
nothing to APNs. 720 Vercel invocations sits inside Hobby's free tier.

**The load is a function of the slate, not the install base.** That is the
whole path-3 argument and none of these options change it.

### Recommendation

**Defer it.** Do first light by hand, with curl and one manually provisioned
channel, and learn what the thing actually does before paying anything to
automate it.

**Then B, then A.** The external pinger is $0 and honest about what it is:
a way to run an unattended slate before there is any revenue to justify a
plan. Move to Pro when E18 un-parks, because by then the terms require it
anyway and the $20 has a reason to exist beyond the cron.

### The question for Andy

1. **Is 60 seconds the cadence?** The code already assumes it and the rule
   permits it. Saying so out loud retires the 30-second number for good.
2. **Pinger or Pro for the first unattended Saturday?** $0 with a third
   party holding the secret, against $20 with nothing new in the stack.
3. **Worth folding Vercel Pro's $20/month into `docs/monetization.md`'s
   break-even now?** It is a real cost of charging money, and the table
   currently leaves it out.

### Sources

Plan limits and prices read 2026-09-15; they move, and none is a quote.

- Vercel — [cron usage and pricing](https://vercel.com/docs/cron-jobs/usage-and-pricing), [Hobby plan](https://vercel.com/docs/plans/hobby), [pricing](https://vercel.com/pricing)
- GitHub Actions — [scheduled-jobs frequency change](https://github.blog/changelog/2019-11-01-github-actions-scheduled-jobs-maximum-frequency-is-changing/), [workflow syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions)
- The polite-guest rule and the 60s assumption are ours: `CLAUDE.md` § Data source, and `STALE_AFTER_SECONDS` in `web/src/app/api/live-activity/broadcast/route.ts`

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
