# Web parity ledger

**What this is.** `web/` and the iOS app are two implementations of one product.
Nothing in the build couples them, so the web silently falls behind every time an
iOS PR lands. This file is the coupling: one row per iOS decision that has a web
consequence, with a status. A row is only "done" when the behavior is on
statside.co, not when it's understood.

**How to use it.** Every iOS PR that changes user-visible behavior adds a row
here — `pending` — at the same time it adds its row to CLAUDE.md's decisions log.
That is the whole rule. The catch-up waves below burn the pending rows down.

**Enforced.** `scripts/check-parity-ledger.sh` runs as the first step of the Web
CI job: a branch that grows the decisions log without growing this file fails.
It counts rows, not meaning — it cannot tell whether the row you added is the
right one, only that you stopped and wrote one, which is the part that was
missing. `[skip-parity]` in a commit message is the escape hatch, for iOS work
with genuinely no product surface. It rides the existing Web CI check rather
than standing as its own so it blocks a merge with no branch-protection change.

**Statuses**
- `shipped` — live on web, matching the iOS decision.
- `pending` — the iOS decision stands; the web hasn't caught up.
- `n/a` — no web analog, deliberately. Recorded so parity is measurable rather
  than aspirational: an unported row and an inapplicable one are different debts.
- `differs` — web does it differently on purpose. Must say why.

**`n/a` categories, decided once so they aren't re-argued per row:** the widget
extension, local notifications and their permission flow, Siri/App Intents,
haptics, Liquid Glass, the iOS share sheet and `LPLinkMetadata`, XCUITest
infrastructure, `project.pbxproj`, App Store release mechanics, and the
`statside://` deep-link scheme (the web's URLs *are* its deep links).

---

## Where the web actually stands (audited 2026-09-09)

The web was last brought to parity on **2026-09-01** (parity waves P2–P12,
commits `b54903b`…`a9ee85d`). Since then iOS has merged ~35 PRs carrying **89
decision rows**. One of them shipped on web — the OpenGraph card (#109) — and it
was built web-first.

Put plainly: **`web/` was StatSide 1.x; W1 and W2 have landed.** The dividing line is the
league axis. The web app is hardcoded to one league:

- `src/lib/constants.ts` pins `ESPN_API_BASE` to `football/college-football`.
- `src/lib/types.ts` has no `league` field anywhere; its axis is
  `Division = "FBS" | "FCS"` and `week: number`.
- `src/lib/espn/endpoints.ts` sends `groups=80` and `week={n}` — the week
  scoreboard iOS retired on 2026-09-05.
- The tab bar is `Scores / Rankings / Teams / Search` — the 1.x set.
- `conferenceGamesUrl` still fetches a season with a bare `dates={year}`, which
  is the bug iOS fixed on 2026-09-05 (a bare year is the *calendar* year: it
  opens the slate with last January's bowls and truncates before December).

Nothing below is a small fix. The league axis has to land before most of it can.

---

## W1 — The league axis  ✅ shipped 2026-09-09

Everything else depends on this. `League` is not a filter bolted on top; it is
the namespace ESPN ids live in, and its absence was already a live bug class on
web: ESPN team id 5 is both UAB and the Browns, id 2 is both Auburn and the
Bills, and group 8 is both the SEC and the AFC.

Verified live against all four leagues: an NHL day window returns 34 games with
`week` absent (not 0) and the conference reading "Atlantic (Eastern)"; an NBA
window returns 40 with "Southeast (Eastern)"; an NFL window returns 14 at week 1
with Cincinnati placed in "AFC North" from the hardcoded registry.

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-08 | `League` gains a sport segment and a league segment; all four base URLs derive from it | shipped |
| 2026-09-08 | Season-year translation — NBA/NHL name a season by the year it *ends*; our axis stays the opening year, translated at the query string only | shipped |
| 2026-09-08 | `Conference` becomes one `Registry` per pro league; `Tier.conference`/`.division` | shipped |
| 2026-09-08 | Hardcoded team→division maps (pro scoreboards ship no group id at all) | shipped |
| 2026-09-06 | Team routing is league-qualified end to end (`TeamRef`); search results key on `followKey`, never a bare id | shipped |
| 2026-09-08 | `SeasonYear.year(for:)` — entity pages read the season on their own league's clock | shipped |
| 2026-09-08 | `leagues[].calendar` decoded leniently; `leagues` becomes a lossy array | shipped |
| 2026-09-08 | A box-score category no longer requires a name (basketball ships `name: null`) | shipped — W5a |
| 2026-09-05 | A season's slate is fetched by date window, never `dates={year}` | shipped |
| 2026-09-08 | TBD kickoffs re-anchored to their Eastern day at the mapper | shipped |
| 2026-09-08 | `League.canTableAWholeSeason` — don't fetch a season for a >1000-game league | shipped |
| — | FCS: honor the existing `Division` type instead of hardcoding `"FBS"` (E8 P2) | shipped |
| 2026-09-06 | Team pages fetch the preseason (`seasontype=1`, a third parallel request) | shipped — the fetch; the per-phase Games cards are W4 |
| 2026-09-09 | Surface is only a fact where the game is played on one (no "Turf" on a rink) | shipped |
| 2026-09-08 | Per-league leader categories, with the payload's own as the fallback | shipped |

**Not a parity row, fixed on the way:** `conferenceGames` fetched a season with a
bare `dates={year}` — the *calendar* year, which opened the slate with the
previous January's bowls and truncated before December. It now asks for the
season's own span, split at November 1 so ESPN's silent 900-event truncation
can't bite.

**Deliberately not moved:** `/game/{id}` links published before the axis. That
URL is what the OpenGraph card shipped on, so it exists in Slack unfurls and
pasted threads. `next.config.ts` redirects the three bare-id entity routes to
college football's — exact, not a guess, since that was the only league the web
app had — and unfurlers follow 3xx and read the destination's og: tags.

## W2 — Scores  ✅ shipped 2026-09-09

Verified live: the strip runs July 1 → June 30 (the NFL's Hall of Fame floor
to the NBA/NHL's June), a Saturday shows 11 college-football conference
sections in tier order plus the NHL's preseason, following Michigan and the
Big Ten puts Following first and *moves* the Big Ten section up rather than
cloning it, and picking 2019 lands on August 1 — the Hall of Fame Game — via
the snap-forward probe rather than on the season's nominal July start.

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-05 | **The day replaces the week as the unit of time**; `DayStrip`, swipe = ±1 day | shipped |
| 2026-09-05 | Five-day `dates=` window per league, centred on the shown day | shipped |
| 2026-09-05 | Section assembly moves up to a cross-league model; `ScoresGrouping` retires | shipped |
| 2026-09-05 | The app never opens on a dead screen (`firstDayWithGames` probes forward) | shipped |
| 2026-09-05 | The slate filter narrows league sections and leaves Following alone | shipped |
| 2026-09-05 | The Scores league scope retires; search tiebreak becomes `preferredLeague` | shipped |
| 2026-09-05 | The Scores header keeps Live and the funnel, nothing else | shipped |
| 2026-09-06 | College football breaks down by conference; the NFL stays one accordion | shipped |
| 2026-09-08 | `League.slateSplitsByConference` — CFB is the only one that splits | shipped |
| 2026-09-09 | The NFL's slate stays one accordion (division sections built and reverted) | shipped — never built the division shape |
| 2026-09-06 | Following is your teams; a followed table gets hoisted instead | shipped |
| 2026-09-06 | League accordions wear their league's mark | shipped |
| 2026-09-07 | Scores section headers tag their league ("ACC CFB") | shipped |
| 2026-09-06 | Day chips carry their month; yesterday and tomorrow get their names | shipped |
| 2026-09-06 | The Today jump leaves the strip for a floating, inverted button | shipped |
| 2026-09-07 | The Today button appears only once the Today chip is off the strip | shipped |
| 2026-09-06 | A calendar sheet joins the day strip | shipped |
| 2026-09-07 | A day swipe commits its day on the frame the thumb lifts | shipped |
| 2026-09-08 | The day fetch debounces 250ms; a cancelled request is never the error banner | shipped |
| 2026-09-05 | The week-rollover machinery retires with the week strip | shipped — `WeekSlot` stays, the rollover rule goes |
| 2026-09-06 | `SwipeSafeButtonStyle` — full-width rows must not fire on a swipe | shipped — `useSwipe` swallows the click a drag leaves behind |
| 2026-09-06 | Followed tables lead in the user's own drag order | shipped — the *order* is honored; the drag UI is W3 |
| 2026-09-01 | Sections pipeline memoizes; sorts once up front | differs — React `useMemo`, not `@Observable`; revisit if the web profiles slow |

**Not a parity row, fixed on the way:** `TeamLogo` built its URL from a bare
ESPN id against a hardcoded **college** bucket, so every pro team wore
whichever college program shared its number — New England (NFL 17) rendered
Claremont-Mudd-Scripps and Seattle (26) rendered UCLA. It now takes the whole
team and prefers the payload's own mark; the dark-variant derivation was
generalized off `ncaa` to every league bucket at the same time (all four
verified 200, including the NHL's nested `500-dark/scoreboard/` path). Caught
by Andy, 2026-09-09.

**Merged with #112 on the way**, not around it: Andy's follow rail landed on
main mid-wave. The rail now resolves its team rows against *every league the
follow set touches* rather than the slate's one — with four leagues on the
page, a college-football-only directory silently dropped a followed NFL team
instead of naming it — and the day strip inherited the week strip's
`lg:pl-[calc(var(--sidebar-w)+var(--sidebar-gap))]` step so its chips still
start where the games do. The `FollowPromptCard` still hides at rail width.

**Deferred to W3 with the hub:** poll follows (`followedPollLeagues` is wired
through the section engine and fed an empty list — the Leagues hub is where a
poll is followed from), and the drag UI for reordering followed tables.

## W3 — Leagues hub  ✅ shipped 2026-09-09

Verified live: College Football's card holds 28 rows — the Top 25, the FBS
root, its eleven conferences in tier order, the FCS root and its fourteen —
and the NFL's holds its own 32-team table above eight divisions grouped
AFC-then-NFC. Following a poll and three conferences, dragging the SEC from
last to second, and reloading Scores put Top 25 → Big Ten → SEC at the head
of a Saturday: one list, one order, both screens.

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-09 | The tab is renamed **Leagues** and takes a trophy icon | shipped |
| 2026-09-05 | One accordion per league, each a browse card with persisted collapse | shipped |
| 2026-09-09 | Pro-league accordions list **divisions**, not conferences | shipped |
| 2026-09-06 | FCS folds inside College Football — one card, no second header | shipped |
| 2026-09-05 | A divisional conference is one row (`foldingDivisions()`) | shipped |
| 2026-09-05 | The NFL gets a whole-league row, built by merging tables already fetched | shipped |
| 2026-09-05 | The Top 25 is followable — a third follow set, keyed by league | shipped |
| 2026-09-06 | A followed thing gets a card, not a row | shipped |
| 2026-09-06 | Followed tables are drag-reorderable; that order leads Scores | shipped |
| 2026-09-07 | The reorder is a hand-rolled drag, not a system drag session | shipped |
| 2026-09-09 | A conference row's teaser falls back to the overall record; a league row shows none | shipped |
| 2026-09-09 | NBA divisions wear their conference's mark | shipped — via the registry's parent walk |
| — | The season-not-started rule (see below) | shipped |

**The route keeps its name.** `/rankings` still serves the hub, exactly as
iOS kept `TablesScreen` and `Tab.tables` — only the words on screen moved.
Nothing that was linked stops resolving.

**Two things fixed on the way, neither a parity row.**

The standings transformer read **one depth** of ESPN's group tree. That was
fine for the shipped response and wrong for two shapes it now has to handle:
a `level=3` request nests divisions under conferences, and college
football's *divisional era* did the same on the plain response — which is
why iOS still shows "Standings TBA" on a 2019 AAC page (`CLAUDE.md`,
2026-08-31, logged there as a known edge). The web now walks the whole tree,
takes parentage from the registry first and the payload's nesting second,
and drops a group that is purely a container so an empty "AFC" can't appear
beside the real one.

And **a season that hasn't opened has no numbers.** ESPN rolls its season
pointer the moment the last one ends and keeps serving the old table
underneath it: probed live 2026-09-09, the NBA standings were stamped
2026-27 and full of 2025-26 results three weeks before a ball was tipped, so
every NBA row on the hub was teasing last season's leader. The roster still
stands — who is in a division is true all summer — so the fix keeps the
teams and drops the records.

> **A gap in this ledger, found by using it.** That last rule exists in the
> iOS app (`ESPNMapper.seasonHasStarted`) but has **no row in CLAUDE.md's
> decisions log**, so the audit that built this file never saw it. The
> ledger is only ever as complete as the log it mirrors, and the CI check
> can only enforce that the log and the ledger grow together — not that a
> shipped behavior reached the log in the first place. Worth knowing before
> treating a `pending`-free wave as proof of parity.

## W4 — Entity pages

**Split into three, because it isn't one PR.** W4 carries 21 decision rows
against ~3,400 lines of iOS source — three to four times W2 or W3 — so it
lands as **W4a** (the template and the standings language), **W4b** (the
Games tabs), and **W4c** (the bracket, the Top 25 entity page, past-season
polls).

### W4a — the template and the standings language  ✅ shipped 2026-09-09

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-05 | The tab row and its filter chips are **sticky** | shipped |
| 2026-09-05 | The season chip moves to the toolbar row on every entity page | shipped |
| 2026-09-05 | A divisional conference keeps its divisions as separate tables | shipped |
| 2026-09-06 | NFL standings gain a League / Conference / Division scope filter | shipped |
| 2026-09-07 | A team page's Standings tab gets the scope chip (scoping *out*) | shipped |
| 2026-09-08 | Standings columns are per league; the ranking key follows | shipped |
| 2026-09-06 | Championship cut marked with a leading-edge bar plus a keyed legend | shipped |
| 2026-09-05 | `SlateControlRow` — Weeks / Date toggles + a Team dropdown | shipped — W4b |
| 2026-09-05 | The Top 25 becomes an entity page with Standings and Games tabs | shipped — W4c |
| 2026-09-05 | `PollScreen` moves onto the entity template; the picker becomes a chip | shipped — W4c |
| 2026-09-05 | ConferencePage's Games tab gains a team filter | shipped — W4b |
| 2026-09-06 | The preseason gets its own cards; the season opens in July | shipped — W4b |
| 2026-09-06 | Team pages fetch the preseason and split Games into a card per phase | shipped — W4b |
| 2026-09-08 | A Games tab opens on the next game — earlier cards fold behind one row | shipped — W4b |
| 2026-09-08 | A Games tab is affordable per team, not per conference (NBA/NHL) | shipped — W4b, as the iOS **code** has it rather than as the row reads. See below |
| 2026-09-06 | The postseason becomes its own tab, drawn as a bracket | shipped — W4c |
| 2026-09-06 | Bracket connectors are earned, never assumed; byes are synthesised | shipped — W4c |
| 2026-09-06 | The postseason tab is the playoff only; the Pro Bowl hangs beneath | shipped — W4c |
| 2026-09-08 | No Postseason tab for NBA/NHL this pass | shipped — W4c |
| 2026-09-05 | Past-season polls come from the core API | shipped — W4c |
| 2026-09-06 | The Top 25 wears college football's mark, not a trophy | shipped — in W3, with the hub row |

### W4b — the Games tabs  ✅ shipped 2026-09-09

Every Games tab in the app gets the same control row and the same fold, plus
the preseason's own cards on team and conference pages alike. The rows are
marked shipped in the W4a table above; two things W4b turned up are worth
their own paragraphs, because neither has a decision row on iOS.

**iOS ships a rolling-window Games tab for the NBA and NHL; its decision row
says it ships none.** CLAUDE.md's 2026-09-08 row reads "NBA and NHL conference
and league pages show Standings alone", and `ConferencePage.swift` has said
otherwise since the leagues merged: `availableTabs` returns `[.standings,
.games]` for a league that can't table a whole season, and `rollingGames()`
fetches a `dates=` window of a week back and three weeks forward, walked
forward up to four times until one has games in it and narrowed by the same
rule that decides whether a followed table claims a game. **The web now
matches the code**, which is the thing users see. There is no decision row for
it on either platform — this is the first place it is written down.

**A dropped `groups=` had an NFL division's Games tab showing the whole
league.** `scoreboardUrl` gated the parameter behind `hasCollegeDivisions`, so
every non-college caller's group was silently discarded and an AFC East page
tabled all fifteen of a week's games. ESPN honours `groups=` far more widely
than that gate assumed — probed live 2026-09-09:

| request | events | verdict |
|---|---|---|
| `nfl` one week, no groups | 15 | the whole league |
| `nfl` one week, `groups=4` | 3 | AFC East's own |
| `nba` whole season, no groups | 900 | truncates at Feb 18 |
| `nba` whole season, `groups=1` | 376 | Atlantic's season, whole |
| `nhl` whole season, `groups=32` | 584 | Atlantic's season, whole |
| `nhl` whole season, `groups=7` | 900 | truncates at Mar 26 |

The dropped parameter is fixed here, which is a parity fix: iOS always sent
it. The **second** half of that table is not. A *division*-scoped season fetch
fits comfortably under ESPN's 900-event cap for basketball and hockey, which
means those pages could carry a real Games tab — weeks, the fold, the team
filter, a whole season — instead of a rolling window, and it means
`canTableAWholeSeason` asks the question at the wrong granularity: the limit
is per **group**, not per league. That is a product change, and it belongs on
iOS first. Logged in BACKLOG.md rather than taken here, because shipping it on
web alone would open exactly the divergence this epic exists to close.

### W4c — the bracket, the Top 25, past-season polls  ✅ shipped 2026-09-09

**The Top 25 is an entity, so it gets the entity page.** Hero mark — college
football's own, not a trophy, because "Top 25" never said whose — title, the
poll's own ESPN headline as the subtitle, the season chip beside the follow
pill on the toolbar row, and Standings / Games / Postseason tabs. The poll
picker becomes a menu chip in the pane's control strip: AP, Coaches and CFP
are the same 25 teams read by different voters, so they filter one table
rather than splitting the page. The table itself adopts the standings tables'
column language — `#` / TEAM / OVR plus a `MOV` column, which is the one thing
a poll has that a standings table doesn't. The Games tab is the division's
whole season filtered to the poll's own teams, by the app's "any ranked
participant" rule.

**Past seasons come from ESPN's core API**, the only surface with a season
axis for rankings — the site API's `/rankings` ignores `season`, `week`, `year`
and `dates` alike. The AP and Coaches polls end in the postseason
(`types/3/weeks/1`, "Final Rankings"); the CFP's last table is selection day's,
at the final week of the *regular* season, read off the weeks collection
rather than assumed. Its ranks name their team by `$ref` alone, so they are
resolved against a one-request `/teams` directory; a rank the directory can't
name is dropped, and an empty directory fails the season rather than tabling
dashes.

**The postseason is a bracket, not a list.** A round of games is a list; a
bracket is a *shape*, and the shape is the information. Match cards in two
columns, the selected round beside the one it feeds, joined by hairline
elbows, with a round chip row and a threshold swipe between rounds.

The connectors are the part worth naming: **a line is drawn only where a
completed game's winner actually turns up in a later game.** ESPN publishes no
bracket tree, so the alternative is assuming games 1 and 2 feed the next
round's game 1 — wrong the moment a format reseeds, and wrong invisibly. So an
unplayed round draws nothing and wires itself up as results land, and a team
that reached a round without playing the previous one gets a **bye** entry of
its own rather than appearing from nowhere. Each next-round game sits level
with the midpoint of its own sources, which is what stops a winner's line
crossing the column to reach it.

Verified against the real 2025 CFP: four first-round games and four byes
resolving into four quarterfinals, then the bracket-ordered pairing that
reorders the left column out of calendar order — MIA/OSU beside MISS/UGA
because both feed the same semifinal. The NFL's four rounds land the same way,
with the **Pro Bowl beneath the final** rather than taking a round chip of its
own: it is filed as `seasontype=3` week 4, and a chip would put an all-star
game between the conference championships and the Super Bowl. College
football's bowls stay out of the bracket entirely — a quarterfinal played *at*
a bowl is a quarterfinal, and a bowl feeds nothing.

The NBA and NHL name no round, so the tab never appears for them: their
playoffs are best-of-seven *series*, and reading advancement off "a winner
turns up later" would draw a line per game of a series. The deferral is
explicit rather than accidental.

**One bug fixed on the way**: `Game.headline` wasn't decoded at all, and it is
the *only* place a college-football playoff round is named — the whole
postseason files under one `seasontype=3` week, bowls and bracket together.

**Three bugs fixed on the way, none of them a parity row.**

**A folded conference table ranked nothing and said otherwise.** A `level=3`
response ships its conference groups *empty*, so deriving a conference table
from its divisions produces entries that are each division's list in turn —
and printing a place column over that is exactly the tiebreaker guesswork the
standings contract forbids. Two changes: an entity page now fetches the
shipped response **and** the divisional one, so a conference ESPN actually
ranks keeps its own order; and where no real table came back, the page shows
**one card per division** rather than a merge. That second path is what gives
a 2019 conference page real standings at all — iOS still shows "Standings
TBA" there (`CLAUDE.md`, 2026-08-31, logged as a known edge).

**The NBA lost its W-L column on any divisional page.** ESPN ships no `total`
stat at `level=3`, only `wins` and `losses` — and the NHL's `total` is a
*sentence* ("50-23-9, 109 PTS"), not a column. The record is composed from
the counts now, per league, with `total.summary` as the fallback.

**A team page's scope chip had no Division rung.** It anchored on the team's
*conference*, so the chain out of it reached only conference and league — the
division race, which is the thing the scope exists for, was missing. It
anchors on the team's own division now, and a scope resolves the anchor to
the rung it names (asking a division for "Conference" means the one above it,
not a conference with the division's id).

## W5 — Game detail

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-05 | Game detail becomes tabbed — Summary / Box score | shipped — W5a |
| 2026-09-05 | Box-score columns carried from the payload, never named in code | shipped — W5a |
| 2026-09-06 | A **Plays tab**; the Drives card moves into it | shipped — W5a |
| 2026-09-08 | Plays group by **period** where a league has no drives | shipped — W5a |
| 2026-09-06 | A live game gets the **Gamecast strip** | shipped — W5b (needs an eyes-on check on a live game) |
| 2026-09-09 | A pre-game header leads with the kickoff time (`kickoffHero`) | shipped — W5b |
| 2026-09-09 | The Game info card splits in two — Game info and **Venue** | shipped — W5b |
| 2026-09-09 | The Game info card leads with a **league row** of tappable table badges | shipped — W5b |
| 2026-09-06 | Venue gets capacity from the core API, plus an attendance meter | **n/a** — ESPN ships no capacity anywhere. The meter shipped; the fetch did not. See below |
| 2026-09-05 | Scoring rows say whose points those were three ways | shipped — W5a, on the play rows; the Scoring card is W5b |
| 2026-09-08 | A derived scoring play is one that moved the game score; hockey → "Goals" | shipped — W5b |
| 2026-09-08 | A period is called whatever its league calls it; the hockey-5 rule | shipped — W5a |

**Split in two**, like W4: **W5a** (the tab shell, the box score, the Plays
tab and the per-league period rules those panes need) and **W5b** (the Summary
pane's own cards — the Gamecast strip, the kickoff hero, the Game info /
Venue split with its league badge row, venue capacity and the attendance
meter, and the derived-scoring rules).

### W5a — the tab shell, the box score, the Plays tab  ✅ shipped 2026-09-09

**Summary / Plays / Box score**, and a tab only exists where its data does: a
pre-kick game, or one ESPN hasn't filled in, shows Summary alone and **no tab
row at all** — pixel-identical to what it showed before either tab existed.
Plays sits in the middle because chronology comes before rosters. The Drives
card moved *into* it rather than being copied: leaving it on Summary would
print the same rows in two tabs.

**Box-score columns come from the payload, never from code.** ESPN ships its
own `labels[]`, and the set changes during the game — a live `passing` group
has five columns and the same group has six once the game is final, because
QBR only lands at the end. So a row whose stat count doesn't match the header
is dropped rather than rendered with every number under the wrong column, and
so is a totals row that doesn't match. Two things the port got right that iOS
had to fix after the fact: **a group with no name is kept** (basketball ships
exactly one, unnamed, and requiring a name dropped every NBA box score
invisibly), and a category nobody recorded anything in is dropped, since ESPN
ships all ten for every game.

**The Plays tab groups by what the league is played in.** Football's plays
live inside their drives, so it is one card of drive accordion rows, newest
first, each expanding in place. Basketball and hockey ship no drives at all
and a flat feed of ~490 plays, so the **period** is the only rung they have —
the same accordion, with the last period open. `All plays` / `Scoring` are the
Games tabs' own toggle language: two answers to one question.

**A scoring play says whose points those were** — read off the change in the
running score rather than off the team that ran the play, because a pick six
and a kick return both score for the side that wasn't on offence. Weight
marks the side, so the colour budget stays at three; a play whose numbers
ESPN didn't ship emphasises neither number rather than guessing.

**A period is called whatever its league calls it**: four quarters in football
and basketball, three periods in hockey, then OVERTIME and counting — except a
**hockey period 5, which is a shootout in the regular season and a second
overtime in the playoffs**, so the label is only offered where the game could
have one.

### W5b — the Summary pane's cards  ✅ shipped 2026-09-10

**The pre-game header leads with the kickoff.** The time takes the slot a
played game's score takes, the date drops beneath it, and the network gets a
third line of its own — the split left it without the second line it used to
ride in on. "Wed, Sep 9 at 8:20 PM" set in the page's quietest type answered
its one question in a whisper while the space between the logos sat empty.
TBD inverts for free: "TBD" headlines and the real day keeps the caption.

**Game info splits from Venue.** One card was answering two questions — when
and where to watch is one, the ground it's played on is another — and the
second half only existed pre-kick, which is what left the played-game card
titled after a card it no longer resembled. The weather rides with the
kickoff: it is the other thing that stops mattering once the game starts.

**Game info leads with a league row**: the league's mark in the icon gutter,
then a tappable badge per table the game counts toward — the widest page
first, then each side's conference. A conference game contributes **one**
conference badge, not two, because the badges are the tables the game appears
in and both sides share one.

**The Gamecast strip** leads the pane while a game is live: possession, the
down, the spot, the drive so far and the last play, over a monochrome field
bar whose ticks every ten yards are what turn a bar into a field. Monochrome
because the header already carries the live dot. It is built from
`drives.current`'s last play — the down it *left behind*, since the strip
describes what happens next — and ESPN drops that object the moment a game
ends, so the card retires itself with no clock check.

**A derived scoring play is one that moved the game score.** ESPN ships
`scoringPlays` for football and none at all for hockey, so hockey's card is
picked out of the flat feed — and only plays whose running score actually
changed, because ESPN flags every shootout attempt as a scoring play and
stamps it with the *shootout tally* rather than the game score. The card is
"Goals" in hockey and doesn't exist in basketball.

### Two things W5b could not mirror

**ESPN ships no venue capacity — anywhere.** The 2026-09-06 iOS decision says
capacity "comes from the core API's venue resource (`/venues/{id}`), memoized
per venue for the client's life", and the row it was written to fix — a
Capacity line that "has never rendered once" — is still not rendering,
because the core resource has **no `capacity` key at all**. Probed live
2026-09-10: a core venue object is `id`, `guid`, `fullName`, `address`,
`grass`, `indoor`, `images` and nothing else; twelve college-football venues
sampled from the collection returned capacity on **zero** of them, and an NFL
venue (Lumen Field) the same. The site API's `gameInfo.venue` carries no
capacity in any of the three leagues either — while `attendance` is present
in all three (93,033 / 68,744 / 17,956).

So the web ships the **card** — attendance leading, the fill meter, the
capacity slot wired behind its optional field so it lights up if ESPN ever
ships one — and **not** the per-venue fetch, which would cost a request per
venue per session to learn nothing. iOS is making that request today. Logged
in BACKLOG.md.

**A summary payload places no team in a conference.** Every game-detail team
arrives with `conferenceId: "0"` (verified live), so the league row had
nothing to build a conference badge from and rendered empty. The web resolves
a side from the **standings the page already fetched** — a third place to
look, after the payload's own id and the pro registry's division map. iOS's
`GameLeagueRow` has only the first two, so the same row is likely empty on a
college-football game there; worth an eyes-on check.

## Post-W7 — decisions since the waves

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-10 | A season is fetched in as many windows as it takes; every conference page gets a Games tab | pending — the web deliberately shipped the rolling window in W4b; this is the follow-up it was logged for |
| 2026-09-10 | The per-venue capacity request is deleted; the decode and the meter stay | shipped — the web never added the fetch (W5b made the same call from the same evidence) |
| 2026-09-10 | The team page gains a Roster tab (FotMob's squad shape, per-league metric column, current-season only) | **shipped 2026-09-11** — fourth tab, after Standings: a Coach card then a card per group, `#` / PLAYER / the league's own metric over rows of jersey gutter, 36px headshot disc, name above "QB · 6' 2" · 225 lbs". All three ESPN findings re-probed live the same day and all three hold, so they ported unchanged — the NBA's flat `athletes` (one "Roster" card, never a group per player), no season axis (so no season chip, Overview's exception joined by a second one), and CLASS for college football against AGE for the pro leagues. `headshotThumbnail` ports too and still earns its place: 219,372 bytes → 19,559 on the combiner. **One departure, from the platform not the design:** iOS shows the tab whenever the backend serves rosters and carries loading/failure inside the pane, where the web fetches server-side — so the tab is always there and the pane says "Couldn't load the roster" (with a retry) or "Roster TBA". The conference-gated Standings tab also stopped being a `slice`, or a conference-less team would have lost Roster along with it |

## W6 — Teams tab, search, onboarding

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-05 | The Teams tab becomes the follow list — one card per followed team | shipped — W6 |
| 2026-09-05 | Joining a team moves into an **Add teams sheet** over the whole directory | shipped — W6 |
| 2026-09-06 | A followed team gets a card; the shortlist interleaves across leagues | shipped — W6 |
| 2026-09-06 | Search results key on `followKey` — the Browns/UAB collision | shipped — W6 |

### W6 — the Teams tab and search  ✅ shipped 2026-09-10

**Teams becomes the follow list.** It was the whole directory in accordions —
every conference, every team, ~250 rows deep — to answer a question about a
handful of teams. Browsing by conference is what the Leagues hub is for and
finding one team by name is what search is for, so this tab is the teams that
are *yours*: one card each, the card navigating and the star unfollowing.
Each card's subtitle names the group **with its league in front of it** —
"NBA Eastern", "NHL Eastern" — because the directory files basketball and
hockey teams under their conference and both leagues call theirs Eastern; and
for the NFL the group is the **division**, since the team's own id would only
ever say AFC or NFC.

**Joining moves into an Add teams sheet** over the whole directory, with a
curated shortlist standing in until the first keystroke. One card per team and
no league headings: a single card holding fifteen teams under a heading reads
as *the* list of that league's teams, which makes every team it omits look
like an oversight. The shortlist **interleaves proportionally** across all
four leagues rather than stacking them, so the top of the sheet is every
league's biggest names instead of fifteen college programs before the first
franchise. Rows toggle follows rather than navigating — the sheet's question
is "which teams are mine?", and a page visit isn't part of answering it.

### Three live bugs, and search was two of them

**Search could only find college-football teams.** `useTeamDirectory("cfb")`
— the league axis landed in 2.0 and the corpus never widened with it, so the
tab could not find the Browns, the Lakers or the Maple Leafs *at all*. That is
also why the `followKey` collision this wave was written to fix had never been
reachable: with one league in the corpus, no two results could share an id.
Both are fixed together, and the collision now has teeth — "pacific" returns
the NBA's Pacific and the NHL's Pacific as two distinct, correctly-linked
rows.

**Search's conference corpus was eleven college conferences.** "AFC East"
found nothing. It is every league's groups now — top-level conferences, the
divisions beneath them, and the league-wide tables.

**Search's game section was permanently empty.** It fetched a bare
`/api/scoreboard` with no league, which that route answers with a **400**, so
`res.ok` was false and the slate silently stayed empty. It fetches a day
window per league now, and a league that misses costs its own games rather
than the section.

Also swept: the app's own name. The root metadata still said "College
Football Hub" — the 1.x name and the 1.x promise, on an app that has covered
four leagues since 2.0.

## W7 — Chrome and tokens

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-09 | The wordmark drops the field glyph and is set as a mark | shipped — W7 |
| 2026-08-31 | Dark mode adopts light mode's elevation logic; new `bgCard` token | shipped — W7 (audited, already correct) |
| 2026-08-31 | Entity-page headers paint `bgCard`; the team-color hero retires | shipped — W7 (audited, already correct) |

### W7 — chrome and tokens  ✅ shipped 2026-09-10

**The wordmark becomes a mark.** It was a 🏈 emoji beside "StatSide" at 17
bold — the glyph-plus-name lockup iOS retired on 2026-09-09, and for the same
reason: the tab bar's own Games icon is a football too, so the header was
saying "sports" twice a thumb apart, and a stock icon beside a stock
system-font string reads as a placeholder logo. All three of iOS's moves turn
out to be reachable in a browser — a **weight split** ("Stat" black against
"Side" medium), the system stack's **condensed width** (measured: 96px → 83px
at 24px, so the axis is genuinely exposed; a browser without it renders normal
width and the other two moves still carry), and **−3% tracking**. It sits at
24px, the hero-title scale, for the reason the entity pages use it: nothing
above it names the screen.

**The token audit came back clean.** Both rows were logged as "needs audit —
the P3 token port predates this", and both are already correct: `--text-primary`
is the soft `#1a1a1a`, the dark ramp is 0.00 / 0.11 / 0.15 / 0.17 exactly
(`#000` → `#1c1c1c` → `#262626` → `#2b2b2b`), `--bg-card` exists and is
distinct from `--bg-primary` in dark, and `bg-bg-primary` is used in four
places, all of them chrome (nav bar, tab bar, calendar-sheet headers) with the
inverted-ink `text-bg-primary` on filled chips. The entity-page hero paints
`bg-card` and no team colour survives anywhere. The only hardcoded hexes
outside the token file are the OpenGraph card's, which is deliberate — it
renders always-light through Satori, which can't read CSS variables — and they
match the light tokens exactly. **Nothing to change**, which is worth
recording as a result rather than a silent tick.

**The fixed-chrome flash is fixed**, paired with this pass as the backlog
suggested. The route template animates the page in with framer-motion's `y`,
and a `transform` on an ancestor becomes the containing block for every
`position: fixed` descendant — so for the length of the entrance the day strip
anchored to the template div rather than the viewport and rendered *over* the
slate.

Of the three ways out the audit listed, this takes the third and structurally
right one: the fixed chrome mounts **outside** the animated subtree, through a
portal into the app shell. Not `document.body` — the shell publishes
`--page-max` as a custom property and the strip reads it to line up with the
content, so portalling that far would fix the transform and break the width.
Verified by measurement, which is how the bug was caught in the first place:
mid-navigation the template still reports `matrix(1, 0, 0, 1, 0, 8)` and the
strip now resolves to **56px**, its correct viewport position, where it used
to be pushed to 196.

---

## Web-originated decisions

Rows that started here rather than on iOS. They carry a status too — the iOS
side is the one that may be pending, and `n/a` cuts both ways: a shape that
answers a desktop problem has nothing to port to a phone.

| Date | Decision | iOS status |
|---|---|---|
| 2026-09-09 | The game page's OpenGraph card (`statside.co`) | shipped — it has always been web-first |
| 2026-09-10 | The Scores day strip, the Live/funnel capsule and collapse-all move into one sticky card at the top of the slate column | **n/a** — the phone has no follow rail, so it has no gap to close |
| 2026-09-10 | The iOS download CTA: a nav-bar pill, a promo card leading the Scores rail and closing a game page's rail, and Safari's Smart App Banner | **n/a** — the app is the thing being linked to |
| 2026-09-10 | The nav bar carries the wordmark on every route rather than swapping it for the page's name | **n/a** — iOS names a screen in its nav bar, which is the platform's own convention and not a thing to port |
| 2026-09-10 | The wordmark reverts to plain 17-bold system type (no condensed axis, no weight split, no tracking); the 🏈 stays gone | **pending** — Andy's objection was to the treatment, not to the platform, and he raised it looking at the web. iOS still ships the 2026-09-09 drawn mark; this row closes when he says which way it goes |
| 2026-09-10 | One content width for the whole app — 1040px, replacing three per-route caps | **n/a** — a phone has one width and the chrome can't shift between routes |
| 2026-09-10 | The site's own OpenGraph card, inherited by every non-game route, plus `twitter:card: summary_large_image` | **n/a** — an unfurl is a property of a URL, and an iOS share deliberately carries the store link (2026-09-05). The `LPLinkMetadata` bubble is the app's equivalent and already exists |
| 2026-09-10 | The OG cards actually load Inter: `fs.readFile` over `fetch`, one static asset URL per face, and a test that the three faces differ | **n/a** — `GameShareCardView` is SwiftUI drawing in the system font; this is a Satori/Node bug with no iOS counterpart |
| 2026-09-10 | Team and conference pages get OpenGraph cards of their own — the page's hero at poster size, on the game card's chassis | **n/a** — an unfurl is a property of a URL, and an iOS team share is text by decision: the invitation framing plus the store link (2026-08-09), with no image |

### The iOS download CTA  ✅ shipped 2026-09-10

Andy: *"include a download CTA for the iOS on the web app"*, then *"include the
logo in the button and create a card on the left side of the page above
following teams/conferences with a stylized graphic of the app"*.

**Why it was missing mattered more after #109.** The OpenGraph card means a
shared game link now unfurls into Slack and on X wearing the matchup card — and
lands every one of those taps on a page with no way to the App Store. The
backlog named that hole at the time ("a way back to the App Store from the web
page"); this closes it.

**Three surfaces, no interstitial.** `GetTheAppPill` sits in the nav bar's right
slot at every width, which has been empty since the Live pill and the funnel
moved into the Scores control card — a bar every page already carries is the
only placement that costs no vertical space. `GetTheAppCard` leads the Scores
follow rail and closes a game page's rail. And `metadata.itunes` emits Safari's
own Smart App Banner, the one placement Apple renders itself, and the only one
that can say "Open" rather than "Get" once the app is installed. No
`appArgument`: the `statside://` scheme is deliberately unregistered and there
are no universal links, so there is nothing to hand it.

**Above the follow lists, not below.** The rail's length *is* the follow set's,
so anything under it sits at a different height for every visitor and is
off-screen for the ones with the most teams. That also forced a fix the card
would otherwise have caused: a sticky column taller than the viewport pins its
top and puts everything past the fold permanently out of reach, so the rail is
capped at `calc(100vh-5rem)` and scrolls inside itself.

**The graphic is drawn, not shot.** A screenshot would be a PNG to re-shoot
every time the slate's type or spacing moved, an unreadable grey smear at
220pt, and a second file for dark mode. The SVG is the same slate abstracted to
its shapes — a day strip with today filled the way the selected chip inverts,
then three game cards, one live — with every value a theme token, so it
re-paints in dark mode with the rest of the page.

**Apple's mark, never Apple's badge.** The "Download on the App Store" badge is
licensed artwork with its own colour and clear-space rules: it would be the
colour budget's fourth exception and a binary to keep in sync. The logo alone,
inline, inherits `currentColor` and inverts with the button it sits in. (The
apple in `lucide-react` is a piece of fruit.)

---

### The Scores control card  ✅ shipped 2026-09-10

Andy, from a FotMob side-by-side: *"move the date controls, live affordance,
filters, etc into a card container so that leagues can be top aligned to that
rather than having an awkward amount of space above the[m] and to the left of
the date controls."*

The three controls lived in three places, and none of them was the column they
scope. The day strip was `position: fixed`, inset past the follow rail
(`lg:pl-[calc(var(--sidebar-w)+var(--sidebar-gap))]`) so its chips began where
the games did. The Live pill and the view funnel portalled into the nav bar's
right slot. Collapse-all floated in a bare row above the first accordion. The
cost was geometric and paid twice: the rail's width of dead air to the left of
the strip, and the strip's height of dead air above **every** card on the page,
because the grid carried an `mt-12` to clear chrome it didn't contain.

In the column's own flow all of that goes. The rail top-aligns to the card
(both measured at 76px at rest, both stuck at the nav bar's 64px), and the
leagues below sit where cards sit. `ChromePortal` stays — the floating Today
button still needs to escape the route template's transform — but the strip no
longer does, because it is no longer fixed.

**Sticky, not merely in flow.** The day is the screen's axis and a Saturday
slate is ten thousand pixels long; the way to the next day must not be a scroll
back to the top. It tucks flush under the nav bar in both sizes (56px on a
phone, 64px from `sm` up), so no slit of scrolling content shows between them.

**Outside the swipe element, deliberately.** The day swipe reads a pointer
drag across the slate, and the strip scrolls horizontally under the same
finger — inside the swipe ref, dragging the strip would scroll it *and* step
the day. The card is the column's first child and the swipe ref moved to the
sibling below it.

---

## Late parity rows

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-12 | The Live filter renames today "Ongoing" on the day strip and the Today button | **shipped 2026-09-12** — same commit as iOS, which is what this ledger is for. `dayChipLabel(day, now, liveOnly)` in `web/src/lib/day.ts` mirrors `DayStrip.namedDay`, and `liveOnly` was already in `ScoresControlCard` and `scores-view` — the two controls just had to be handed it. One difference, pre-existing: a web chip's `aria-label` is the full date on every day (`dayLongLabel`), where iOS speaks the named day, so the rename is visual only on web. Left as it is rather than churned here |
| (unrecorded) | The first tab is labelled **Games**, not Scores | **shipped 2026-09-10** — `RootView.swift` has said Games since the league axis landed and no decision row ever recorded it, so the web had no way to learn it. Logged on both sides now. Second instance of the gap E11's P3 item is open on |

---

## Rows that are `n/a`, recorded so they stay decided

| iOS date | Decision | Why no web analog |
|---|---|---|
| 2026-09-06, 2026-09-07 | Every widget decision (month on kickoffs, clearing yesterday, row deep links) | No widget extension on web |
| 2026-09-12 | A widget row's kickoff reads "Today" / "Tomorrow" on game day and the day before | No widget extension on web. The *rule* is not new to the web — the Scores rows have named the near days since 2026-08-09 and `web/` ports that with them; what has no analog is the widget row it landed on, and the timeline-expiry machinery underneath it |
| 2026-09-07 | The haptics budget grows to four | No haptics API worth using here |
| 2026-09-07 | Deep links carry `?day=` | The web's URLs are already addressable; a `?day=` query is the natural port and rides W2 |
| 2026-09-07 | Every load's end re-tries the pending deep link | Server-rendered routes resolve before paint |
| 2026-09-01 | The overnight agent loop; `main` protection | Process, not product |
| 2026-09-05 | The share link deliberately stays the App Store link | Already settled; the web's own card shipped |
| 2026-09-06 | `SwipeSafeButtonStyle` naming at call sites | iOS-only mechanism |
| 2026-09-10 | The parity ledger is enforced and counted (this mechanism) | Process, not product — it is *about* this file |
| 2026-09-10 | Live Activities de-iced on path 3 (broadcast channels), and the card designed | **n/a** — a Live Activity is a lock-screen and Dynamic Island surface; the `n/a` categories above already cover the widget extension, and this is the same family. The *service* is not n/a and is sequenced with Open question #6 |
| 2026-09-10 | The Live Activity broadcast service ships in `web/` (APNs transport, channel lookup, poll loop) | **shipped** — it *is* web code. The web app has no Live Activity of its own to reach parity on; what landed here is the server half of an iOS feature, which is the first row in this ledger to run in that direction |
| 2026-09-10 | Navigation destinations carry an identity (`.id(team.followKey)`), fixing a team page that could show another team's cached everything | **n/a** — a SwiftUI `NavigationStack` state-reuse bug. The web routes by URL, so a different team is a different page with no state to carry over; there is nothing here to port and nothing to guard against |
| 2026-09-12 | Game destinations carry an identity too (`.id(game.routeKey)`), fixing a detail page that showed one game's header over another's summary | **n/a** — the same `NavigationStack` state-reuse bug as the row above, on the game destination. The web routes by URL: `/game/{id}` is its own page with its own fetch and no state to carry over from the last one. Nothing to port; the guard has no web shape |
| 2026-09-10 | The iOS wordmark reverts to plain system type (21pt header, 15pt share sign-off), no glyph | **shipped** — this row runs backwards: the web reverted first, on 2026-09-10, and iOS is the one catching up. `web/src/components/wordmark.tsx` is the reference implementation. The sizes differ by surface and always have (the web's nav bar is 17) |
