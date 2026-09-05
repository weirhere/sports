# Live Activities — the decision, and what it actually costs

**Status:** open question for Andy. No code exists. Written 2026-09-05, prompted by Gabe Santiago asking for Live Activities. Backlog: E9.

## Why this doc exists

The Icebox has carried one line since 2026-08-04:

> ~~Widgets~~ / Live Activities *(widgets de-iceboxed 2026-08-04 → E7; Live Activities stay iced — no push story without a backend)*

That verdict is right about the destination and wrong about the reasoning, because "a push story" is not one thing. There are three ways to keep a Live Activity on screen, they have very different costs, and only two of them involve a server. The one that needs no server fails for a reason that has nothing to do with backends. Deciding this properly means separating them.

CLAUDE.md § Don'ts: *"Don't add third-party packages, analytics, or a backend without an explicit conversation first."* This doc is the material for that conversation.

## What a Live Activity would be, concretely

A lock-screen and Dynamic Island card for one followed team's in-progress game: both marks, the score, the clock, the network. It starts at kickoff and ends at the final. It is the thing you glance at without unlocking the phone — which is exactly the app's stated promise ("Speed and focus are the product") extended one surface further out than the widget reaches.

ROADMAP.md has called this "probably the killer feature for this app" since the beginning.

## The three paths

### 1. Local-only updates — no server, and it still doesn't work

`NSSupportsLiveActivities` in the app's Info.plist keys, `ActivityKit` in a widget-extension surface, and `Activity.update(...)` called from the running app. No entitlement beyond the plist key, no APNs, no server, no new ESPN request source.

**Why it fails:** the activity only advances while our process is running. Background execution is not a schedule you can rely on — `BGAppRefreshTask` is granted at the system's discretion, typically minutes to hours apart, and is not designed for a 30-second cadence. So the card is fresh while you're looking at the app, and stale the entire time you aren't.

That is the inverse of the use case. A lock-screen score that is right only when you're already in the app is worse than no card at all, because it looks authoritative while lying. **This path is rejected on the merits, not on cost** — and that distinction matters, because "no backend" has been doing the work of this argument for a year.

### 2. Per-activity APNs push

The real mechanism: each started activity vends a push token, the app ships that token to a server, and the server pushes `content-state` updates to each activity as the score changes. Push-to-start tokens (iOS 17.2+) would additionally let a game's card appear without the user opening the app.

**What it costs:**
- `aps-environment` entitlement, APNs auth key, a push-capable server.
- **State.** The server must hold a token per activity per device, know which game each maps to, and expire them. That is a database. This is squarely the "stateful backend" CLAUDE.md rules out without a conversation.
- **ESPN load that scales with users.** The server polls on behalf of every active token. The politeness rule ("no faster than every 30s, only while foregrounded and live") was written for a client that only polls while someone is looking at it. A push relay poll runs for every subscribed game whether anyone is looking or not, and grows with installs. This is the part that should worry us most — it's the unofficial-API risk compounding, not just a hosting bill.

### 3. Broadcast push channels (iOS 18+) — the cheapest path that works

Channel-based Live Activity updates: devices subscribe to a **channel per game**, and one push to that channel fans out to every subscriber. Apple runs the fan-out.

**Why it's materially better than path 2:**
- **No per-user state.** The server holds channel ids for live games, not tokens for devices. Subscriber count doesn't change what it stores.
- **Flat ESPN load.** One poll per live game regardless of whether ten people or ten thousand are watching it — the same shape as the CFBD caching-proxy idea, which E8 already accepted as compatible once the constraint was amended to *"no **stateful** backend"* (BACKLOG.md:183).
- The Saturday ceiling is bounded by the slate, not the install base: ~60 concurrent games worst case, one poll each.

**What it still costs:** `aps-environment`, an APNs key, and a always-on service — most plausibly the same Cloudflare Worker shape E8 sketched for CFBD. It is a real operational commitment: if it goes down mid-Saturday, cards freeze on a wrong score, and there is nobody on call.

## Comparison

| | Server | Per-user state | ESPN load | Fresh on a locked phone |
|---|---|---|---|---|
| 1. Local-only | none | none | none | **No** — the disqualifier |
| 2. Per-activity push | yes | yes, a token store | scales with installs | Yes |
| 3. Broadcast channels | yes | none | scales with the slate | Yes |

## Recommendation

If Live Activities happen, **path 3**. Path 1 doesn't deliver the feature and shouldn't be built as a consolation version — a card that's stale exactly when you need it damages the product's central claim more than a missing feature does. Path 2 is path 3 with worse economics and a database.

Path 3 shares infrastructure with the CFBD caching proxy already sketched in E8. If the licensing question (Open question #6) ever resolves toward that proxy, the marginal cost of Live Activities drops a lot — the service exists by then and the ESPN-load argument is already conceded. **These two decisions are worth making together rather than separately.**

## The question for Andy

Is StatSide willing to run a small always-on service — an APNs-capable Worker holding no user data, polling one request per live game?

- **No** → Live Activities stay iced, and the Icebox line gets the honest reason: not "no push story", but "the only version that works needs a service we've chosen not to run."
- **Yes** → this becomes a real epic, and it should be sequenced with Open question #6, not ahead of it.
- **Not yet** → the doc stands; revisit when the licensing answer forces the proxy question anyway.
