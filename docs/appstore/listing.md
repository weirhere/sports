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

## Promotional text (170 chars max — editable anytime without review) ✏️

> Kickoff is coming. Follow your teams now and be ready for Week 1 — live
> scores, rankings, and every conference at a glance. (125)

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
Order suggestion: scores (hero) → game detail → rankings → teams → team page.

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

> StatSide displays publicly available college football scores and rankings.
> No login is required — the app is fully browsable on launch. In the
> offseason the current week may show few or no games; use the season picker
> (top right of the Scores tab) to view the completed season.

## Copyright

`© 2026 Andy Weir`
