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
| 2026-09-08 | A box-score category no longer requires a name (basketball ships `name: null`) | pending — W5, where the box score is rendered |
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
| 2026-09-05 | Game detail becomes tabbed — Summary / Box score | pending |
| 2026-09-05 | Box-score columns carried from the payload, never named in code | pending |
| 2026-09-06 | A **Plays tab**; the Drives card moves into it | pending |
| 2026-09-08 | Plays group by **period** where a league has no drives | pending |
| 2026-09-06 | A live game gets the **Gamecast strip** | pending |
| 2026-09-09 | A pre-game header leads with the kickoff time (`kickoffHero`) | pending |
| 2026-09-09 | The Game info card splits in two — Game info and **Venue** | pending |
| 2026-09-09 | The Game info card leads with a **league row** of tappable table badges | pending |
| 2026-09-06 | Venue gets capacity from the core API, plus an attendance meter | pending |
| 2026-09-05 | Scoring rows say whose points those were three ways | pending |
| 2026-09-08 | A derived scoring play is one that moved the game score; hockey → "Goals" | pending |
| 2026-09-08 | A period is called whatever its league calls it; the hockey-5 rule | pending |

## W6 — Teams tab, search, onboarding

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-05 | The Teams tab becomes the follow list — one card per followed team | pending |
| 2026-09-05 | Joining a team moves into an **Add teams sheet** over the whole directory | pending |
| 2026-09-06 | A followed team gets a card; the shortlist interleaves across leagues | pending |
| 2026-09-06 | Search results key on `followKey` — the Browns/UAB collision | pending |

## W7 — Chrome and tokens

| iOS date | Decision | Status |
|---|---|---|
| 2026-09-09 | The wordmark drops the field glyph and is set as a mark | pending |
| 2026-08-31 | Dark mode adopts light mode's elevation logic; new `bgCard` token | needs audit — the P3 token port predates this |
| 2026-08-31 | Entity-page headers paint `bgCard`; the team-color hero retires | needs audit |

---

## Rows that are `n/a`, recorded so they stay decided

| iOS date | Decision | Why no web analog |
|---|---|---|
| 2026-09-06, 2026-09-07 | Every widget decision (month on kickoffs, clearing yesterday, row deep links) | No widget extension on web |
| 2026-09-07 | The haptics budget grows to four | No haptics API worth using here |
| 2026-09-07 | Deep links carry `?day=` | The web's URLs are already addressable; a `?day=` query is the natural port and rides W2 |
| 2026-09-07 | Every load's end re-tries the pending deep link | Server-rendered routes resolve before paint |
| 2026-09-01 | The overnight agent loop; `main` protection | Process, not product |
| 2026-09-05 | The share link deliberately stays the App Store link | Already settled; the web's own card shipped |
| 2026-09-06 | `SwipeSafeButtonStyle` naming at call sites | iOS-only mechanism |
