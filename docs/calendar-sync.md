# Calendar sync — the decision, and what it actually costs

**Status:** open question for Andy. No code exists. Written 2026-09-05, prompted by Matt Walkley asking to subscribe to games from his calendar. Backlog: E9.

## Why this doc exists

Matt's ask, verbatim:

> *"Subscribe via to calendar so I can see the dates amidst my life schedule"*
>
> *"We always add the games manually so we can plan kids sports and activities around games we don't want to miss"*

The word *subscribe* is doing real work. A subscription in the calendar sense is a hosted `.ics` feed that a calendar app polls — which is a backend. But the need Matt described is also served by the app writing a calendar on the device, with no server anywhere. Those are different features with very different costs, and there is a third, much smaller thing that helps a little and costs almost nothing. Deciding this properly means separating them.

CLAUDE.md § Don'ts: *"Don't add third-party packages, analytics, or a backend without an explicit conversation first."* This doc is the material for that conversation.

## What it would be, concretely

The games of the teams you follow, sitting in Apple Calendar next to kids' soccer and school pickup, so an October Saturday conflict is visible in September instead of the night before.

The app already knows this exact set of games — it builds kickoff reminders from it every time the scene activates (`NotificationScheduler.resync(followedKeys:)`). Nothing here needs a new data source. What is new is a surface the app doesn't own.

**Scope, already decided (Andy, 2026-09-05):** followed **teams** only. Followed conferences are out — a conference season is ~150 games, and dropping that into someone's personal calendar isn't sync, it's vandalism. This also keeps the calendar consistent with the widget and the reminders, which are both already team-driven.

## The three paths

### 1. On-device EventKit calendar — no server

The app creates a "StatSide" calendar and reconciles it against the followed teams' schedules whenever follows change or the app foregrounds.

Note up front: **EventKit cannot create a subscribed calendar programmatically.** Path 2 is not a hosted variant of this one — it's a different feature with a different mechanism.

Structurally this is `NotificationScheduler` again: a `nonisolated protocol` slice for test injection (value types only, so no `EKEvent` ever crosses it and the fake is a plain actor), an enabled flag in defaults, `refreshAuthorization()` / `requestAndEnable(followedKeys:)` / `disable()` / `resync(followedKeys:)`, and a desired-vs-existing diff. Most of the logic is a pure function over value types, which is where the tests live.

**It needs full calendar access, and that follows from an argument rather than a spike.** Write-only access can neither read events back nor fetch one by identifier — and updating or deleting requires holding the fetched object. So write-only permits no updates and no deletions at all: every resync would blindly append and duplicate the season. Reconciliation *is* the feature, so `NSCalendarsFullAccessUsageDescription` it is, and the heavier prompt comes with it.

**Reconcile by reading our own calendar back, not by persisting an id map.** Match on a marker written into `event.url` (`statside://game/{id}?league=cfb` — already a valid `DeepLink`, league-qualified because ESPN ids collide across sports). `eventIdentifier` is a device-local, store-assigned handle: a persisted `[gameId: eventIdentifier]` map survives a device restore while the identifiers it names do not, which is how you get orphaned events or, worse, writes aimed at somebody else's. Read-back is self-healing — whatever is in our calendar right now is the state.

Diff rules that are product decisions, not implementation details:

- **An unmarked event in our calendar is never touched.** Someone may have filed their own event there, and deleting a user's event is unrecoverable.
- **Nothing before today is ever revisited**, so unfollowing a team doesn't erase the Saturdays you already spent.
- **A moved kickoff is an in-place update, never delete-and-recreate.** A recreate on a shared calendar flickers the event out and back, drops any alarm the user added to it, and re-notifies every subscriber.
- **`timeTBD` becomes an all-day event**, which is a principled divergence from notifications (they skip TBD games). A reminder with no kickoff time is useless; a day-block with no kickoff time is exactly what a TBD game does to your Saturday. When ESPN publishes the time it flips to a timed event in place. The all-day date must be derived in **Eastern** time — ESPN's placeholder is midnight ET, so a Pacific user's local day would be the day before.
- **No scores, ever, and no alarms.** Writing a final score would rewrite every past event and broadcast spoilers to everyone on a shared calendar. An `EKAlarm` would double-notify against the existing 30-minute reminder, and on a shared calendar it alarms the whole family.

The `maxScheduled = 24` cap does **not** carry over — that exists for iOS's 64-pending-notification limit. A cap still belongs, but for a product reason: 60 followed teams would mean ~780 events. Three teams is ~42.

**Cost on the API is 2N requests, not N** — `teamSchedule` issues a regular and a postseason call per team — and `NotificationScheduler.resync` already fetches this exact data on every scene-active. A separate calendar resync on the same trigger would double the app's schedule traffic for zero new information, so both features should read through one shared fetch. That fetch must also carry a **completeness flag: never delete on an incomplete answer.** (The reminder scheduler has this bug today — see the E5 backlog item — and in a calendar it would remove ~70 events from a family calendar because a plane had no wifi.)

**Two frictions worth naming.**

The marker URL works for diffing but isn't *tappable* from Calendar.app unless the `statside://` scheme is registered — and it is deliberately unregistered (decisions log, 2026-08-04, because widget and notification taps deliver in-process). A calendar event is the first StatSide artifact that lives outside the app and wants to point back into it. Ship it unregistered (the diff is what matters); registering it is its own follow-up, since it supersedes a logged decision.

The denied-permission state opens Settings, which would be the app's **second UIKit exception** after `openNotificationSettingsURLString`, and needs a decisions-log row.

**The honest cost:** events only move when the app runs. There's no background refresh in this app, and adding one means unattended ESPN requests. Kickoff times land ~12 days out, so a phone that hasn't opened StatSide in a fortnight holds a stale calendar. It degrades gracefully, though — the TBD all-day event is *correct* in the meantime, so the failure mode is "that Saturday is blocked" rather than "wrong time."

**The advantage path 2 can't match:** written to an iCloud source, the calendar syncs to his Mac and iPad and can be **shared with his spouse from Calendar.app**. That's nearer to "plan kids sports around games" than a subscription he alone holds. Where it lands has to be said out loud in the UI ("in iCloud" vs "on this iPhone"), because the local-source fallback quietly doesn't do the thing he asked for.

### 2. Hosted `.ics` feed — the literal subscription

A route on the existing `web/` Next.js app, already deployed to Vercel and already carrying an ESPN client under `src/lib/espn/`. Genuinely what Matt asked for: it updates without the app running, and it works on a phone that doesn't have StatSide installed.

Serve **per-team** feeds (`/cfb/team/333.ics`), not per-user ones. The user subscribes once per team, so the follow *set* never leaves the device and the URLs stay static and CDN-cacheable. A single feed encoding the whole follow set would leak it in a URL and in Vercel's logs.

It is stateless — no user records, flat ESPN load — the same shape E8 already accepted when it amended the constraint to *"no **stateful** backend"* (BACKLOG.md:183).

**What it costs:**

- **It is still a backend**, and it republishes ESPN-derived data from Andy's own domain rather than an app calling ESPN directly. That is a materially larger licensing exposure, and it belongs *to* Open question #6 rather than beside it.
- **PRIVACY.md would have to change.** It currently says the app has "no server of its own," and that StatSide "sends no identifiers, no account information, and nothing about which teams you follow." Per-team feeds keep the second promise largely intact; the first is simply false once a feed exists.
- **The auto-update edge is smaller than it sounds.** iOS lets a user pick a subscription refresh from 5 minutes to weekly, but treats the interval as a hint and defers it aggressively on battery, in Low Power Mode, or on a phone that hasn't been unlocked — and the default is slow. Confirm the current default before leaning on this either way.

### 3. Per-game "Add to Calendar" — near-free, and it composes with either

An `EKEventEditViewController` from the game-detail toolbar: the system's own out-of-process editor, prefilled, where the user picks the destination calendar. No reconcile, no store, no Info.plist key, and reportedly no permission prompt at all (see the spike list).

It does **not** answer Matt's ask — one game at a time is not a standing arrangement. But it's the smallest useful thing in the space, it's roughly a tenth of the work, and it survives whichever way paths 1 and 2 go. It would also tell us something: if people use it constantly, standing sync is the right next build.

## Claims that need a spike, stated as such

Apple's own documentation pages were not retrievable while researching this, so these are labelled rather than asserted. **None of them blocks Andy's answer** — the full-access argument above is self-contained — they block the first day of implementation.

- **EventKit's inclusive/exclusive `endDate` convention for all-day events.** The classic off-by-one renders a one-day event across two, and TBD games are all-day by design.
- **Whether `INFOPLIST_KEY_NSCalendarsFullAccessUsageDescription` survives Xcode's Info.plist generation.** The app target has no Info.plist file (`GENERATE_INFOPLIST_FILE = YES`), and a missing usage string is an instant crash on the permission request. Verify with `plutil -p` on the built `.app`.
- **Whether `EKEventEditViewController` genuinely needs no permission prompt on iOS 17+** — path 3's whole appeal. WWDC23 material says it renders out of process with full access regardless of the app's own grant; other sources say write-only is still required first.
- **Whether a `.local` source exists on an iCloud-signed-in device**, and what the source list looks like with iCloud off — the fallback chain's last rung.
- **Whether Calendar.app will launch a registered `statside://` URL** from an event's URL row, if the scheme is ever registered.
- Judgment rather than fact, and flagged as such: **the event duration**. ESPN gives no end time, so a fixed per-league guess (~3.5h CFB, ~3h NFL) stands in. Erring long is right — the event's job is to block the afternoon.

## Comparison

| | Server | Per-user state | Privacy rewrite | Licensing exposure | Fresh without opening the app | Syncs + shareable with family |
|---|---|---|---|---|---|---|
| 1. On-device calendar | none | none | no | none | **No** — the cost | **Yes** |
| 2. Hosted `.ics` | yes | none | yes | **grows** | Yes, with caveats | No |
| 3. Add to Calendar | none | none | no | none | n/a | n/a |

## Recommendation

**Path 1, and path 3 regardless.**

Path 1 delivers what Matt described — including the family half, which the subscription can't do — with no server, no privacy rewrite, and no new licensing surface. Its weakness is real but bounded: it degrades to *last week's truth*, not to a wrong number on a lock screen. That distinction is exactly why the local-only Live Activities path failed on the merits (`docs/live-activities.md`) and this one doesn't — a stale calendar entry is a planning tool that's a bit behind; a stale live score is a lie.

Path 3 costs almost nothing, needs no decision from anyone, and is the fallback that still delivers something if path 1 is deprioritized.

Path 2 is the only literal subscription. Its cost isn't hosting — it's that publishing ESPN-derived schedules from Andy's domain moves Open question #6 from "decide before submission" to "decide now." **Sequence it with that question, not ahead of it.**

## The questions for Andy

Two, because they unblock separately.

**1. Build the on-device calendar (path 1)?**

- **Yes** → this becomes a real build item, the spikes above run first, and the decisions log gains a row for the second UIKit exception.
- **No** → the doc records the reason, and path 3 ships on its own.

**2. Ever publish `.ics` feeds (path 2)?**

- **Yes** → sequence it with Open question #6 and budget a PRIVACY.md rewrite; the "no server of its own" sentence goes.
- **Not yet** → the doc stands, and gets revisited when the licensing answer forces the hosting question anyway.
