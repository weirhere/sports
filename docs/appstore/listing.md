# StatSide — App Store listing

Everything App Store Connect asks for, drafted. Character limits noted where they exist.
Fields marked ✏️ are Andy's-voice drafts — edit freely; nothing here is load-bearing.

## App name (30 chars max, must be unique on the store)

1. `StatSide` (8) — taken at 1.0, keep it.
2. `StatSide — Football Scores` (25) — fallback

The 1.0 fallbacks named college football (`StatSide — CFB Scores`,
`StatSide: College Football`). They stopped being fallbacks at 2.0, when the
NFL joined — a name that names one league is worse than no fallback.

## Subtitle (30 chars max) ✏️

`CFB, NFL, NBA and NHL scores` (28)

Alternates:
- `CFB, NFL, NBA, NHL at a glance` (30) — keeps the 1.x promise, but sits
  exactly on the limit, so any counting difference in ASC rejects it
- `Four leagues, at a glance` (25) — keeps the promise, names nothing, and
  spends no characters on search

Rewritten for 2.2.0. "CFB and NFL, at a glance" named half the app the moment
basketball and hockey landed. Naming all four costs the "at a glance" promise,
which is the trade taken on purpose: the subtitle is indexed and the promise
is not, and a four-league app that reads as a football app in search is the
more expensive miss. The league abbreviations stay jargon, and stay the jargon
this audience searches with.

## Category

Primary: **Sports**. No secondary needed.

## What's New in This Version (4000 chars max) ✏️

Per-version release notes. Newest first — keep the old ones, this is the
release-notes history now.

### 2.2.0 (build 16)

> • Basketball and hockey. The NBA and the NHL join college football and the
>   NFL — same day strip, same Following section, same widget, same reminders
>   30 minutes before your teams play. StatSide has no offseason now: the
>   season runs July through June.
> • Each league keeps its own language. NBA standings show wins, win
>   percentage and games back; the NHL's show games played, W-L-OTL and
>   points. Overtime is called overtime and a shootout is called a shootout.
>   Nothing invents a down or a drive for a sport that hasn't got one.
> • A basketball or hockey game page has its line score, its leaders, its
>   box score, and its plays grouped by period.
> • Rosters. Team pages have a Roster tab — the head coach, then every
>   player by position, with the number, the height and weight, and the
>   class year or the age.
> • Tables is now Leagues. Same hub, truer name: what it lists is leagues,
>   and a conference or a poll is reached through one. The NBA and the NHL
>   list their divisions there, each wearing its conference's mark.
> • A game that hasn't kicked leads with the time it does. The kickoff takes
>   the big slot between the crests — the one a score fills the moment there
>   is one — with the date and the network beneath it.
> • A game page says which tables it counts toward. The league and both
>   conferences ride the top of Game info as badges you can tap, so the
>   standings are one tap from the game instead of three.
> • Where a game is played got a card of its own, so the kickoff and the
>   stadium stopped sharing one.
> • A Games tab now runs to the end of the season. Hockey's used to stop in
>   January, and nothing said so.
> • Fixed: opening a team from search or from the widget could show you
>   another team's schedule, next game and record under the right crest.

### 2.1.1 (build 15)

> • Fixed: games with a kickoff time still to be announced showed up a day
>   early for everyone outside Eastern time. A Saturday game landed on
>   Friday in Central, Mountain, Pacific, Alaska and Hawaii — on the day
>   strip, on team schedules, in shares and in the widget. They sit on the
>   right day now.

### 2.1 (build 14)

> • Playoff brackets. The NFL's league page and the Top 25 each have a
>   Postseason tab that draws the bracket instead of listing it — who plays
>   whom, round by round, with a bye shown where a team sat one out. Swipe
>   between rounds.
> • Scores goes back to conferences. College football breaks down the way you
>   already think about it — the SEC, the Big Ten, the Big 12 — instead of one
>   sixty-row list. The NFL's Sunday stays one section, because that's the
>   whole slate at a glance.
> • Follow a conference and its table moves up. Following stays your teams; a
>   conference or poll you follow now rides directly beneath it instead of
>   pouring another eight games in.
> • Drag your tables into the order you want. Rearrange them in Tables and the
>   Scores page follows suit.
> • Jump to any day. A calendar opens beside the day strip, so a game in
>   November is one tap instead of a long drag — and Today floats over the
>   slate whenever you've wandered off.
> • Swiping between days works over the games again. A swipe that started on
>   a game row used to open that game instead of moving the day — which on a
>   Saturday, when the screen is nothing but games, was most of the screen.
> • NFL standings, three ways. See the whole league, a conference, or a
>   single division. An AFC or NFC division page has its table back, too.
> • The preseason gets its own cards. The Hall of Fame Game and the preseason
>   weeks sit apart from the games that count, on team pages and league pages
>   both.
> • The FCS lives inside College Football in Tables now — one card, FBS
>   conferences and then FCS ones. It's all college football.
> • Conference standings mark the championship cut, so you can see at a glance
>   which teams are playing for the title.
> • Search says which league a team plays in. Every result carries it now,
>   not just the searches that turn up both — one "Cleveland Browns" tells
>   you nothing about which football you found.
> • Day chips carry their month, and yesterday and tomorrow are named the way
>   you'd name them.
> • Fixes: searching "Browns" no longer opens UAB, the AP/Coaches poll picker
>   works, and NFL kickoff times stopped getting cut off in the widget.

### 2.0 (build 13)

> • The NFL is here. Follow your NFL teams alongside your college ones —
>   they share the Following section, the widget, and your kickoff reminders.
> • Scores is a day at a time now. College football and the NFL each get
>   their own section on the day you're looking at, so a Saturday and a
>   Sunday both read the way they actually happen. Swipe for the next day,
>   or jump back with Today.
> • Tables covers both: the Top 25 and every college conference, the AFC and
>   NFC and their divisions, and the whole NFL in one table.
> • Teams is your list now. It holds the teams you follow; Add teams opens
>   the whole directory — both leagues — with the popular ones up front.
> • Search tells them apart. Two Cincinnatis, two Miamis: results say which
>   league each one is.
> • The FCS has its own card in Tables, so following a conference there is
>   one tap from the hub.
> • Bye weeks show up on NFL team schedules instead of a silent gap between
>   two week numbers.
> • The whole Sun Belt was missing from Teams and search. It's back — all 14.

### 1.4.0 (build 12)

> • Box scores. Every game page now has a Box score tab — passing, rushing,
>   receiving, and defense for both teams, live from the first drive and
>   complete when the game ends.
> • Scoring plays say who scored. The team's mark leads the row and the
>   scoring side's number carries the weight, so you can read a drive without
>   matching player names against the leaders.
> • FCS, when you want it. Every FCS team has a page now, and they're in
>   Teams and in search. Filter to an FCS conference — or follow one — and
>   its games join your slate. Leave it alone and the slate stays FBS.
> • Sharing a game carries the matchup card as the link preview, so the
>   thread shows the game instead of a stock picture of the app.
> • The Leaders card went two-sided, with player headshots on the outer
>   edges — each player sits on their own team's side of the header.
> • Live scores reach further: a conference's Games tab keeps updating while
>   you watch it, and Siri stopped reading out a score it doesn't have.
> • Team and conference pages got a cleaner header. It matches the cards now,
>   with back, follow, and share on one row, and the season picker sits with
>   the games it filters.
> • Live and final games lead with one big score between the logos, and the
>   venue is back on the game page.
> • A game at the break reads "Half" instead of a stopped clock at 0:00.
> • The widget's scores line up in one column, and "Following" stopped
>   truncating in the team-page toolbar.
> • Scores got lighter under the thumb — swiping between weeks and scrolling
>   a full Saturday slate both cost less than they did.

### 1.3.1 (build 11)

Note 2026-09-05: three bullets below shipped in **1.4.0**, not this build.
The archive was cut at 11:13 on 8/31 from the same tree as these notes, and
the cleaner entity-page header, the centered big score, and the "Half" label
all merged that afternoon. They're repeated in 1.4.0's notes, where they're
true. Left as written here because this section is release history — and as
a reminder that notes written before the archive can outrun it.

> • Team pages open on a new Overview tab: the next (or current) game up top,
>   with the season's conference and overall records right under it.
> • Swiping between weeks on Scores now shows the neighboring week's real
>   games mid-swipe instead of placeholders, and the new week lands instantly.
> • Dark mode got a retune: cards and sheets now sit visibly above the black
>   background instead of blending into it.
> • Team and conference pages got a cleaner header. It matches the cards now,
>   with back, follow, and share on one row, and the season picker sits with
>   the games it filters.
> • Switching tabs on team and conference pages slides the right way every time.
> • A game at the break reads "Half" instead of a stopped clock at 0:00.
> • Live and final games lead with one big score between the logos.
> • Box scores fill their card edge to edge with bigger, easier-to-read
>   numbers.

### 1.3.0 (build 10)

Note 2026-09-01: the team-colors line below describes the hero that retired
on 2026-08-31 (headers match the cards now). It stays as written if build 10
actually shipped, since this section is release history. If it never went
up, fold the still-true bullets into 1.3.1 and drop that one.

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

> Four leagues, one screen. Follow your college football, NFL, NBA and NHL
> teams, see what's live, and get a reminder 30 minutes before they play.
> No ads. (155)

Rewritten for 2.2.0: the 2.0 line said "Saturday and Sunday", which is two
days of a week the app now covers most of. "Before they play" replaces
"before kickoff" — the reminder is league-agnostic and three of the four
leagues don't kick anything. This field is editable without review, so it
should never be the stale one.

## Description (4000 chars max) ✏️

> StatSide is college football, the NFL, the NBA and the NHL, at a glance. One
> screen answers "what's happening right now" — no ads, no interstitials,
> nothing between you and the scores.
>
> BUILT FOR GAME DAY, ALL YEAR
> • Your teams first: follow any team in any of the four leagues and their
>   games lead the page, together
> • One day at a time, every league stacked — college football broken down
>   the way you think about it, by conference, and the NFL, the NBA and the
>   NHL each in a section of their own
> • Live games get a pulsing dot, heavier type on the score, and possession
>   where the sport has it
> • One tap filters to live games only
>
> YOUR TEAMS, EVERYWHERE
> • A Home Screen and Lock Screen widget with your teams' live score or next
>   game, from every league you follow
> • Reminders 30 minutes before your teams play
> • Ask Siri "What's my next game?" — or share a score straight from any game
> • Long-press any game to follow a team or share the score
>
> LEAGUES, TABLES AND TEAMS
> • AP Top 25 and Coaches Poll, with movement arrows
> • Every FBS conference, the FCS, the AFC and NFC and their divisions, and
>   every NBA and NHL division — each table in its own league's terms
> • Game pages: line score, box score, scoring plays, team stats, leaders,
>   and the plays themselves — drives for football, periods for basketball
>   and hockey
> • Team pages: the record, the full season, bye weeks, and the roster
> • Search any team, conference or game — across every league
> • Browse past seasons back to 2014
>
> DESIGNED QUIET
> Black, white, and team logos in full color. No banner ads, no autoplay video,
> no account, no tracking. StatSide collects no data — your followed teams
> live on your phone and nowhere else.
>
> Free. Fast. Four leagues, done right.
>
> StatSide is an independent app and is not affiliated with or endorsed by the
> NFL, the NBA, the NHL, the NCAA, or any conference, team or school.

Rewritten for 2.2.0. Four things in the 2.0 copy stopped being true:

- **"college football and the NFL"** named half the app, in the opening line
  and again in the closing one ("Two leagues, done right").
- **"BUILT FOR SATURDAYS AND SUNDAYS"** was the football week. The NBA and the
  NHL play most nights from October to June, so the heading is the year now.
- **"both leagues stacked"** described a two-accordion Scores page. College
  football breaks down by conference as of 2.1, and there are four leagues on
  the day.
- **"kickoff reminders"** and **"next kickoff"** are football words for a
  league-agnostic feature. The disclaimer named only the NFL and the NCAA.

Kept deliberately: the drive log is still named, because it is still there for
football and nothing pretends a possession is a drive elsewhere; and the "no
data" paragraph is unchanged, because nothing in this release collects any.

## Keywords (100 chars max, comma-separated, no spaces needed after commas)

`college football,scores,live,standings,top 25,ncaaf,basketball,hockey,box score,playoff,afc,nfc` (95)

Don't repeat words already in the name/subtitle — they're indexed
automatically. That is why `cfb`, `nfl`, `nba` and `nhl` are *not* here: all
four are in the subtitle, so repeating them would spend characters on nothing.

Changed for 2.2.0: `basketball`, `hockey`, `standings` and `box score` in;
`rankings`, `schedule`, `sec` and `big ten` out. The two sport words are the
ones a basketball or hockey fan actually types, and they have to come from
somewhere. `standings` replaces `rankings` because three of the four leagues
have no poll, `top 25` already carries the one that does, and the box score is
the surface Josh's feedback named as the reason he opens a game page.

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
replace them when the shots themselves change. Note that the promo PNGs in
`docs/social/` crop into these masters at hardcoded pixel offsets, so
reshooting means re-rendering those too (see docs/social/README.md).
Order suggestion: scores (hero) → **widget on the Home Screen** → game detail
→ rankings → teams → team page. The widget frame is captured manually from
the simulator (springboard is outside the UI test's reach) — it's the
reviewer's first visual evidence of native functionality, put it second.

### What actually goes up

The plain shots above are the masters; the store listing uses the *marketing*
frames built from them — device on a black stage, one headline apiece:

- `docs/appstore/screenshots-marketing-1284x2778/` — the 6.5" slot, eight PNGs
- `docs/appstore/screenshots-marketing-1320x2868/` — the same eight at 6.9"

Reshot 2026-09-06 for 2.0 against a live Saturday. Still eight frames; what
changed is the app under them — the day strip, the league accordions, Tables,
and Teams-as-a-follow-list. Both sizes render from the same
`docs/social/src/as-*.html` sources — see that README for the `?69` flag.

**Masters renumbered at 2.0.** The automated set is `01-scores`,
`02-game-detail`, `03-box-score`, `04-rankings`, `05-teams`, `06-team-page`
— what `AppStoreScreenshots` shoots, in the order it shoots them. Two more
are captured by hand or by a second run:

| File | How |
|---|---|
| `07-widget.png` | Manual — springboard is outside the UI test's reach |
| `08-nfl-sunday.png` | A second run with `SCREENSHOT_DAY` + `SCREENSHOT_PREGAME` |

`08-nfl-sunday` exists because the hero can only be one day, and a Saturday
is college football alone. The 04 frame ("Saturday. Then Sunday.") carries
the NFL, shot on an upcoming Sunday.

**Two things about shooting the NFL before its season starts.** There is no
played NFL game anywhere Scores can reach — the strip is bounded by the
current season and Scores has no season control since the view-options sheet
retired — so that frame is a slate of kickoff times, which is the honest
picture of a Sunday morning. `SCREENSHOT_PREGAME` waives the "must have
scores" assertion and stops after the slate, since everything below it needs
a played game. Reshoot it once the season is under way and it will carry real
scores.

### 2.2.0: the set is still football

The eight frames are the 2026-09-06 set — college football and the NFL. The
release's headline is basketball and hockey, and **neither appears in a single
screenshot**. That is a real gap on the product page, and it is a deliberate
open question rather than an oversight, because of what can and cannot be shot
in September:

- **The hero cannot show them.** Scores is bounded by the current day and has
  no season control (the view-options sheet retired 2026-09-05), and the NBA
  and NHL regular seasons do not open until late October. A day strip today
  has empty basketball and hockey sections, which is the honest picture and a
  bad screenshot.
- **The other surfaces can.** The Leagues tab lists all four leagues today
  with real tables, and a league or team page's season chip reaches a finished
  NBA or NHL season — full schedules, real standings, real box scores. So a
  Leagues frame and an NBA or NHL team-page frame are both shootable now.

Two ways to close it, and it is Andy's call which:

1. **Reshoot two frames now** — Leagues (all four) and an NBA or NHL team page
   on a past season — and carry the other six. Costs a capture run plus
   re-rendering those marketing frames and the `docs/social/` crops that read
   the masters at hardcoded offsets.
2. **Ship the football set and reshoot at tip-off.** Screenshots carry forward
   automatically on a version update, and late October gives a live slate that
   shoots the hero properly too.

**Warm the logo cache first.** A capture run against a fresh install shoots
before the team marks have downloaded, and every logo lands as an empty grey
disc — which is fatal, since logos-in-colour is the app's whole visual
signature. Run the suite twice and keep the second set.

The env knobs, all `TEST_RUNNER_`-prefixed on the xcodebuild command line:

- `SCREENSHOT_DAY` — a day chip's spoken label, e.g. `"Sunday, September 13"`
- `SCREENSHOT_FOLLOWS` — argument-domain array, e.g. `"(cfb:130, nfl:26)"`;
  the teams worth seeding depend on the day being shot
- `SCREENSHOT_PREGAME` — allow a day nobody has played yet

`07-widget.png` is still the 1.4.0 capture and shows college football only.
The widget carries both leagues since 2.0, so it wants a reshoot — it is not
one of the eight uploaded frames, so it does not block a submission.

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

Rewritten 2026-08-04 for the 4.2.2 resubmission; league names refreshed for
2.2.0. Leads with what the user does and the native surface area; never
self-describes as displaying aggregated content.

> StatSide is a fully native SwiftUI app built around following your teams
> across college football, the NFL, the NBA and the NHL. Follow a team (Teams
> tab) and the app personalizes around it: a Following section leads the games
> page with your teams from every league together, and you can turn on game
> reminders — local notifications 30 minutes before each of your teams' games,
> scheduled on-device.
>
> Native functionality in this build:
> • Home Screen and Lock Screen widget (WidgetKit) showing your teams' live
>   score or next game across every league you follow, with deep links into
>   the app
> • Local game reminders with deep links to the game
> • Siri Shortcut / App Intent: "What's my next game?"
> • Live scores that update in place every 30 seconds while games are on,
>   with haptic feedback on score changes
> • Share sheets, context menus on every row, full Dynamic Type and
>   VoiceOver support, light/dark mode
> • No web views anywhere; every screen is native SwiftUI
>
> To demo: follow any team from the Teams tab (Add teams → any of the four
> leagues), then enable the bell on its team page (game reminders) and add the
> StatSide widget to the Home Screen. The day strip on Games walks any day of
> the season, and the season picker on a league or team page reaches past
> seasons with full live-style data — useful if the current day is quiet. No
> login required. The app collects no data (App Privacy: Data Not Collected).

**Reviewer-timing note for this build.** It is submitted in September: college
football and the NFL are in season, and the NBA and NHL regular seasons do not
open until late October. A reviewer opening the app today sees football on the
day strip and empty slates for basketball and hockey, which is the season and
not a defect. The Leagues tab shows all four with their tables, and a past
season on an NBA or NHL team page shows a full schedule — that is the fastest
way to see the new leagues carrying real data.

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
