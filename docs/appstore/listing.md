# StatSide — App Store listing

Everything App Store Connect asks for, drafted. Character limits noted where they exist.
Fields marked ✏️ are Andy's-voice drafts — edit freely; nothing here is load-bearing.

## App name (30 chars max, must be unique on the store)

1. `StatSide` (8) — if available, take it. (iTunes Search API showed no app
   named StatSide as of 2026-07-21 — likely free, confirmed only when App
   Store Connect accepts it.)
2. `StatSide — CFB Scores` (21) — fallback
3. `StatSide: College Football` (26) — fallback

## Subtitle (30 chars max)

`College football, at a glance` (29)

Alternate: `Fast college football scores` (28)

## Category

Primary: **Sports**. No secondary needed.

## What's New in This Version (4000 chars max) ✏️

Per-version release notes. Newest first — keep the old ones, this is the
release-notes history now.

### 1.3.0 (build 10)

> • Scores opens by date now, so today's games lead the page. The by-conference
>   view is one tap away in the new view sheet.
> • Filter the slate: all games, Top 25, or any single conference. Your filter
>   and grouping choices stick between launches.
> • Conference pages picked up a Games tab: the whole season's slate, week by
>   week, with past seasons in the season picker.
> • Team pages wear their team's colors, and a game in progress jumps to the
>   top as a Current game card with live scores and the clock.
> • Standings show who's playing right now: a green dot for winning, red for
>   losing.
> • Live rows list the TV network under the clock, so "where do I watch" gets
>   answered without leaving Scores.
> • The live accent turned green, and on iOS 26 the header controls picked up
>   a Liquid Glass finish.

### 1.0.1 (build 7)

> • Kick times now read the way you think about them — "Today 3:30 PM,"
>   "Tomorrow," then the weekday. No date math on the way to the couch.
> • Every row reflows to a single column at the largest text sizes, so team
>   names stop truncating to a letter and an ellipsis.
> • Sharing a score now carries a link to the app.

### 1.0 (build 6)

> Initial release. (App Store Connect doesn't show What's New on a first
> version — the Description carries it.)

## Promotional text (170 chars max — editable anytime without review) ✏️

> Kickoff is coming. Follow your teams, get kickoff reminders, and put their
> games on your Home Screen — ready for Week 1 with live scores and rankings. (151)

## Description (4000 chars max) ✏️

> StatSide is college football, at a glance. One screen answers "what's
> happening in college football right now" — no ads, no interstitials,
> nothing between you and the scores.
>
> BUILT FOR SATURDAYS
> • Your teams first: follow any FBS team and their games lead the page
> • Top 25 games in their own section, always complete
> • Every conference in collapsible sections that remember how you left them
> • Live games get a pulsing dot, a possession marker, and the only red in the app
> • One tap filters to live games only
>
> YOUR TEAMS, EVERYWHERE
> • A Home Screen and Lock Screen widget with your teams' live score or next kickoff
> • Kickoff reminders 30 minutes before your teams play
> • Ask Siri "What's my next game?" — or share a score straight from any game
> • Long-press any game to follow a team or share the score
>
> A WEEK, NOT A DATE
> College football thinks in weeks — so does StatSide. Flip through Week 0
> to championship week, the bowls, and the Playoff. Sunday keeps the
> completed week on screen until the new polls drop.
>
> RANKINGS AND DETAILS
> • AP Top 25 and Coaches Poll, with movement arrows
> • Game pages: line score, scoring plays, drive log, team stats, leaders
> • Team pages: full season schedule and results
> • Browse past seasons back to 2014
>
> DESIGNED QUIET
> Black, white, and your team's colors. No banner ads, no autoplay video,
> no account, no tracking. StatSide collects no data — your followed teams
> live on your phone and nowhere else.
>
> Free. Fast. One sport, done right.
>
> StatSide is an independent app and is not affiliated with or endorsed by
> the NCAA or any conference or school.

## Keywords (100 chars max, comma-separated, no spaces needed after commas)

`college football,cfb,scores,live,rankings,top 25,ncaaf,schedule,sec,big ten,playoff` (83)

Don't repeat words already in the name/subtitle — they're indexed automatically.

## URLs

- Support URL: `https://weirhere.github.io/statside-site/` (docs/index.html — see below)
- Privacy Policy URL: `https://weirhere.github.io/statside-site/privacy.html`
- Marketing URL: optional, leave blank

Live via GitHub Pages from the public weirhere/statside-site repo (this repo
is private, so Pages is hosted separately). Source of truth: docs/ here —
copy changes over to statside-site when editing.

## Screenshots

Required: 6.9" (iPhone 17 Pro Max class, 1320×2868). Smaller sizes reuse the
6.9" set automatically unless you upload separate ones. Captured by
`sportsUITests/AppStoreScreenshots.swift` — see docs/appstore/screenshots/.

**Upload the 1284×2778 copies, not the masters.** This account's drop zone
rejects 1320×2868; `docs/appstore/screenshots-1284x2778/` is the set that
actually goes up, resized from the masters in `screenshots/`. Learned the
expensive way during the 1.0 submission.

Screenshots carry forward automatically on a version update — you only
replace them when the shots themselves change. Note that the nine promo PNGs
in `docs/social/` crop into these masters at hardcoded pixel offsets, so
reshooting means re-rendering those too (see docs/social/README.md).
Order suggestion: scores (hero) → **widget on the Home Screen** → game detail
→ rankings → teams → team page. The widget frame is captured manually from
the simulator (springboard is outside the UI test's reach) — it's the
reviewer's first visual evidence of native functionality, put it second.

## App Privacy (nutrition label)

Answer: **Data Not Collected** — the app has no accounts, analytics, ads, or
backend. Followed teams and UI state are stored only on-device in UserDefaults.
Score data is fetched anonymously over HTTPS.

## Age rating questionnaire

All content questions: **None** (no violence, gambling, etc. — sports scores).
Unrestricted web access: **No**. Gambling: **No**. Result: **4+**.

## Export compliance

Uses only standard HTTPS/ATS encryption → **exempt**. The project sets
`ITSAppUsesNonExemptEncryption = NO` in the Info.plist build settings, so App
Store Connect won't even ask per-build.

## App Review notes (submission form) ✏️

Rewritten 2026-08-04 for the 4.2.2 resubmission. Leads with what the user
does and the native surface area; never self-describes as displaying
aggregated content.

> StatSide is a fully native SwiftUI app built around following your college
> football teams. Follow a team (Teams tab) and the app personalizes around
> it: a Following section leads the scores page, your team's conference
> floats up, and you can turn on kickoff reminders — local notifications 30
> minutes before each of your teams' games, scheduled on-device.
>
> Native functionality in this build:
> • Home Screen and Lock Screen widget (WidgetKit) showing your teams' live
>   score or next kickoff, with deep links into the app
> • Local kickoff notifications with deep links to the game
> • Siri Shortcut / App Intent: "What's my next game?"
> • Live scores that update in place every 30 seconds while games are on,
>   with haptic feedback on score changes
> • Share sheets, context menus on every row, full Dynamic Type and
>   VoiceOver support, light/dark mode
> • No web views anywhere; every screen is native SwiftUI
>
> To demo in the offseason: follow any team from the Teams tab, then enable
> the bell on its team page (kickoff reminders), add the StatSide widget to
> the Home Screen, and use the season picker (top right of Scores) to browse
> the completed season with full live-style data. No login required. The app
> collects no data (App Privacy: Data Not Collected).

## 4.2.2 resubmission (build 6) — Resolution Center reply ✏️

Sent in-thread in App Store Connect alongside the build 6 submission.
Tone: never argue; enumerate what changed.

> Hello, and thank you for the review.
>
> We've submitted build 6, which addresses Guideline 4.2.2 with substantial
> native functionality beyond displaying scores:
>
> • A WidgetKit Home Screen / Lock Screen widget showing the user's followed
>   teams' live score or next kickoff, refreshed on a timeline and deep-
>   linked into the app
> • Local kickoff notifications: after following a team, users can enable
>   reminders 30 minutes before each of their teams' games — scheduled
>   entirely on-device, tapping one opens the game
> • A Siri Shortcut ("What's my next game?") built on App Intents
> • Haptic feedback on follows, refreshes, and live score changes; share
>   sheets and context menus throughout
>
> We'd also like to clarify the app's existing depth, which our original
> review notes undersold: StatSide is 100% native SwiftUI (no web views),
> with a team-following system that personalizes the whole app, live
> in-place score updates while games are on, week-based navigation
> purpose-built for college football, and full VoiceOver and Dynamic Type
> support. The app renders structured sports data in a native interface —
> it does not aggregate or display web content.
>
> Nothing changes on the privacy front: no accounts, no tracking, App
> Privacy remains "Data Not Collected."
>
> In the offseason the current week can be quiet; the review notes include
> steps to see the follow → reminders → widget flow and a completed season's
> data. Happy to provide anything else that would help.

## Copyright

`© 2026 Andy Weir`
