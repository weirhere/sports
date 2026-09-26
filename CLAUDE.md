# CLAUDE.md — sports

Context file for AI-assisted development sessions on this project. Read this before writing any code.

## What this is

A sports scores app for iOS — college football, the NFL, the NBA and the NHL — inspired by FotMob's information architecture. Four leagues, done fast and beautifully, in black and white. College football came first and still leads the fall; the NFL joined at 2.0 (2026-09-05) and brought the league axis, which is exactly how basketball and hockey arrived (2026-09-08).

The target user checks scores 20+ times a fall weekend and is tired of ad-stuffed everything-apps where their sport is one tab among 30. Speed and focus are the product.

**On "one sport, done fast":** that was the 1.x charter, and the discipline behind it survives — the app still does a small number of things completely rather than many things partly. What changed is that a fan's weekend is Saturday *and* Sunday, and that the winter has its own. The leagues share teams' worth of structure (the same ESPN shapes, the same follows, the same widget). What they do not share is a calendar, which is why the week strip retired for a day strip — and why the day strip is what made a six-month, ten-games-a-night league possible at all. The app now has no offseason: the season runs July through June.

**A note on what stayed football-shaped.** Drives, the Gamecast field strip, downs, weeks and the polls are football's, and they hide themselves rather than being generalized. A basketball game page shows a line score, leaders, a box score and its plays by period, and nothing that pretends a possession is a drive.

**Monorepo note:** this repo also carries `web/` — a Next.js prototype web app (`college-football-hub`), merged in with full history from a standalone web repo (confusingly also named `weirhere/sports` at the time, since deleted) on 2026-09-01 via `git subtree`. It has its own README and PRD under `web/` and none of the iOS conventions below apply to it. Everything else in this file is about the iOS app. This repo itself is **`weirhere/sports`** — renamed from `weirhere/sports-ios` on 2026-09-01; GitHub redirects the old URLs.

## Product principles

1. **The Saturday sort order is the product.** The landing page answers "what's the state of college football right now" in one thumb, one scroll. Everything else hangs off that.
2. **The day is the unit of time on Scores; the week still is wherever a league has one.** Superseded 2026-09-05 for the Scores screen, when two leagues landed on one page. Football's team pages, conference pages and polls still think in weeks, because within one league fans do (Wk 0–14, championship week, bowls, CFP). Basketball and hockey have none — ESPN sends `week: null` on every event — so their Games tabs group by date and the Weeks toggle isn't offered.
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
- **SDK/target:** Built with Xcode 26.6 / iOS 26 SDK. **Deployment target is iOS 18.0.** Do not use iOS 26-only APIs without `#available` guards. Prefer APIs available in iOS 18. *(Amended 2026-09-21: was "Xcode 26.3", stale by three point releases.)* Xcode 27.1 beta (`27A9269`, iOS 27.1 SDK, Swift 6.4) is installed alongside at `/Applications/Xcode-27.1.0-Beta.app` for iPhone Duo work; `xcode-select` stays on 26.6, so scope the beta per-command with `DEVELOPER_DIR=` rather than flipping the machine onto a beta toolchain. The app builds clean against the 27.1 SDK — the concurrency warnings it reports are identical to the 26.6 baseline, so Swift 6.4 adds none of its own.
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
- Live data is the product: while a game is live, the scoreboard and game page poll every 5s (`DataProvider.pollInterval`), about as fast as ESPN's CDN refreshes them (`max-age` 1–3s). Poll only while the app is foregrounded and games are live or kicking off; a quiet slate makes no requests. *(Amended 2026-09-26: was a 30s polite-guest floor, which left scores visibly behind the broadcast.)*
- Not for commercial use long-term. Fine for a personal v1; needs a licensing answer before any public/App Store ambition beyond personal use.

## Conventions

- File layout under `sports/`: `App/`, `Theme/`, `Stores/`, `Intents/`, `Features/{Scores,Rankings,GameDetail,Teams}/`. Shared code (models, networking, theme tokens) lives in top-level `StatSideShared/`, compiled into both the app and `StatSideWidgets/` (the widget extension). Entitlements live in `Config/`.
- State: `@Observable` classes (iOS 17+, fine for our 18.0 floor), owned by views via `@State`, passed via `@Environment`.
- One view per file. Views over ~100 lines get decomposed.
- Names say what things are: `GameRow`, `WeekStrip`, `ConferenceAccordion`, `LiveDot`. No `Manager`, no `Helper`, no `Utils`.

## Running the UI tests

`sportsUITests` drives the real app against the live ESPN API — no fixtures, with one deliberate exception: `LiveDetailHoldUITests` runs the scripted `FixtureScoresClient` (`-data.provider fixture`, poll compressed via the DEBUG-only `poll.interval` default) because live-game churn can't be scheduled for a test run. Eight environment rules, all learned the hard way:

- **XCUITest can ghost-activate controls on iOS 26.5.** A hold that queries the accessibility tree every second (an `exists` loop) occasionally fires a navigation control with no synthesized touch — a back button (pops the held screen), a NavigationLink (pushes a page nobody tapped), an accordion toggle. Verified 2026-08-31 with screen recordings and the one-synthesized-event xcresult; hand-driven holds and query-free holds never fire. This is what the 2026-08-29 "detail pops itself back to Scores" field report was. Keep long holds query-sparse, treat a spontaneous navigation during a querying hold as this artifact until the `scoresnav` path-depth log says otherwise, and see `LiveDetailHoldUITests`' `GHOST_REPRO=1` diagnostics to demonstrate it.

- **Uninstall the app before `ReminderOfferUITests`** (`xcrun simctl uninstall <udid> com.andyryanweir.sports`). Fresh-user state for `notifications.enabled` must come from a fresh install, not an argument-domain override: overrides beat the app's own writes, and `refreshAuthorization()` re-reads the key on scene-active, so the override flips the bell back off right after the grant. The uninstall also resets the TCC notification permission so the springboard prompt path actually runs.
- **Never `tap()` an alert-panel button** — the app's SwiftUI alerts and springboard's permission prompts alike. Under Xcode 26.6+/iOS 26.5 the synthesized tap resolves an activation point that lands somewhere else on screen (one stray toggled the reminder bell mid-test). Use `tapUntilDismissed(_:dismissing:via:)` in `UITestSupport.swift`: app-rooted coordinate taps at the button's settled frame, verified by the panel actually going away.

- **Pin `-ui.scoreFilter none` in any suite that queries game rows.** The Scores slate filter persists across launches by design (2026-08-29), so a suite inherits whatever the last run — or whoever last used the simulator — left selected, and every row query then searches a filtered slate. The failure looks like the app lost its games. Safe as an argument-domain override, unlike the `notifications.enabled` case above, because `UIStateStore` reads the key once in `init`; `"none"` parses to no filter. `FCSOptInUITests` selects a filter as its whole point, which is what surfaced this: it left every other fixture-backed suite failing until all three pinned it.

- **Pin `-ui.appearance system` in any suite that sets the simulator's appearance.** Settings' Appearance choice (2026-09-25) persists, and a Light or Dark left over from a previous run beats `simctl ui <udid> appearance`, so a dark screenshot pass would quietly come out light. Safe as an argument-domain override: `UIStateStore` reads the key once in `init`. `ScreenshotTests` and `AppStoreScreenshots` pin it.

- **Pin `-review.prompt off` in any suite that could reach a game from a notification.** The rating ask (2026-09-15) fires 1.5s after a reminder-tapped game finishes loading, and a system rating sheet eats taps meant for the app — the same class of problem as the alert-panel rule above, with no `tapUntilDismissed` escape because the sheet is StoreKit's. Preventive rather than learned: no suite taps a real kickoff notification today, so nothing has failed on this yet. DEBUG-only, and safe as an argument-domain override because `ReviewPrompt` reads the key per call.

- **Always pass `-parallel-testing-enabled NO`.** Parallel runs clone the simulator, and the clones fail wholesale with `Invalid device state` / `Mach error -308 — server died` before a single assertion runs. The failure looks nothing like a test failure, so it's easy to misread as a broken build.
- **Check the simulator's Dynamic Type size before believing a failure.** At `accessibility-*` content sizes the header chips and the Teams search field no longer fit, so queries for them find nothing and previously-passing tests fail in unrelated-looking places. `ScreenshotTests` documents setting appearance and text size for accessibility passes; that state persists on the device afterward. Reset with `xcrun simctl ui <udid> content_size large` — `large` is the iOS default, so it's what both the tests and the App Store screenshots assume. Pass the **UDID, not the device name**: `iPhone 17 Pro` exists on several runtimes and xcodebuild's pick between them isn't stable.

- **The iPhone Duo has two displays, and every default points at the wrong one.** `simctl io <udid> enumerate` lists two `Display class: 0` framebuffers: 2007x2853 (669x951pt) and 1398x2034 (466x678pt). The larger is what `simctl io screenshot` captures by default, and on a device at rest it renders **pure black** — a booted, healthy sim looks like it failed to launch. The live panel is the smaller one; pass `--display=<uuid>`. The UUIDs are regenerated on every boot, so re-read them from `enumerate` in the session and never hardcode one. Injected taps land on the wrong display too: a tap at coordinates in the advertised 466x678 space hit nothing twice and backgrounded the app once, and `inspect` (accessibility-tree readback) is unavailable on the 27.1 runtime, so screenshots are the only verification. Recorded 2026-09-21 while standing the Duo up; no suite targets a Duo destination yet, so this is preventive. Related: `simctl boot` starts a device headlessly, and **Xcode 27.0 and 27.1 beta ship no `Simulator.app`** — Xcode 26.6's is the only one on the machine.

Because the data is live, assertions must not encode calendar facts. Don't wait on a specific poll (the AP Top 25 doesn't exist until mid-August, and `RankingsScreen` hides the picker entirely when only one poll came back) or on a specific week's games. Shared helpers for the recurring traps — retrying a tab tap that a navigation transition swallowed, scrolling the week strip without oscillating — live in `sportsUITests/UITestSupport.swift`.

## Decisions log

**Lives in [`docs/decisions.md`](docs/decisions.md)** — 211 rows, oldest first. Moved
out of this file on 2026-09-13, when it passed the 150k-character context limit and the
log was 92% of it.

**Read it before changing product behavior.** It is the record of *why* the app is the
way it is, and it is load-bearing: several of its own rows exist because a session
re-derived something the log had already settled. The § Don'ts below are its distilled
form, not a substitute — `tail -40 docs/decisions.md` is the cheap way in, and the whole
file is worth a read before a feature that touches an existing surface.

**Every decision gets a row there**, dated, with the reasoning and not just the change.
A PR that adds one must also add a row to `docs/web-parity.md`; `scripts/check-parity-ledger.sh`
enforces it in web CI.

## Don'ts

- Don't add colors beyond the budget. If a design problem seems to need color, it needs weight, size, or spacing instead.
- Don't dedupe games across sections.
- Don't let a date picker *replace* the day strip. The strip is the Scores screen's axis (2026-09-05); the calendar sheet added 2026-09-06 is a jump-to shortcut beside it, bounded by the same season, and supersedes this don't's original "not a calendar modal" clause.
- Don't add third-party packages, analytics, or a backend without an explicit conversation first.
- Don't edit `project.pbxproj` file references by hand — synchronized groups make file management automatic. Build settings, and target/build-phase additions when adding a new target, are allowed (amended 2026-08-04 for the widget extension); always verify with `plutil -lint` + a full build.
- Don't build for iPad/Mac/Vision idioms in v1.
- Don't generalize a football shape onto a sport that doesn't have it. Drives, downs, the Gamecast field strip, weeks and the polls are football's; they hide themselves for the other leagues rather than growing a basketball meaning. The test is whether the payload carries it, not whether the code could be made to.
- Don't let a `dates=` window truncate in silence. ESPN caps one at `limit` events and cuts the rest with **no flag, no count and no cursor** — a request that looks like it worked is missing February. A window that comes back at exactly the limit is the only signal there is, and `ESPNClient.seasonGames(days:groups:)` re-asks the month as its own days rather than trusting a span. *(Amended 2026-09-10, superseding both the per-league gate and the claim that `groups=` is ignored outside college football: it narrows the slate in every league we cover, and the cap is per **group**, not per league. Amended again 2026-09-17: the halving this used to describe went with the range form below.)*
- Don't ask for a `dates=` range. `dates=A-B` was withdrawn (2026-09-17) and now 400s in every league, past seasons included — the only tokens ESPN still honours are a day (`20260917`), a month (`202609`) and a year (`2026`). A window is one request per day; a season is one per month. Re-probe before assuming it came back.
- Don't raise `limit` past 500. It does not clamp — `limit=501` collapses the response to ESPN's default 25 events and still answers 200, so the truncation guard above can't see it either. The 900 that sat here until 2026-09-17 meant every season request had been quietly answering with 25 games.
- Don't start coding a feature that isn't in BACKLOG.md — add it to the backlog and discuss first.
