# CLAUDE.md — sports

Context file for AI-assisted development sessions on this project. Read this before writing any code.

## What this is

A college football scores app for iOS, inspired by FotMob's information architecture. One sport, done fast and beautifully, in black and white. NCAA football first; the architecture should leave the door open to other sports later without designing for them now.

The target user checks scores 20+ times every fall Saturday and is tired of ad-stuffed everything-apps where CFB is one tab among 30. Speed and focus are the product.

## Product principles

1. **The Saturday sort order is the product.** The landing page answers "what's the state of college football right now" in one thumb, one scroll. Everything else hangs off that.
2. **Week is the unit of time, not the day.** Fans think in weeks (Wk 0–14, championship week, bowls, CFP). Polls, TV schedules, and slates all move weekly. Never build a date-scroller.
3. **Sections are complete, never deduplicated.** A game can (and should) appear in Following, Top 25, and its conference section simultaneously. Each section keeps its promise of completeness.
4. **Monochrome chrome, color only where it earns it.** See design system below.
5. **Fast beats complete.** ESPN will always have more data. We win on time-to-score. No interstitials, no ads, no splash screens doing work.

## Design system

- **Palette:** Black, white, and grays only for all UI chrome, text, dividers, and backgrounds. Support light (white bg) and dark (black bg) via semantic colors from day one.
- **The color budget:** exactly three exceptions to monochrome:
  1. Logos — team and conference — render in full color (grayscale logos would make Michigan and Iowa look like the same team).
  2. The live indicator (a small pulsing dot + live score emphasis) may use a single red accent.
  3. Rankings movement indicators: green up, red down (the same red as the live accent — the app carries exactly one red). Arrows carry the meaning too; color is never the only signal.
- **Live state spends the visual budget:** heavier type weight on live scores, pulsing dot, possession indicator. Pre-game and final rows stay quiet.
- **Typography:** system font (SF Pro). Weight and size create hierarchy, not color. Scores use monospaced digits (`.monospacedDigit()`) so they don't jitter as clocks tick.
- **Density target:** FotMob-level. A game row is one compact line: logo, team, record, score/time, network. No cards-with-shadows padding inflation.

## Technical constraints

- **Language/UI:** Swift + SwiftUI only. No UIKit unless a specific need forces it. No third-party dependencies without an explicit decision (goal: zero for v1).
- **SDK/target:** Built with Xcode 26.3 / iOS 26 SDK. **Deployment target is iOS 18.0.** Do not use iOS 26-only APIs without `#available` guards. Prefer APIs available in iOS 18.
- **Backend:** none. The app talks directly to ESPN's unofficial API. No accounts, no server, no analytics in v1.
- **Persistence:** UserDefaults for followed teams and UI state (accordion expansion). No database in v1.
- **Concurrency:** async/await throughout. Note the project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` (Xcode 26 default) — types are MainActor-isolated unless marked otherwise; put network work in `nonisolated` or actor-isolated types deliberately.

## Project facts (verified from project.pbxproj)

- `objectVersion = 77` with **PBXFileSystemSynchronizedRootGroup**: any file added under `sports/` on disk is automatically part of the app target. No pbxproj surgery needed to add files.
- Deployment target currently `26.2` in all 6 build configs — must be changed to `18.0` (see BACKLOG E0).
- `SUPPORTED_PLATFORMS` includes macOS, visionOS; `TARGETED_DEVICE_FAMILY = 1,2,7`. iPhone is the only design target for v1; don't spend effort on other idioms.
- Bundle id: `com.andyryanweir.sports`.

## Data source: ESPN unofficial API

Base: `https://site.api.espn.com/apis/site/v2/sports/football/college-football`

| Purpose | Endpoint |
|---|---|
| Scoreboard | `/scoreboard?groups=80&limit=300&week={n}&seasontype={2\|3}` |
| Rankings | `/rankings` |
| Game detail | `/summary?event={eventId}` |
| FBS teams by conference | `https://site.api.espn.com/apis/v2/sports/football/college-football/standings?group=80` (the `/teams` endpoint has no conference data — see ARCHITECTURE.md) |
| Team schedule | `/teams/{id}/schedule` (score is an object here, not a string) |

Response shapes were verified live on 2026-07-21 — see ARCHITECTURE.md § API reference for the field-level breakdown.

**Rules for working with this API:**
- It is undocumented and can change without notice. Every response field is optional in our decoders. No force-unwraps, no `try!` on decode paths. A missing field degrades the row, never crashes the app.
- Isolate ESPN's shapes in DTO structs; map them to our own domain models at the client boundary. If we ever swap to CollegeFootballData.com, the blast radius is one file.
- Poll the scoreboard no faster than every 30s, and only while the app is foregrounded and games are live. Be a polite guest.
- Not for commercial use long-term. Fine for a personal v1; needs a licensing answer before any public/App Store ambition beyond personal use.

## Conventions

- File layout under `sports/`: `App/`, `Theme/`, `Stores/`, `Intents/`, `Features/{Scores,Rankings,GameDetail,Teams}/`. Shared code (models, networking, theme tokens) lives in top-level `StatSideShared/`, compiled into both the app and `StatSideWidgets/` (the widget extension). Entitlements live in `Config/`.
- State: `@Observable` classes (iOS 17+, fine for our 18.0 floor), owned by views via `@State`, passed via `@Environment`.
- One view per file. Views over ~100 lines get decomposed.
- Names say what things are: `GameRow`, `WeekStrip`, `ConferenceAccordion`, `LiveDot`. No `Manager`, no `Helper`, no `Utils`.

## Running the UI tests

`sportsUITests` drives the real app against the live ESPN API — there are no fixtures. Two environment rules, both learned the hard way:

- **Always pass `-parallel-testing-enabled NO`.** Parallel runs clone the simulator, and the clones fail wholesale with `Invalid device state` / `Mach error -308 — server died` before a single assertion runs. The failure looks nothing like a test failure, so it's easy to misread as a broken build.
- **Check the simulator's Dynamic Type size before believing a failure.** At `accessibility-*` content sizes the header chips and the Teams search field no longer fit, so queries for them find nothing and previously-passing tests fail in unrelated-looking places. `ScreenshotTests` documents setting appearance and text size for accessibility passes; that state persists on the device afterward. Reset with `xcrun simctl ui <udid> content_size large` — `large` is the iOS default, so it's what both the tests and the App Store screenshots assume. Pass the **UDID, not the device name**: `iPhone 17 Pro` exists on several runtimes and xcodebuild's pick between them isn't stable.

Because the data is live, assertions must not encode calendar facts. Don't wait on a specific poll (the AP Top 25 doesn't exist until mid-August, and `RankingsScreen` hides the picker entirely when only one poll came back) or on a specific week's games. Shared helpers for the recurring traps — retrying a tab tap that a navigation transition swallowed, scrolling the week strip without oscillating — live in `sportsUITests/UITestSupport.swift`.

## Decisions log

| Date | Decision | Why |
|---|---|---|
| 2026-07-21 | Data: ESPN unofficial API for v1 | Free, no key, live scores. Risk accepted + contained via DTO layer |
| 2026-07-21 | Scope: Scores + Rankings + Game detail + Team following in v1 | Andy's call; scores screen leads |
| 2026-07-21 | Week-based navigation, not date-based | CFB's native clock; kills the empty-Tuesday problem |
| 2026-07-21 | Section order: Following → Top 25 → conferences (accordions) | Fixes ESPN's "where are my teams" failure |
| 2026-07-21 | Games duplicate across sections | Section completeness beats dedupe cleverness |
| 2026-07-21 | Conference chips jump-scroll, they don't filter | Filtering creates a mystery state |
| 2026-07-21 | One "Live" toggle is the only filter | The 3:30-Saturday use case |
| 2026-07-21 | Accordion state persists; Following + Top 25 open by default | FotMob's memory pattern |
| 2026-07-21 | Week rolls over Monday morning; Sunday still shows the completed week | Sunday is for catching up + new poll drops in place |
| 2026-07-21 | Monochrome + logos-in-color + single red live accent | Distinctive, and live state pops harder |
| 2026-07-21 | iOS 18.0 deployment target, iOS 26 SDK | Andy's call |
| 2026-07-20 | Conference jump chips removed (supersedes the jump-scroll decision) | Accordions cover section navigation; the chip row was redundant. The Live toggle stays, now as its own `LiveFilterChip` |
| 2026-07-21 | Rankings movement gets red/green (third color-budget exception) | Andy's call; movement direction reads instantly. Down reuses the live red; arrows keep it color-blind safe |
| 2026-07-20 | Conference logos in section headers render grayscale (inverted in dark mode) | Headers are chrome, and the color budget's logo exception is team-specific (disambiguation); conference headers already carry the name. ESPN has no dark-variant conference logos, so dark mode inverts the grayscale mark |
| 2026-07-21 | Conference logos render full color (supersedes the grayscale decision) | Andy's call after seeing it in practice; the color budget's logo exception now covers all logos, not just teams. Also drops the dark-mode invert hack |
| 2026-07-21 | App name: **StatSide** | Andy's call, closing open question #1. Wordmark + `CFBundleDisplayName` updated |
| 2026-07-21 | Live accent stays red (closes open question #2) | Decided from side-by-side renders; a 6 pt monochrome dot doesn't register at scroll speed, and Reduce Motion removes the pulse fallback |
| 2026-07-21 | Top 25 = any ranked participant (closes open question #3) | 2025 data: any-ranked is 15–21 games/wk, ranked-vs-ranked 3–6 — too thin for a section named Top 25 |
| 2026-07-21 | "Other" section = both-sides-unknown only | FCS visitors were double-bucketing ~48 Week-1 games into Other; an FCS visitor now stays in its host's conference section |
| 2026-07-21 | Dark mode backs conference marks with a light disc (`logoBacking`) | Navy marks (Big Ten, ACC) vanish on black; a backing disc is chrome, not color, so the budget holds |
| 2026-08-04 | Widgets + local notifications de-iceboxed (epic E7) | Apple rejected 1.0 (5) under 4.2.2 Minimum Functionality; they were the roadmap's "killer feature" anyway. Live Activities stay iced (no push story) |
| 2026-08-04 | pbxproj-edit rule amended: target/build-phase/build-setting edits allowed when adding targets, verified by lint + build; file references still never touched by hand | The widget extension is a genuinely new target; synchronized groups still handle all file membership |
| 2026-08-04 | Shared code lives in `StatSideShared/` — a second synchronized root group compiled into both app and widget targets | The alternative (exception-set deny-list on `sports/`) silently adds every future app file to the widget target |
| 2026-08-04 | App Group `group.com.andyryanweir.sports`; `FollowingStore` reads the shared suite, migrated once from standard defaults (standard copy kept) | Widget needs the follow set; migration flag lives in the suite |
| 2026-08-04 | Deep links `statside://game/{id}` / `statside://team/{id}` / `statside://teams`, scheme deliberately unregistered (no `CFBundleURLTypes`) | widgetURL and notification taps deliver to `onOpenURL` without registration; registering would force a partial Info.plist for external openers nobody needs yet |
| 2026-08-04 | Notifications: one local reminder 30 min before kickoff, app-wide bell toggle on TeamPage, permission asked contextually (bell tap or post-first-follow alert), never at launch | One reminder beats two under the 64-pending cap; per-team granularity is icebox material |
| 2026-08-04 | Haptics budget: exactly three (follow toggle, refresh success, live score change in game detail only) | Mirrors the color budget's discipline; GameRow haptics on a 60-game Saturday would machine-gun the Taptic engine |
| 2026-08-04 | UIKit import exception: `UIApplication.openNotificationSettingsURLString` for the bell's denied state | No SwiftUI equivalent exists |
| 2026-08-04 | Widget provider fetches ESPN directly (no app-written snapshot as primary) | The widget must be live at 3:30 Saturday without the app opening; WidgetKit's ~40–70/day reload budget is itself the politeness throttle (~48 requests on a full Saturday). Adds an unattended request surface to the unofficial-API risk — volume negligible |
| 2026-08-09 | Scores rows spend exactly as much date as the kick needs: "Today 3:30 PM" / "Tomorrow 3:30 PM" inside 48 hours, the bare weekday out to a week, weekday + date ("Sat, 9/5 3:30 PM") past that | On the Saturday itself — the app's whole use case — "Sat" is dead weight; but a weekday alone means *the next one*, so it lies about a game three weeks out. Scores-screen rows only; share text, widget, and schedule strings stay absolute because they outlive the moment they're generated |
| 2026-08-09 | A row under a day divider never repeats the date; `SectionAccordion` passes its existing `spansMultipleDays` down as `GameRow.dayIsLabeled`. VoiceOver always speaks the full date | Dividers and rows were both saying "Aug 29" in conference sections. The divider is the section's date mechanism, so the row defers to it — but only visually, since a VoiceOver swipe can land on a row without passing the divider |
| 2026-08-09 | Pinch on Scores collapses (in) / expands (out) every rendered section — FotMob's gesture, the app's first gesture. Fires once per pinch in `onChanged` at 0.8/1.25 magnification, persists exactly like per-header taps, day sections included, Scores only | Batch accelerator for the dozen-tap Saturday problem. No haptic (the budget of three holds; the animation is the feedback). Gesture-only: every header keeps its focusable toggle button, so nothing is pinch-gated for VoiceOver or motor-impaired users |
| 2026-08-09 | Team share = invitation framing ("Keep up with…" + record + next game) through `ShareSignOff` — the last share site to adopt it. Body never names the app; the sign-off is the only branding. No `statside://` link in shares | "Following X on StatSide" carried no link and no substance. Custom schemes aren't tappable in iMessage and there's no domain for universal links, so the store link stays the one tappable link; the unregistered-scheme decision holds |
| 2026-08-09 | Game shares attach a rendered matchup-card PNG (`GameShareCard: Transferable`, lazy async export); share text + store link move to `ShareLink(message:)` | The generic App Store card was the only visual in a shared thread. The card renders always-light at fixed type sizes (theme Font tokens bake against the process content size, so they can't be pinned via the environment) from `GameHeaderState`, the extracted detail-header derivations. Repointing the iMessage *link preview* itself would need per-game web pages — a backend — so it stays the App Store card, beneath the real game image |
| 2026-08-09 | Rows inside a day-grouped accordion drop the date entirely (`GameRow.timeOnly`) — kick time + network only. VoiceOver still speaks the full date | The accordion header already says "Saturday, Aug 29"; even the weekday the divider rule keeps is dead weight when the whole section is one day |
| 2026-08-09 | App-wide search is a native search tab (`Tab(role: .search)`) — the FotMob-style circular magnifier beside the floating tab bar on iOS 26, a plain fourth tab on iOS 18; corpus = shared team directory + FBS conferences + the selected week's already-loaded games (no new fetch surface); conference results emit a `Router` intent (`pendingConferenceId`), never a hardcoded destination | Andy's call after seeing per-header magnifiers (superseded same day): FotMob's bottom placement beats three header buttons, and the OS renders it. Time-to-answer beats corpus breadth, and the intent indirection keeps search decoupled from the in-flight conference-page worktree. Enabler: `ScoreboardStore` + new `TeamDirectoryStore` hoisted to RootView's environment — single fetch, polling lifecycle owned by the scene, not a tab |
| 2026-08-09 | Conference standings via a new `conferenceStandings()` protocol method; `fbsConferences()` and `ConferenceTeams` untouched | Same endpoint, second mapper: browse keeps its alphabetical contract, ConferencePage keeps ESPN's standings order (not derivable from records — tiebreakers). The standings mapper keeps empty conferences so the page can say "Standings TBA" offseason |
| 2026-08-09 | Conference follows are a second set on `FollowingStore` (App Group suite, new key); v1 scope is the Scores Following section only — widget and kickoff notifications stay team-driven (closes open question #5) | One store owns "do I follow this game"; a conference has no single "next game" for the widget, and ~9 reminders/week would evict team reminders under the nearest-24 cap. Conference follows count toward `followsAnyone`; an FCS visitor's game joins Following via its FBS host's conference |
| 2026-08-09 | Conference accordion headers gain a trailing standings button (`ConferenceStandingsLink`); the header surface stays the expand/collapse toggle; context menu + VoiceOver custom action mirror the GameRow precedent | Two side-by-side buttons beat gesture cleverness — the toggle's whole-width promise is never diluted, and the small trailing target gets redundant accessible paths |
| 2026-08-09 | Scores and Teams stacks switched typed paths (`[Game]`/`[Team]`) to `NavigationPath` | A homogeneous typed path can't push a second destination type; `NavigationPath` keeps every existing `NavigationLink(value:)` and the deep-link pending-id resolution intact. Rankings keeps its view-builder links but registers the same value destinations. (Main reached the same conclusion independently for game-detail team links — the merge kept `NavigationPath`) |
| 2026-08-10 | Rankings is the tables hub: CONFERENCES card (one row per conference, leader teaser, follow star, followed pinned first) below the poll — no 4th tab | Andy's call after weighing a Conferences tab: a tab would be a menu, not a destination, and Rankings already answers "who's good" — now at both levels. The teaser hides preseason (a 0-0 "leader" is last season's carry-over); a standings fetch miss hides the card, never errors over the poll |
| 2026-08-10 | Rankings root is a FotMob-Leagues-style row list: Top 25 row (→ `PollScreen`) above the conference rows (supersedes the poll-stays-inline-at-root first cut, same day) | Andy's call from the FotMob reference: 25 inline rank rows buried the conference list below the fold where nobody would discover it. The poll costs one obvious tap now; the whole hub is visible in one screen |
| 2026-08-10 | Search conference results land on ConferencePage — the Teams resolver pushes the standings page instead of expanding/scrolling the browse list (takes over the seam the search decision left open) | A conference's page beats its roster mid-list as a search destination. Resolution needs no loaded data (the page fetches its own standings), so the browse-list scroll machinery (`scrolledSection`, `scrollPosition`, the 450ms layout wait) came out entirely |
| 2026-08-16 | Team logos switch to ESPN's `500-dark` variants in dark mode, app + widget, via URL derivation (`URL.darkTeamLogoVariant`); missing dark asset → light fallback, with the 404 negative-cached in `LogoCache` | Black artwork (Ohio State's lettering) vanishes on the black background. The scoreboard payload ships no `logos[]` array, so the dark URL can't be decoded — derivation covers every surface from one helper. Share card stays always-light; conference marks derive nothing and keep `logoBacking` (no verified dark conference assets) |
| 2026-08-17 | Horizontal swipe on the Scores content pages to the adjacent week (left = next, right = previous), with a directional push slide; week-strip chip taps share the direction rule; season ends are a quiet no-op | Andy's call; the strip is a top-of-screen reach on a couch Saturday, and swiping the content is the FotMob-native way to walk weeks. Gesture-only accelerator like the pinch — chips keep every week tappable — and no haptic, so both budgets hold |
| 2026-08-16 | Widget families become medium + large (small removed; lock-screen accessory stays), both rendering one FotMob-style stacked list: ★ Following header, 8pt-padded rows, medium 2 games / large 5 + updated/as-of footer, provider limit 5 for all families. Pre-game rows drop scores entirely (no 0–0, no dashes) and the status is time-only — weekday + time, date joining at 7+ days out, no network | Andy's call from FotMob side-by-sides: the 3-row medium was too tight, and FotMob's medium/large split fits the "list of my games" promise better than a single-game small. A 0–0 pre-game score is noise pretending to be signal, and the network doesn't earn its width in a widget row. Placed small widgets go blank — accepted |

## Don'ts

- Don't add colors beyond the budget. If a design problem seems to need color, it needs weight, size, or spacing instead.
- Don't dedupe games across sections.
- Don't add a date picker or day-based navigation.
- Don't add third-party packages, analytics, or a backend without an explicit conversation first.
- Don't edit `project.pbxproj` file references by hand — synchronized groups make file management automatic. Build settings, and target/build-phase additions when adding a new target, are allowed (amended 2026-08-04 for the widget extension); always verify with `plutil -lint` + a full build.
- Don't build for iPad/Mac/Vision idioms in v1.
- Don't start coding a feature that isn't in BACKLOG.md — add it to the backlog and discuss first.
