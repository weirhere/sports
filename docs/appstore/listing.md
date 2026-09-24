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

Audited at 2.3.0 and unchanged: 2.3.0 adds no league, so the field still names
exactly what the app covers. Audited again at 2.5.0 and unchanged, for the
same reason.

Audited at 2.4.0 and unchanged, with one question asked and answered. 2.4.0
renames college football to **NCAAF everywhere inside the app** — the league
sits beside NFL, NBA and NHL there, and `CFB` was the odd register. The
subtitle deliberately does not follow, for two reasons. It is a *search*
field, and `cfb` and `ncaaf` are two different queries: `ncaaf` is already
indexed from the keywords, so keeping `CFB` here means the listing carries
both, where swapping would leave `cfb` in neither. And
`NCAAF, NFL, NBA and NHL scores` is exactly 30 — the limit this section
already refuses to sit on. The in-app label and the store field answer to
different things, and this is the one place they're allowed to differ.

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

### 2.5.0 (build 19)

> • Stats, for players and teams. A player page has Games, Stats and Career
>   tabs now, with a This season card up top. A team page's Overview shows its
>   season numbers and its leaders, and there's a full Stats tab behind it.
>   Tap a name in a box score and you land on that player.
> • Win probability on football and basketball game pages. Before kickoff
>   it's ESPN's matchup predictor. During the game it moves with every play.
>   After the final it shows what the odds were at kickoff, so an upset looks
>   like one.
> • A Tight filter next to Live: games that are close late, or where the
>   underdog is winning. The ones worth switching to.
> • Betting lines, if you want them. Turn them on in Settings and the spread
>   and over/under show before kickoff, on the Scores page and the game page.
>   They're off unless you switch them on.
> • Settings has a home: the gear at the top of Games. Betting lines and
>   kickoff reminders live there.
> • Hide all / Show all folds everything that isn't yours out of the way in
>   one tap, and it stays that way until you open it again.
> • Leagues are listed A to Z: NBA, NCAAF, NFL, NHL.
> • Smoother everywhere. StatSide runs at 120Hz on ProMotion iPhones now, and
>   switching days does a fraction of the work it used to.
> • Games scroll under the tab bar instead of stopping short of it.
> • Rearranging the leagues you follow takes a deliberate hold now, so
>   scrolling past them doesn't pick one up.
> • Fixed: a league card could get stuck mid-drag and stop the Leagues tab
>   from scrolling.

### 2.4.0 (build 18)

> • Players have pages. Tap a name on a roster, in a search result or on a
>   Leaders card and you get the player: number, position, the vitals, and
>   the team crest as a door through to the team.
> • Search was rebuilt around the thumb. The field sits at the bottom, where
>   your hand and the keyboard already are. Scope pills replace the section
>   headings, and every result is one card at one height.
> • Search remembers. It opens on what you last opened instead of the same
>   empty sentence every time, and a recent you don't want can be dismissed.
> • Players are searchable, across all four leagues at once. College results
>   are checked against the directory, so FBS and FCS are in and Division II
>   isn't.
> • The Leagues tab answers one question. The accordions start closed, so all
>   four leagues fit before you scroll. There's a field to find a league by
>   name that opens what it matched. And the standings that used to ride
>   along in the rows are gone — a row here is a door to a table, not a
>   table.
> • College football reads NCAAF, next to NFL, NBA and NHL. Teams read by
>   their full name — "Tampa Bay Buccaneers", not "Buccaneers" — so a list
>   drawn from four leagues says which team is which.
> • The widget has a refresh button in its footer, and asks for new numbers
>   every five minutes while your team is playing.
> • Tapping Games when you're already on it brings the day back to today,
>   as well as the slate.
> • An NFL game page names the division — AFC North, NFC South — where it
>   named the conference before.
> • A roster lists each group in jersey order.
> • Fixed: a team page with five tabs wrapped its tab labels onto two lines.
>   The row scrolls sideways now instead of squeezing.
> • Fixed: an inactive tab label was too faint to pass contrast.
> • Fixed: the matchup card repeated standings the summary above it was
>   already showing.
> • Fixed: one trophy won under two spellings counted as two rows.

### 2.3.0 (build 17)

> • Trophies. A team page has a Trophies tab — the conference titles, bowls
>   and championships the team has actually won, a row per trophy with the
>   count and the years, back through 2014. Nothing is claimed on a title
>   game that hasn't been played yet.
> • Head to head. Every game page has an H2H tab: the series between these
>   two teams, and each previous meeting as a row you can open. It says
>   which window it counted rather than claiming an all-time record it
>   can't see — ten seasons back in college football, fewer in the leagues
>   where two teams meet more often.
> • Where a team plays. The Overview tab has a Venue card — the ground and
>   its city, the home games played there, and the average attendance.
> • NFL standings are the full spread: W, L, T, PCT, home, away, division,
>   conference, points for, points against, differential and streak. Twelve
>   columns don't fit a phone, so the table scrolls sideways with the team
>   names staying put.
> • The day got easier to move around. The selected day is ink now instead
>   of a filled pill, the calendar sheet opens on the month you're already
>   in, and Today takes the slate home with it — the strip and the scroll
>   both.
> • Live means today. The Live filter applies to today and nowhere else:
>   swipe off and it steps aside, come back and it's on again. Today reads
>   "Ongoing" while it's on, and the active chip wears the live accent.
> • The Top 25 header's name opens the poll, the way a conference header
>   already opened its table. The count and the chevron still just open and
>   close the section.
> • A game page keeps its Game info card after kickoff, instead of hiding
>   it the moment there's a score to show.
> • Widget kickoffs read "Today" and "Tomorrow" on the near days.
> • Fixed: a failed schedule refresh could quietly cancel a game reminder
>   you'd already set. A reminder survives a bad network now.
> • Fixed: a day that failed to load sat under a loading skeleton forever
>   with nothing to tap. It says what went wrong and offers Retry — and in
>   light mode the skeleton is visible while you wait, which it wasn't.
> • Fixed: a season came back short after a change at the source. A Games
>   tab runs the whole season again.

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

Audited at 2.3.0 and left alone. Nothing in it has stopped being true, and
the two candidates that named the release's headline both bought "the series
history" with the concrete "30 minutes" — a vaguer hook for a better-sounding
one. If it wants to carry H2H and trophies later, it can: this is the one
field that changes without a review.

Audited at 2.5.0 and left alone. Every clause is still true, and the
2.4.0 candidate below still reads well if the headline should change.

Audited at 2.4.0 and left alone, on the same trade as 2.3.0. The standing
candidate is now a good one and worth writing down rather than rediscovering:
*"Four leagues, one screen. Find any team, conference or player in any of
them, follow the ones that matter, and get a reminder 30 minutes before they
play. No ads."* (162) — it keeps the "30 minutes" the 2.3.0 candidates spent,
which is why it survives where they didn't. It loses the league names, and
those are what a browsing reader is scanning for. Swap it in if the four
leagues ever stop being the thing worth saying first; no review needed.

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
> • One tap filters to live games, or to the tight ones: close late, or the
>   underdog ahead
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
>   win probability, the head-to-head series, and the plays themselves —
>   drives for football, periods for basketball and hockey
> • Team pages: the record, season stats and leaders, the full season, bye
>   weeks, the roster, the home ground, and the trophies the team has won
> • Player pages: this season's numbers, every game, and the career, reached
>   from a roster, a search, a box score or a game's leaders
> • Optional betting lines: the spread and over/under before kickoff, off
>   unless you turn them on
> • Search any team, conference, game or player — across every league,
>   from a field that sits under your thumb
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

Changed for 2.5.0, in four places. The live-filter bullet names Tight; game
pages gain win probability; team and player pages gain their stats (the
player bullet also names the box score as a way in); and a bullet for the
optional betting lines, worded as off-by-default because that's the fact a
reader deciding whether this is a betting app needs. "Free." in the closer
stays, for the reason in the 2.3.0 note below. The "collects no data"
paragraph stays true: nothing in 2.5.0 sends anything about a person
anywhere.

Changed for 2.4.0, in two places, both because search stopped being a
team-only field: the search bullet now names a player and says where the
field sits, and a Player pages bullet joins Team pages. Nothing else moved —
2.4.0 adds no league and takes nothing away, so the four-league copy 2.2.0
wrote still describes the app.

Audited at 2.3.0 and left alone. The closing line's "Free." survived the
2026-09-19 Guideline 2.3.7 rejection on purpose — that rejection is about
*screenshots*, and Apple's own remedy names the description as where price
belongs. The `08-closer` frame dropped the word; this field keeps it. See
§ Screenshots.

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

Audited at 2.3.0 and unchanged: at 95 of 100 there are five characters
spare, and nothing 2.3.0 added is a term this audience types into search —
nobody looks for an app by "head to head" or "trophies".

Audited at 2.5.0 and unchanged. The release's new surface is stats, and
`,stats` (6) still doesn't fit in the five spare characters. Nothing here
stopped being true.

Audited at 2.4.0 and unchanged. `ncaaf` was already here and now matches what
the app calls the league on screen, which is luck rather than planning. The
release's new surface is players, and the candidate terms don't fit: five
characters spare takes neither `,roster` (7) nor `,stats` (6), and `stat` is
indexed from the app name anyway. Nothing here has stopped being true, so the
honest move is to spend nothing.

Changed for 2.2.0: `basketball`, `hockey`, `standings` and `box score` in;
`rankings`, `schedule`, `sec` and `big ten` out. The two sport words are the
ones a basketball or hockey fan actually types, and they have to come from
somewhere. `standings` replaces `rankings` because three of the four leagues
have no poll, `top 25` already carries the one that does, and the box score is
the surface Josh's feedback named as the reason he opens a game page.

## URLs

- Support URL: `https://statside.co/support`
- Privacy Policy URL: `https://statside.co/privacy`
- Marketing URL: optional, leave blank

**Both changed on 2026-09-13 and both fields need updating in App Store
Connect** — the old pair (`weirhere.github.io/statside-site/…`) is a 404 and
has been for some time: that repo went private, so Pages stopped serving,
and nothing noticed because nothing checks a listing field. The live
listing's Privacy Policy link was dead.

They are routes in `web/` now — `/privacy` and `/support`, prerendered
static, on the app's own domain and its own deploy. No copy step between two
repos: the policy's text is `PRIVACY.md` at the repo root, mirrored into
`web/src/content/privacy.ts` under a test that fails Web CI if the two ever
differ. `weirhere/statside-site` holds nothing that isn't here and can be
archived.

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

### 2.5.0: carried forward a third time

Andy's call at the cut: the reshoot is still booked for late October, when the
NBA and NHL open. Nothing in the frames became false in 2.5.0. They just miss
more: the Settings gear on the Games header, the Tight chip, win probability,
player and team stats, and the optional lines. The October pass should shoot
the Games header as it now stands (Live · Tight · calendar, gear), a game page
with the Win probability card, and a player page's Stats tab, on top of the
2.3.0/2.4.0 debt listed below. Don't shoot a frame with betting lines turned
on: it's an off-by-default feature and shouldn't be what the listing leads
with.

### 2.4.0: carried forward a second time, and the staleness is now compounding

**Andy's call at the 2.4.0 cut, on schedule rather than merit** — the same
reasoning as 2.3.0, and the October reshoot it defers to is still booked for
when the NBA and NHL open. Recorded here because the gap is wider than it was
and the next cut should not have to rediscover how wide.

Nothing in the set is *false*. 2.4.0 adds no league, removes nothing a frame
shows, and carries no price reference. What has drifted is the chrome:

- the selected day is still a filled black pill in `01-hero` and
  `03-saturdays` — stale since 2026-09-12, waived at 2.3.0, waived again
- team names now read in full ("Tampa Bay Buccaneers"), so followed cards,
  the team-page hero and the Add teams rows in `02-follow` all render
  differently than they're shown
- a team page's tab row scrolls now instead of sitting fixed, and college
  football is labelled NCAAF wherever the league is named

And the release's headline appears in **no frame at all**: the rebuilt search
and the player page are both unshot. That is the strongest argument for the
October pass carrying more than a basketball slate — it should add a search
frame and a player frame alongside the NBA/NHL hero, on top of 2.3.0's
still-outstanding Trophies and H2H.

### 2.3.7 rejection (build 17) — the closer frame said "Free"

**Rejected 2026-09-19** under Guideline 2.3.7 (Accurate Metadata): "The app
screenshots include references to the price of the app or the service it
provides." Apple's note spells out that free counts — "references to free or
discounted services are considered a price reference."

One frame was the cause. `08-closer` read **"Free. Fast. / Four leagues, done
right."** and that first word is the whole violation. It now reads **"Fast.
Focused. / Four leagues, done right."** — the two words `CLAUDE.md` already
uses for what the product is ("speed and focus are the product"), so the frame
keeps its rhythm and loses the price claim.

**What was checked and deliberately left alone:**

- `01-hero`'s pill, "Live scores · No ads · No account". 2.3.7 is about price,
  and an ad-free experience is a description of the product, not of what it
  costs. Same for `07-quiet`'s four pills. If a future reviewer disagrees,
  the fix is the same one-word class of edit and it's cheap.
- The **Description**'s "Free. Fast. Four leagues, done right." stays. Apple's
  own next step says price belongs there: "If you would like to advertise
  changes to the app's price, consider including this information in the app
  description." So the description and the closer frame now say different
  things on purpose, and that divergence is the point rather than a drift.
- `docs/social/`'s own closers (`07-closer.html`, `story-07-closer.html`) keep
  "Free." They're Twitter and Stories graphics, not App Store metadata, and
  nothing stops an app advertising its price off the store. (They do still say
  "One sport, done right," which the 2.2.0 pass fixed in the App Store frames
  and not in these. Stale, but stale about leagues, not price.)

**No new build needed.** Screenshots are metadata. The version goes back to an
editable state after a rejection, so replacing the 08 frame and resubmitting
is the whole job — build 17 stands.

**The first re-render came off Linux; the shipping one came off the Mac.**
`social.css` points `@font-face` at Andy's Dropbox copy of Inter, which a CI or
cloud session doesn't have, so the render in the rejection-fix commit used the
Google Fonts Inter variable TTF under headless Chromium. The layout and the zoom
reflow were exactly right (icon crop pixel-identical, mean delta 0.3/255), but the
glyph edges on "StatSide" and the fine print came from a slightly different Inter
cut than frames 01–07 — invisible side by side, and still not what the rest of
the set is made of.

**Re-rendered on the Mac 2026-09-19** with the real Dropbox Inter, per
`docs/social/README.md` § Regenerating, and that is the version in the repo now.
Both sizes land on their exact required dimensions (1284×2778 and 1320×2868 —
anything else and the drop zone rejects it), the copy carries no price reference,
and the diff against the Linux render is a mean 1.2/255 confined to the text band:
same layout, matched glyphs. Nothing to redo before upload.

### 2.3.0: carried forward, with one frame knowingly stale

Not reshot. Andy's call at the cut, and the reasoning is a scheduling one
rather than a claim that the set is current.

**What went stale.** The frames were captured 2026-09-11; the day strip's
selected day became ink instead of a filled capsule on 2026-09-12. So
`01-hero` and `03-saturdays` both show "Sat, Sep 5" as a black pill the app
no longer draws. That is the chrome-changed trigger for a reshoot, and it is
the only thing in the set the release falsified — no frame makes a claim
2.3.0 broke, and the copy is untouched.

**Why it waits.** The set is already booked for a full reshoot in late
October, when the NBA and NHL seasons open and basketball and hockey can
appear in a slate frame for the first time — the thing the 2.2.0 note left
open. Shooting now would mean shooting twice in five weeks to fix a capsule.
The cheaper miss is the stale pill.

**Worth doing in that October pass**, beyond the league frame: 2.3.0's own
new surface can be shot on football teams that are in season — a team page's
**Trophies** tab and a game page's **H2H** tab, neither of which appears in
any frame today.

### 2.2.0: reshot, but still football

The eight frames were **recaptured and re-rendered on 2026-09-11** against
2.2.0. Two things were wrong with the 2.0 set and only one of them is fixed.

**Fixed — the copy, and the captures.** Five frames said things the release
made false: `01-hero` ("College football and the NFL" / "Both leagues"),
`02-follow` ("either league"), `08-closer` ("Two leagues, done right", plus a
disclaimer naming only the NFL and the NCAA), and the weekend framing on
`03-saturdays` and `04-week`, which stopped being the promise once the NBA and
NHL brought most nights from October to June. And the device shots underneath
were the 2026-09-05 set, showing a tab bar reading "Scores | Tables | Teams",
undated day chips, Today inside the strip, one "College Football" accordion,
and the retired field glyph. Seven masters reshot; `07-widget` untouched,
since it is a manual springboard capture that no store frame composites.

**Still open — no basketball or hockey appears in any frame.** The slate
frames are Saturday, September 5 and the NFL's opening Sunday, because those
are the days that exist: the NBA and NHL regular seasons do not open until
late October, Scores is bounded by the current day, and a day strip today has
empty sections for both. Reshoot `01-scores` and add a league frame once
either season is under way.

What the reshoot did buy: the **Roster** tab and game detail's **Plays** tab
are both in the set now, without anything being staged for them. The release's
own features could not appear in a September 5 capture, which is the argument
for reshooting at a cut rather than carrying frames forward by default.

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
backend. *(Re-read at 2.5.0: still true. The Live Activity channel service
now exists at statside.co, but this build never calls it: Live Activities are
gated off, and even when on, it's asked for a game's channel with a game id
and a league, never anything about a person. See `PRIVACY.md`.)* Followed teams and UI state are stored only on-device in UserDefaults.
Score data is fetched anonymously over HTTPS.

## Age rating questionnaire

All content questions: **None** (no violence, gambling, etc. — sports scores).
Unrestricted web access: **No**. Gambling: **No**. Result: **4+**.

**Re-read at 2.5.0 — Andy's call in ASC.** 2.5.0 adds *optional betting
lines*: the pre-game spread and over/under, off by default, switched on in
Settings. They're informational only. There's no wagering, no real or
simulated gambling, no sportsbook name or logo, no odds beyond those two
numbers, and no link to a betting service. The expectation is that the
gambling question stays **No**, since it asks about gambling, not about
printing a line. But the questionnaire wording has changed before, so read
it against the feature rather than against this note.

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

**Reviewer-timing note, still current at 2.4.0 (September 2026).** College
football and the NFL are in season; the NBA and NHL regular seasons do not open
until late October. A reviewer opening the app today sees football on the day
strip and empty slates for basketball and hockey, which is the season and not a
defect. The Leagues tab shows all four with their tables, and a past season on
an NBA or NHL team page shows a full schedule — that is the fastest way to see
basketball and hockey carrying real data.

**Notes audit at 2.5.0: one addition, pasted after the demo paragraph.**
2.5.0 adds no capability that needs declaring: no new entitlement, no
account, nothing collected. One feature is worth saying out loud before a
reviewer finds it, and it goes in the submission as:

> Settings (the gear at the top of the Games tab) includes an optional
> "Betting lines" switch, off by default. When on, it shows the pre-game
> point spread and over/under as plain text on the scores list and the game
> page. It's informational only: no wagering, no sportsbook branding or
> links, and nothing to buy or place.

Demo paths for the release: any finished football game → Summary → Win
probability; the Tight chip on the Games header during a live game; a
player's name in a box score → Stats. Live Activity code is in the build but
**gated off**, so there's nothing for a reviewer to find and nothing to
declare yet.

**Notes audit at 2.4.0: no rewrite needed.** 2.4.0 adds no capability that
needs declaring — no new entitlement, no account, no data collected, no web
view. It rebuilds the search surface, gives players a page of their own and
finishes the Leagues tab, all of which are screens rather than permissions.
The opener still leads with following teams, which is still what the app is
built around. One demo path worth naming, because it is the release and it is
two taps: **Search → type a player's name → open the result**, which reaches
a player page from a cold start with no team followed first.

**Notes audit at 2.3.0: no rewrite needed.** Every native surface listed is
still in the build and nothing 2.3.0 added contradicts the opener. The release
adds depth to existing screens — a Trophies tab and an H2H tab, a Venue card,
the NFL's full standings spread — rather than a new capability that needs
declaring. Two demo paths worth naming if the reviewer wants the new surface:
any team page → Trophies, and any game page → H2H.

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

## 2.3.7 rejection (build 17) — Resolution Center reply ✏️

Sent in-thread in App Store Connect with the replaced screenshot. Same tone as
the 4.2.2 reply below: don't argue, say what changed.

> Hello, and thank you for the review.
>
> You're right. The final screenshot read "Free. Fast. Four leagues, done
> right," and that first word is a price reference. We've replaced that
> screenshot. It now reads "Fast. Focused. Four leagues, done right," and no
> screenshot in the set references price, free service, or a discount.
>
> No other metadata changed and the binary is unchanged, so build 17 is the
> build we'd like reviewed.
>
> Happy to make any further adjustment if something else in the set reads as a
> price reference to you.

## Copyright

`© 2026 Andy Weir`
