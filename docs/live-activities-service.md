# The Live Activity broadcast service

**Update 2026-09-24: blocker 3 is built, and it has not yet run against
Apple.** Channels are now made **on demand**. The first pin of a game calls
`GET /api/live-activity/channel`, which checks the game against ESPN, creates
its channel on APNs' management host, and records it in Upstash Redis. Every
later pin reads that record back. The broadcast tick pushes to stored
channels and **reaps** them: an hour after a game's first `end` push, or a day
after kickoff for a game that never finished. Only games that are live or
kick off within 12 hours get a channel, because ActivityKit ends a card after
8 hours anyway. Without a store, both routes fall back to the hand-made
`APNS_CHANNELS` map below.

**A correction to everything below:** the management host is on **:2195 in
the sandbox** and on :2196 only in production (Apple, "Sending channel
management requests to APNs", checked 2026-09-24). The text below says
:2196 throughout. That was the production figure, and it's wrong for the
sandbox, which is where first light happens.

**Still needed before it runs:**
1. Add Upstash Redis to the `weirhere/web` project through the Vercel
   Marketplace. It sets `KV_REST_API_URL` and `KV_REST_API_TOKEN`, and the
   code reads either those or the `UPSTASH_REDIS_REST_*` pair.
2. The probe: one `curl "https://<preview>/api/live-activity/channel?gameId=<a
   game kicking off today>&league=nfl"` on a deployment with the sandbox key.
   A `channelId` in the answer proves Vercel can reach :2195. An
   `apns-send-threw: … ECONNREFUSED/timeout` on the retry means it can't, and
   the next step is the infrastructure conversation this doc has been
   deferring.
3. First light on a real device, as described below.

**Not yet handled:** an orphan sweep. A channel whose record expired (48h
TTL) without being reaped stays at Apple, counted against the 10,000 cap.
That only happens if the tick stops running for two days. Apple's
`GET /1/apps/<bundle>/all-channels` is how to find orphans when it matters.

**Status: APNs accepted a broadcast on 2026-09-15.** `{"status":"ok",
"pushed":1,"failed":[]}` against a live NFL game, sandbox environment, from
production. The server half of path 3 works end to end.

**What that proves**, and it is worth enumerating because every step had been
a guess until this response: `node:http2` reaches APNs from Vercel's runtime;
the ES256 provider token signs and verifies against the real `.p8`; the
channel id resolves and Apple recognises it; the payload and every header
pass validation. Four things that had only ever been read about.

**What it does not prove: that a card appears on anybody's lock screen.**
`pushed: 1` means Apple accepted the broadcast *for fan-out to that channel's
subscribers*, and the channel currently has none. The client half is built
and gated off (`LiveActivityController.isAvailable` is a DEBUG-only default),
so putting a card on glass still needs a debug build on a real device — the
simulator cannot receive pushes — with the activity started from that game's
detail page. **That is a separate milestone and it has not happened.**

*Previous status, kept because the gap between it and the line above is the
whole story: "code written and unit-tested 2026-09-10; never once run against
Apple."* Three things were wrong in it and none could have been caught by
reading: the transport, the missing `apns-expiration`, and the unhandled
throw that hid both.

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
ordinary serverless runtime can reach it at all.

**Over HTTP/2, which is not optional and is not what `fetch` does.**
*(Amended 2026-09-15, from the first run against Apple.)* APNs has been
HTTP/2-only since the provider API existed, and Node's `fetch` is undici,
which is HTTP/1.1-only. Pointing `fetch` at Apple does not fail politely: it
feeds HTTP/2 binary frames to an HTTP/1.1 parser and throws
`TypeError: fetch failed` with an `HTTPParserError` cause, which Vercel
renders as a **500 with an empty body**. The transport is `http2Transport`
in `apns.ts`, built on `node:http2` — built in, so the no-dependency rule
holds for the same reason `node:crypto` signs the JWT.

**The heading below says "verified" and it is worth being exact about what
was.** The headers and the payload were checked against Apple's published
specification on 2026-09-10 and were right. The transport underneath them
was never run, and could not have worked. Reading a document cannot verify
a socket.

| Header | Value |
|---|---|
| `authorization` | `bearer <ES256 JWT>` |
| `apns-push-type` | `liveactivity` |
| `apns-topic` | `<bundleId>.push-type.liveactivity` |
| `apns-channel-id` | the channel |
| `apns-priority` | `10` for a score, `5` for a routine tick |
| `apns-expiration` | UNIX seconds, and **required on a broadcast** |

**`apns-expiration` is not optional here**, which the spec reading missed and
the first real send caught: absent, APNs reads it as 0 and answers
`BadExpirationDate`. It is a required field on `BroadcastRequest` now, so the
compiler enforces it. The route sets an update to expire at its own stale
date — a score two ticks old has no business arriving on a lock screen — and
a final an hour out, inside the 8 hours a most-recent-message channel stores.

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

*Written before any of this had run. Blockers 1 and 3 closed on 2026-09-15
for a single hand-provisioned game; blocker 2 was decided the same day (60s
on an external pinger). What remains of 3 is the part that was always the
hard half: **provisioning at the scale of a slate**, rather than one channel
made by a person in a console. The text below stands as the record of what
each cost.*

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

   **The by-hand path is written out in § Provisioning a channel below**,
   including the capability that has to be switched on before the console
   will show you a Channels tab at all.

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

Written 2026-09-15, at Andy's ask. **Resolved the same day: 60 seconds, and
an external pinger** (Andy: *"60 seconds is fine, go with the pinger"*). The
reasoning below stands as written; § Setting the pinger up is what to do
about it.

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

### Resolved 2026-09-15: 60 seconds, option B

**60 seconds is the cadence.** The 30-second number is retired — it was the
polite-guest *ceiling* read as a floor. `STALE_AFTER_SECONDS = 120` is two
ticks' grace and stays; it moves only if the cadence does.

**The pinger, not Pro.** $0 while there is no revenue to justify a plan, and
honest about what it is. Vercel Pro stays the destination rather than the
starting point: the terms require it the day E18 ships anything paid, which
is also the day the $20 has a reason to exist beyond the cron.

First light is still by hand — one curl, one manually provisioned channel —
because a pinger against an endpoint that has never once talked to Apple
tests nothing.

**Still open:** whether to fold Pro's $20/month into `docs/monetization.md`'s
break-even now. It is noted there against the price table and not yet in the
arithmetic.

### Setting the pinger up

Nothing here is code. **Steps 1–3 are worth doing now** — the hand-driven
first light needs the same secret, so they are not pinger-specific work.
**Step 4 onward is only worth doing once there is something to push**, which
means after the provider key and at least one channel exist. A pinger
hammering an endpoint that answers `apns-not-configured` every minute is a
scheduled no-op.

#### 1. Generate the secret

```bash
openssl rand -hex 32
```

Copy the output. It is 64 hex characters on one line. This is the only thing
standing between the internet and a push relay, so treat it like the `.p8`:
not in chat, not in a screenshot, not in the repo, into a password manager.

A secret that has been pasted anywhere shared is spent — generate another,
which costs one command. That is cheap precisely while it is still only in a
terminal; it stops being cheap once it is in Vercel and a third party's
dashboard, which is the argument for being careful at exactly this step.

#### 2. Put it on Vercel

1. [vercel.com](https://vercel.com) → the **sports** project
2. **Settings** → **Environment Variables**
3. Key `LIVE_ACTIVITY_CRON_SECRET`, value the 64 characters from step 1
4. Tick **Production** at minimum. Tick Preview too if you want the branch
   preview URL to answer, which is handy while testing.
5. Save

#### 3. Redeploy, which is the step everyone skips

**A new environment variable does not reach the deployment that is already
running.** Vercel injects them at build time, so until there is a new
deployment the route still sees no secret and still answers 401 to
everything, including a correct request. This looks exactly like a wrong
secret and it is not.

Deployments → the current one → **⋯** → **Redeploy**. Or push any commit.

#### 4. Prove it by hand, before any scheduler exists

Put the secret in a shell variable first, rather than into the command:

```bash
read -rs SECRET        # press enter, paste, press enter again
echo ${#SECRET}        # should print 64
curl -i https://www.statside.co/api/live-activity/broadcast \
  -H "authorization: Bearer $SECRET"
```

`read -rs` does not echo, so the secret stays out of scrollback and shell
history — and there is nothing left to substitute by hand. **A placeholder
written as `<the secret>` gets pasted verbatim**; it happened twice on
2026-09-15 and produced two clean 401s that looked like real failures.

**`www`, not the apex, and this is not cosmetic.** *(Confirmed against
production 2026-09-15: the apex 308s, `www` answers the route directly with
`x-matched-path: /api/live-activity/broadcast`.)* `statside.co` answers
**308** with `location: https://www.statside.co/...`, and curl strips the
`Authorization` header when it follows a redirect to a *different host* —
which `www.statside.co` is. So the apex URL either stops at the redirect
(without `-L`) or arrives with no credentials (with it), and both look like
a broken secret. Found 2026-09-15, from a real 308 against the apex.

The same applies to the pinger's URL in step 5.

Read the body, because all three answers mean different things:

| Response | What it means |
|---|---|
| `{"status":"apns-not-configured","pushed":0}` | **Working.** Auth passed; the APNs key just isn't set yet. This is success today |
| `{"error":"unauthorized"}` (401) | The secret is wrong, or step 3 never happened |
| `{"status":"ok","pushed":N}` | Fully wired, and N cards were actually updated |

Do not move on until you get one of the first or third. The whole point of
doing this by hand first is that a scheduler makes every failure quieter.

**First light, such as it is, happened 2026-09-15**, in two steps an hour
apart. The route answered an authorized request in production for the first
time — `apns-not-configured` — and then, once the three APNs variables
landed and the deploy caught up, `{"status":"ok","at":"…","pushed":0,
"failed":[]}`.

What `ok` proves: the deploy is live, the bearer guard rejects a wrong secret
and accepts the right one, `www` is the reachable host, the provider key
**parsed**, and the route completed a full pass — four league scoreboards
fetched from Vercel, no errors.

What it does not prove: that **Apple accepts the key**. `ok` means
`apnsConfigFromEnv()` returned a config rather than null, and nothing more.
`pushed: 0` is correct at that point because `APNS_CHANNELS` is unset, so
every game falls out at `if (!channelId) continue`. The first evidence Apple
has ever seen this key is a delivered broadcast, which needs § Provisioning a
channel.

#### 5. Create the job at cron-job.org

Free tier, and it goes down to 60-second intervals. Sign up, verify the
email, then **Create cronjob**:

- **Title** — `StatSide Live Activity broadcast`
- **URL** — `https://www.statside.co/api/live-activity/broadcast` — **`www`**, for the 308 reason in step 4
- **Schedule** — every **1 minute** (see step 6 before leaving this at 24/7)
- **Advanced / request settings** → **Method** `GET`
- **Advanced / request settings** → **Headers**, add one:
  - Name `Authorization`
  - Value `Bearer <the secret>` — the word `Bearer`, a space, then the secret

Save, then use their **Test run** / **Execute now** button and check the
response body matches what curl gave you in step 4. Their history view keeps
the responses, which is the log we would otherwise not have.

Two things to watch on their side: they time out a request before our
`maxDuration = 60` does, and a timeout on their end does **not** mean the
function did not run — it means they stopped listening. And their failure
notification emails are the only alerting this service has.

#### 6. Bound the schedule to game windows

**Do not leave it at every minute, around the clock.** Every tick costs four
ESPN scoreboard requests whether or not a ball is in the air, because nothing
can know without asking. 24/7 at 60s is ~5,760 requests a day, most of them
spent on an empty Tuesday at 3am, against a polite-guest rule that says poll
*only while games are live*.

cron-job.org's schedule editor takes days and hours, so use them:

| | Roughly |
|---|---|
| College football | Saturdays, ~11:00–02:00 ET |
| NFL | Sundays ~12:30–24:00 ET, plus Monday and Thursday evenings |
| NBA / NHL | Nightly, ~19:00–01:30 ET |

Start with **one day** — the Saturday you actually want to watch — rather
than modelling the whole calendar up front. The point of the first unattended
slate is to find out what breaks, and a narrow window makes that cheaper.

Doing this properly in code means caching the next kickoff and skipping the
fetch until then, which is state this service deliberately does not hold.
Until it does, the pinger's schedule is the only thing that can honor the
rule.

#### Rotating the secret, when it comes to that

Vercel first, then redeploy, then the cron-job.org header. In that order
there is a gap where the pinger 401s; in the other order there is a gap where
the old secret still works. The first is the safer failure.

### Sources

Plan limits and prices read 2026-09-15; they move, and none is a quote.

- Vercel — [cron usage and pricing](https://vercel.com/docs/cron-jobs/usage-and-pricing), [Hobby plan](https://vercel.com/docs/plans/hobby), [pricing](https://vercel.com/pricing)
- GitHub Actions — [scheduled-jobs frequency change](https://github.blog/changelog/2019-11-01-github-actions-scheduled-jobs-maximum-frequency-is-changing/), [workflow syntax](https://docs.github.com/actions/using-workflows/workflow-syntax-for-github-actions)
- The polite-guest rule and the 60s assumption are ours: `CLAUDE.md` § Data source, and `STALE_AFTER_SECONDS` in `web/src/app/api/live-activity/broadcast/route.ts`

## Provisioning a channel

Walked live 2026-09-15. The order matters: the console will not let you make
a channel until the App ID carries the capability, and the button it offers
for that does not do it.

#### 1. Turn on Broadcast for the App ID

**Broadcast is a sub-capability of Push Notifications, separate from it and
off by default.** Having Push Notifications on is not enough.

[developer.apple.com/account](https://developer.apple.com/account) →
Certificates, Identifiers & Profiles → **Identifiers** →
`com.andyryanweir.sports`. Scroll the capability list to **Push
Notifications** — already ticked — and **Broadcast Capability** is an
**inline sub-checkbox directly beneath it**. Tick that, then **Save** at the
top right.

**Two buttons nearby that are not it**, both walked into on 2026-09-15:

- **Configure**, beside Push Notifications, opens *Apple Push Notification
  service SSL Certificates* — the legacy certificate auth path. With a `.p8`
  provider key there is **nothing to create there**; hit Done and ignore it.
  A certificate made here is harmless and useless.
- **Enable broadcast capability**, on the console's Channels tab, opens
  [Apple's documentation](https://developer.apple.com/documentation/usernotifications/setting-up-broadcast-push-notifications)
  rather than enabling anything. A dead end shaped like a control.

The switch is the checkbox in the list. Neither button leads to it.

Changing App ID capabilities invalidates provisioning profiles. Automatic
signing regenerates them on the next build, so there is nothing to download.

#### 2. Create the channel

The console is at
[icloud.developer.apple.com/dashboard/notifications](https://icloud.developer.apple.com/dashboard/notifications),
or from the account page under **Services → Push Notifications**. Pick the
app, then **Channels** → **New Channel**:

| Field | Value | Why |
|---|---|---|
| **Environment** | **Development** | This is sandbox, which is what `APNS_ENVIRONMENT` defaults to. Sandbox and production are separate channel namespaces, so a channel made here is invisible to a TestFlight build |
| **Push type** | **Live Activity** | |
| **Storage policy** | **Most Recent Message** | See below |

**On the storage policy.** *No Storage* delivers only to devices connected
right now and buys a higher publishing budget; *Most Recent Message* holds
the latest deferred update for a device that reconnects. Most Recent is the
better fit here and the reason is specific to scores: the most recent
message **is** the current score, so a phone that dropped off for two minutes
comes back correct rather than blank, with no staleness risk. The cost is
budget, which matters at a 60-second tick and is the thing to watch first if
updates start disappearing.

#### 3. Wire it up

Copy the channel id, then set `APNS_CHANNELS` on Vercel to a JSON map keyed
`<league>:<gameId>` — `{"nfl:401772936":"<channel id>"}` — redeploy, and curl
the route again. `pushed` goes to 1 when that game is **live**: the route
skips anything pre-game (`if (phase === "pre") continue`), so an end-to-end
test needs a game actually in progress, not merely scheduled.

**This is the part that does not scale**, and it is worth being blunt about
it rather than letting a working test imply otherwise. One channel per game,
created by hand, against a slate that is ~60 games on a September Saturday.
It is a test harness, not a season. The real version needs a durable store
and a box that can reach :2196, which is blocker 3's unsolved half.

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
