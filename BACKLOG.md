# BACKLOG.md — sports

Priorities: **P0** = must exist before the season starts (~5 weeks). **P1** = in-season. **P2** = when it earns its spot. Nothing gets built that isn't here; new ideas get added here first and discussed.

## E0 — Foundation

- [x] **P0** Set `IPHONEOS_DEPLOYMENT_TARGET` to 18.0 in all build configs (currently 26.2). App runs on an iOS 18 simulator. *(Verified 2026-07-20: builds + runs on iPhone 16 Pro / iOS 18.3.1.)*
- [x] **P0** Create folder structure per ARCHITECTURE.md; delete template `ContentView.swift` in favor of `RootView`.
- [x] **P0** Theme tokens: mono ramp + `liveAccent`, light/dark, type styles, spacing. Acceptance: a theme preview screen shows every token in both modes; no view ever references a raw color.
- [x] **P0** ESPN DTOs + domain models + `ESPNClient` behind a `ScoresProviding` protocol. Acceptance: decodes a real July (empty) and a fixtured in-season scoreboard JSON without error; every field optional; unit test with a truncated/malformed fixture drops the bad event, keeps the rest. *(15/15 unit tests pass.)*
- [x] **P0** Week model parsed from ESPN calendar. Acceptance: strip data includes Wk 0–14 + CCG + Bowls + CFP with correct date ranges; nothing hardcoded.

## E1 — Scores screen

- [x] **P0** Week strip. Horizontal, current week auto-selected, past weeks left, future right. Acceptance: Sunday shows the just-completed week; Monday flips forward; postseason slots use names not numbers. *(Rollover rules unit-tested; rendered live 2026-07-20.)*
- [x] **P0** Game row, 3 variants. *(Pre variant verified on-device with real Wk 1 data; live/final verified in previews + decode fixtures — on-device check needs real games, see E5 note below.)*
  - Pre: logo, team, record, kick time, network. Network is prominent (CFB-specific must-have).
  - Live: score (monospaced digits, heavy weight), quarter + clock, possession indicator, red pulsing `LiveDot` — the only color accent on screen.
  - Final: score with winner in heavier weight, "FINAL"/"FINAL OT".
  - Acceptance: all 3 variants legible in light and dark; row height compact (FotMob density, not ESPN cards).
- [x] **P0** Section stack: Following → Top 25 → conferences, accordion collapse/expand. Acceptance: a game in multiple sections appears in all of them; Following section hidden when the user follows nobody; unknown conferenceId lands in "Other," never crashes. *(Unit-tested; cross-conference duplication confirmed on-screen — Fresno St @ USC renders in Big Ten and Mountain West.)*
- [x] **P0** Accordion memory. Following + Top 25 expanded by default; conference state persists across launches.
- [x] **P0** Conference chips = jump anchors. Tap scrolls to that section (expanding it if collapsed). Acceptance: chips never hide content.
- [x] **P0** Live toggle. One chip; on = each section shows only in-progress games, empty sections hide. Acceptance: toggling never loses scroll position wildly; off restores exactly the prior view. *(Filter logic unit-tested; chip only appears when games are live — on-device check needs real games.)*
- [x] **P0** Refresh: pull-to-refresh always; 30s auto-poll only while foregrounded AND ≥1 game is live. Acceptance: in-place updates preserve accordion + scroll state; no polling in background (verify with logs). *(Implemented with os.Logger instrumentation; log verification needs live games.)*
- [x] **P1** Day dividers inside sections spanning multiple days (Thu/Fri/Sat, whisper-quiet). Field note 2026-07-20: ESPN's 2026 "Week 1" spans two weekends (Aug 22–Sep 8), so weekday alone is ambiguous — dividers need dates ("Sat Aug 29"), and pre-row kick times may too. *(Built with dates; verified on-screen.)*
- [x] **P1** Conference section ordering personalizes: followed team's conference first, then P4 → G5 → Independents. *(Unit-tested; verified on-screen — following Georgia floats SEC above the alphabetical P4.)*
- [x] **P1** Conference logos in section headers. URLs hardcoded per conference id alongside the names, verified against ESPN's /scoreboard/conferences endpoint 2026-07-20. Following/Top 25/Other headers stay text-only. *(Originally grayscale for the monochrome chrome budget; switched to full color 2026-07-21 — the budget's logo exception now covers conferences too.)*
- [x] **P1** Screen states: skeleton loading, error-with-retry (keep last good data), offseason/empty week state with next-kickoff countdown. *(Skeleton rows + quiet refresh-error banner + countdown from the week calendar.)*
- [x] **P1** Header row above the week strip: placeholder wordmark left (name still open — see open question #1), season selector right. Past seasons via scoreboard `dates={year}` (verified live 2026-07-21), CFP-era floor (2014); a past season lands on its final slot (CFP), current season reapplies the rollover rule.
- [x] **P1** Logo loading resilience: replace bare `AsyncImage` with `LogoImage` + `LogoCache` (in-memory, dedupes in-flight fetches, retries on reappearance). Field note 2026-07-21: AsyncImage fetches once and never retries, so a network blip at cold launch permanently blanked the first-rendered section's logos (Following) while lazily-rendered rows loaded fine. Bonus: a team duplicated across sections now renders its logo instantly from cache.
- [x] **P1** Grouping toggle on Scores: a "By date" chip beside the Live chip switches sections to Following (pinned) → one accordion per calendar day, chronological, expanded by default. Live filter composes with either mode; mode persists (`ui.scoresGrouping`). Acceptance: day sections cover the full slate; nil-kickoff games land in a trailing "TBD" section; conference mode unchanged; chip row reachable with zero live games. Note: week-scoped day *grouping*, not day navigation — the no-date-picker rule stands. *(Chip lives in the header beside the season picker, not the Live chip row — that row hides with zero live games, which would have hidden the toggle. Day ids from local calendar components ("day-2026-08-29"), inverse-persistence so days start expanded; TBD shares the "day-" prefix. 8 unit tests cover pinning/no-dedupe, TBD, chronology, Live composition, persistence; smoke test round-trips the toggle on live data 2026-07-21.)*
- [x] **P2** Pinch to collapse/expand all sections (FotMob parity). Pinch in collapses every rendered accordion, pinch out expands them all; fires once per gesture at the threshold crossing; date-grouping day sections included; Scores only. Acceptance: scroll, pull-to-refresh, and header taps unaffected; state persists exactly like individual header taps; no new haptic (budget holds). *(MagnifyGesture via simultaneousGesture on the section ScrollView; bulk store ops unit-tested incl. the mixed expanded/collapsed-semantics case.)*

## E2 — Game detail

- [x] **P1** Header: teams, records, score, status; linescore grid by quarter (incl. OT columns). *(Pre-game header verified on-device; linescore decode-verified against the 2025 CFP championship fixture — visual check needs a completed game, see E5.)*
- [x] **P1** Scoring plays list, chronological with period markers. *(Decode-verified: 8 plays from the championship fixture.)*
- [x] **P1** Team stats comparison (total yards, pass/rush, 3rd down, TOs, possession) as opposing mono bars. *(Bar magnitudes parse "5-14" and "31:14" shapes; unit-tested.)*
- [x] **P1** Leaders (pass/rush/receive per team). *(From summary's top-level leaders; decode-verified.)*
- [x] **P2** Live auto-refresh on this screen while game is in progress. *(30s loop, same rules as the scoreboard: foregrounded + live only; stops itself when the summary comes back final. os.Logger instrumented; live verification folds into the E5 first-game pass.)*
- [x] **P2** Drive log (data already in `drives.previous[]`). *(DRIVES section after Leaders: one line per possession — logo, result with weight on scoring drives, ESPN's "5 plays, 20 yards, 2:39" line — grouped by quarter markers like SCORING. Decode-verified: 22 drives / 8 scoring from the championship fixture; VO speaks each drive as one sentence.)*

## E3 — Rankings

- [x] **P1** AP Top 25 default; segmented picker for Coaches and CFP (CFP appears only when ESPN returns it). *(Chip picker; FCS/DII/DIII polls filtered out; choice persists via ui.pollChoice.)*
- [x] **P1** Rank row: rank, logo, team, record, movement arrow (▲/▼/–, derived from `previous` − `current`), first-place votes where present. Monochrome arrows; movement shown by weight not color. *(Verified on-device incl. NEW tag for unranked-previous.)*
- [x] **P2** Tap rank row → team page. *(NavigationLink straight to TeamPage — RankedTeam already carries a full Team.)*

## E4 — Teams + following

- [x] **P1** Team browse: searchable FBS list grouped by conference. *(Sourced from standings?group=80 — the /teams endpoint has no conference data; see ARCHITECTURE. Sun Belt empty in ESPN's offseason data, renders as absent.)*
- [x] **P1** Follow/unfollow, persisted. Acceptance: follows survive relaunch; Scores Following section updates immediately. *(UI smoke test covers the full flow: search → follow → Following section appears.)*
- [x] **P1** Team page: identity header, record, current-season schedule with results, follow button. *(Schedule shows "Schedule TBA" until ESPN publishes 2026 season schedules; 2025 fixture decode-verified with W/L results.)*
- [x] **P2** Onboarding moment: first launch prompts "pick your teams" (skippable). *(Sheet over RootView, shown once and only when following nobody — an upgrader with follows never sees it; dismissed any way (Skip, Done, swipe) sets ui.onboardingSeen. Searchable conference-grouped list where the whole row toggles follow. Verified on-simulator: fresh install shows the sheet, flagged relaunch doesn't. Smoke test launches with -ui.onboardingSeen YES to stay deterministic. Field note: sheet content only inherits environment applied outside the .sheet modifier — RootView orders .environment after .sheet for that reason.)*
- [ ] **P1** App-wide search: a `Tab(role: .search)` — the FotMob-style circular magnifier beside the floating tab bar on iOS 26, a plain fourth tab on iOS 18 — searches teams, conferences, and the selected week's games. No new fetching — teams/conferences from a shared `TeamDirectoryStore` (one standings fetch at launch), games from the already-loaded scoreboard. Results route through `Router` pending intents; a new `pendingConferenceId` lands on the Teams tab with that conference expanded and scrolled to (intent-only, so the in-flight conference-destination work can re-point one resolver). Acceptance: diacritic-insensitive matching ("jose" finds San José State), followed teams rank first, a no-results state exists, Cancel returns to the previous tab untouched.

## E5 — Season hardening (in-season, field-notes-driven)

- [ ] **P1** First-live-game verification pass (earliest: Week 1, Aug 22): live/final row variants on-device, Live toggle, 30s polling logs, in-place update preserving scroll/accordion state. Everything is unit/preview-verified but ESPN serves only pre-game states until then.
- [ ] **P1** Performance pass with a full Saturday slate (60+ events, all sections expanded).
- [ ] **P2** Rankings ghost-week handling (poll updates Sunday while week still shows Saturday's games).
- [ ] **P2** Week rollover edge cases: Week 0, Army-Navy solo week, CFP date ranges.
- [x] **P2** Accessibility pass: Dynamic Type, VoiceOver labels on rows ("Georgia 24, Tennessee 17, 3rd quarter"), contrast check on grays. *(Type tokens scale via UIFontMetrics, row logos via @ScaledMetric; every row speaks one sentence — game/rank/schedule label shapes unit-tested; chips get selected traits, accordion headers speak count + expanded/collapsed, LiveDot hidden from VO + respects Reduce Motion. Contrast: light textSecondary 0.44 → 0.42 to clear WCAG AA 4.5:1 on bgElevated; all other tokens verified. Remaining: an on-device VoiceOver listen-through and large-size layout check — field-notes material.)*

## E6 — App Store release

De-iceboxed 2026-07-21 (Andy's call). Gated on open question #6 (data licensing) before public release; everything below except submission itself can proceed now.

- [ ] **P0** App icon. The appiconset is empty — this alone blocks submission. Monochrome mark consistent with the design system (icon may spend the red live-dot accent; it's the app's one color). Provide light, dark (transparent bg), and tinted (grayscale) 1024pt variants per iOS 18 conventions.
- [ ] **P0** Platform trimming: `SUPPORTED_PLATFORMS` → iPhone only (`iphoneos iphonesimulator`), `TARGETED_DEVICE_FAMILY` → 1. iPad runs the iPhone app in compatibility mode; no Mac/Vision availability. Matches the "don't build for other idioms" rule.
- [ ] **P0** Privacy policy page (required App Store Connect field even with zero data collection). Draft lives in repo (`PRIVACY.md`); needs a public URL before submission — GitHub Pages is the zero-cost answer.
- [ ] **P0** Apple Developer Program enrollment + App Store Connect listing: verify "StatSide" name availability, description, keywords, age rating (4+), export compliance (standard HTTPS exemption), privacy nutrition label ("Data Not Collected").
- [ ] **P0** Screenshots: 6.9" and 6.5" sets. Real Saturday data reads best — capture during Week 1+ (pairs with the E5 verification pass).
- [ ] **P0** `CFBDClient`: a CollegeFootballData.com v2 backend conforming to `ScoresProviding` (Andy's call 2026-07-21, resolving open question #6 toward option a). ESPN stays the default; CFBD activates via `data.provider` = "cfbd" + a key in `cfbd.apiKey`/`CFBD_API_KEY`. CFBD's scoreboard rows don't carry records/ranks/logos/network inline, so the client joins `/teams/fbs`, `/records`, `/rankings`, and `/games/media` (all season-cacheable) onto `/games` + live `/scoreboard`. Acceptance: all five protocol methods return domain models with no view-layer changes; a malformed element drops the row, never the response; unit tests cover status mapping (pre/live/final-OT), conference name→id mapping, poll movement, and the live merge. **Needs verification with a real key (Tier 1+):** live-field shapes (`possession`, `clock`), whether CFBD team ids match ESPN's (follows persistence across the switch), and score latency vs ESPN on a live Saturday.
- [ ] **P1** Version/build hygiene: marketing version tracks the release (1.0 shipped, 1.0.1 is build 7), build numbers increment per upload. Both `MARKETING_VERSION` and `CURRENT_PROJECT_VERSION` live in 8 places each in `project.pbxproj` — one per target per config — and the app and widget **must** match or the upload is rejected. Chore worth doing: hoist both to the project-level config so a bump is two lines, accepting that Xcode's Target → General fields write back per-target and would undo it.
- [ ] **P2** App Store product page polish: preview video, promotional text. Only after the listing exists.

## E7 — App Review 4.2.2 response

Added 2026-08-04: Apple rejected 1.0 (5) under Guideline 4.2.2 Minimum Functionality ("does not sufficiently differ from a web browsing experience"). The fix is a native-functionality bundle — widgets and notifications come out of the Icebox (they were the roadmap's "killer feature" anyway; the rejection just moved the date). Resubmit as 1.0 (6).

- [ ] **P0** Home-screen widget (`StatSideWidgets` extension target): followed teams' live/next game, systemSmall + systemMedium + accessoryRectangular, monochrome design system, sparse budget-aware timeline (15 min live / hourly idle), last-good snapshot on network failure.
- [ ] **P0** App Group `group.com.andyryanweir.sports`: entitlements for both targets, `FollowingStore` on the shared suite, one-time migration of existing follows.
- [ ] **P0** Shared code to `StatSideShared/` (second synchronized root group; models + networking + Theme tokens compile into both targets).
- [ ] **P0** Deep links: `statside://game/{id}`, `statside://team/{id}`, `statside://teams` via `onOpenURL` + a small Router; scheme unregistered (widgetURL/notification taps only in v1).
- [ ] **P0** Local kickoff notifications for followed teams: one reminder 30 min before kickoff, app-wide bell toggle on TeamPage, contextual permission (never at launch), nearest-24 cap, kickoff-encoded request ids so reschedules are a pure diff.
- [ ] **P0** Haptics (budget of exactly three): follow toggle, refresh success, live score change in game detail only.
- [ ] **P0** ShareLink: game share text (status-shaped) in game detail + team page + row context menu.
- [ ] **P0** Context menus: GameRow (follow either team, share), TeamBrowseRow + RankRow (follow).
- [ ] **P0** Review notes rewrite in `docs/appstore/listing.md` (delete the "displays publicly available…" opener; lead with native functionality) + Resolution Center reply draft.
- [ ] **P0** Build 6: `CURRENT_PROJECT_VERSION` = 6 in app **and** widget configs (must match).
- [ ] **P1** `NextGameIntent` App Intent / Siri Shortcut ("What's my next game?").
- [x] **P2** App Store URL appended to share text once the app is live. *(Shipped in 1.0.1 (7). The sign-off moved behind `ShareSignOff.appended(to:)` in `StatSideShared/Models/Game+ShareText.swift` because game detail composes its own body from the fresher summary score — two call sites, one sign-off, so the link can't drift out of one of them. Link sits on its own line after "— via StatSide" so messaging apps render a preview.)*
- [ ] **P2** One home-screen-widget screenshot frame for the listing (manual simulator capture).
- [x] **P1** Game share carries a rendered matchup card image, not just text. *(A `GameShareCard: Transferable` exports a PNG lazily — logos fetched (1.2 s budget) and `GameShareCardView` rendered by `ImageRenderer` only when a share target is picked, so the 60-row context menu costs nothing. Detail-header layout (logos flanking a status column), always light, type pinned to fixed sizes because the theme's Font tokens bake against the process content size. Share text with the App Store link rides along as `ShareLink(message:)` plus a text-only `ProxyRepresentation` fallback. The iMessage link-preview card itself can't show the game — that's built by the recipient's device from the App Store page's OG tags, and repointing it would need a per-game web page, i.e. a backend.)*

## Icebox (deliberately not now)

- ~~Widgets~~ / Live Activities *(widgets de-iceboxed 2026-08-04 → E7; Live Activities stay iced — no push story without a backend)*
- ~~Notifications~~ *(local kickoff reminders de-iceboxed 2026-08-04 → E7; live-event push still needs a backend, still iced)*
- College basketball (the offseason answer: same schools, same follows)
- FCS/lower divisions
- News content (may be never; scores-first is the identity)
- iPad/Mac/visionOS layouts

## Open questions

1. ~~**App name.**~~ *Resolved 2026-07-21: **StatSide** (Andy's pick). Wordmark + home-screen display name updated.*
2. ~~**Live accent color.**~~ *Resolved 2026-07-21: red stays, decided from side-by-side renders of the real live row. At 6 pt a monochrome dot reads as a stray fleck, and Reduce Motion users lose the pulse — color is the remaining signal.*
3. ~~**Top 25 section scope.**~~ *Resolved 2026-07-21: any ranked participant, confirmed against 2025 data — any-ranked runs 15–21 games/week (~one thumb-scroll), ranked-vs-ranked only 3–6 and breaks the completeness promise.*
4. ~~**FCS games in `groups=80`.**~~ *Resolved 2026-07-21: rows render cleanly (ESPN ships logos/records; `curatedRank` 99 maps to no badge). Found + fixed: FCS visitors' unknown conference ids were double-bucketing 48 Week-1 games into "Other" — Other is now strictly the both-sides-unknown backstop.*
5. **Following a conference** (not just teams) — worth it? Wait for field notes.
6. **Data licensing for public release.** ESPN's unofficial API is fine for a personal build but is undocumented, unlicensed, and revocable at will — the reason App Store release was iceboxed. Options: (a) CollegeFootballData.com — free key, CFB-only, but live-score latency/coverage needs verification against the time-to-score promise; (b) paid provider (SportsDataIO, Sportradar) — real license, real monthly cost, only sensible if the app ever charges; (c) ship on ESPN and accept the sudden-death risk — the DTO layer contains the swap blast radius to one file if it comes to that. Related: team logos off ESPN's CDN are university trademarks; same decision, same options. Andy decides before submission; E6 technical work proceeds regardless.
   **CFBD field notes (verified against their v2 OpenAPI spec + published tiers, 2026-07-21):** `/scoreboard` carries everything the game row needs — tv, period, clock, possession, situation, lastPlay, linescores, win probability — plus `/rankings`, `/calendar` (weeks), `/drives`, `/games/teams` for detail; records/ranks/logos aren't inline on scoreboard rows and would join from `/teams/fbs` + `/records` + `/rankings` (all cacheable weekly). Two catches: **(1) live scoreboard requires Tier 1 ($1/mo Patreon), free tier is historical-only and capped at 1,000 calls/month; (2) all tiers are per-key monthly caps** — one Saturday of 30s polling is ~1,400 calls, so a keyless client-side app doesn't work: the key would ship in the binary (extractable) and every install shares one quota (100 users ≈ 1M calls/mo, above the largest $30/500k tier). A public CFBD app therefore needs a thin caching proxy (e.g. Cloudflare Worker free tier: poll CFBD once per 30s while games are live ≈ 8–10k calls/mo → Tier 2 $5/mo, serve all users from cache) — which amends the "no backend" constraint to "no *stateful* backend." Personal-use TestFlight could ship CFBD keyed at Tier 2 without the proxy. Logos: CFBD's `/teams` logo URLs point at ESPN's CDN anyway, so the trademark posture is unchanged by switching.
