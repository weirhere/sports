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

- File layout under `sports/`: `App/`, `Theme/`, `Models/`, `Networking/`, `Stores/`, `Features/{Scores,Rankings,GameDetail,Teams}/`.
- State: `@Observable` classes (iOS 17+, fine for our 18.0 floor), owned by views via `@State`, passed via `@Environment`.
- One view per file. Views over ~100 lines get decomposed.
- Names say what things are: `GameRow`, `WeekStrip`, `ConferenceAccordion`, `LiveDot`. No `Manager`, no `Helper`, no `Utils`.

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

## Don'ts

- Don't add colors beyond the budget. If a design problem seems to need color, it needs weight, size, or spacing instead.
- Don't dedupe games across sections.
- Don't add a date picker or day-based navigation.
- Don't add third-party packages, analytics, or a backend without an explicit conversation first.
- Don't edit `project.pbxproj` except for the deployment-target change (synchronized groups make file management automatic).
- Don't build for iPad/Mac/Vision idioms in v1.
- Don't start coding a feature that isn't in BACKLOG.md — add it to the backlog and discuss first.
