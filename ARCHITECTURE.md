# ARCHITECTURE.md — sports

## Shape of the app

SwiftUI, MVVM-lite, no backend. Three layers, dependencies point one way:

```
Views (Features/*)          — SwiftUI, dumb, render domain models
  ↓
Stores & ViewModels         — @Observable, own state + orchestration
  ↓
Networking + Models         — ESPNClient (DTOs) → domain models
```

ESPN's JSON shapes never leave the networking layer. Views never see a DTO.

## Folder layout

```
StatSideShared/              — compiled into BOTH the app and the widget extension
  AppGroup.swift             — shared-suite contract: suite id, keys, follows migration
  GameSelection.swift        — pure widget selection + refresh-policy rules (unit-tested)
  Models/                    — Game, Team, Ranking, Week, Scoreboard, TeamSchedule,
                               GameSummary, Game+ShareText — all nonisolated Sendable
  Networking/                — ESPNClient (+ ScoresProviding protocol + mapper), DTOs,
                               CFBD trio, DataProvider, LogoCache
  Theme/Theme.swift          — semantic colors (mono ramp + liveAccent), spacing, type styles
StatSideWidgets/             — the widget extension target (appex, embedded in the app)
  StatSideWidgetsBundle.swift, NextGameWidget.swift, NextGameProvider.swift,
  NextGameEntry.swift (+ WidgetSnapshot), NextGameViews.swift, WidgetLogoFetcher.swift,
  Info.plist               — NSExtension only (membership-excepted from resources)
Config/                      — sports.entitlements, StatSideWidgets.entitlements (App Group)
sports/
  App/
    sportsApp.swift          — entry point; follows migration + notification delegate wiring
    RootView.swift           — TabView: Scores | Rankings | Teams; deep-link + reminder wiring
    DeepLink.swift           — statside://game/{id} | team/{id} | teams (scheme unregistered)
    Router.swift             — pending navigation intents from widget/notification taps
    NotificationDelegate.swift — foreground presentation + tap → Router
  Stores/
    FollowingStore.swift     — Set<Team.ID> in the App Group suite; nudges widget reloads
    UIStateStore.swift       — accordion expansion, last poll choice, in UserDefaults
    ScoreboardStore.swift    — current week, games, polling loop, section grouping
    NotificationScheduler.swift — kickoff reminders (see Notifications below)
  Intents/
    NextGameIntent.swift     — "What's my next game?" App Intent + Siri Shortcut
  Features/
    Scores/                  — ScoresScreen, WeekStrip, SectionAccordion,
                               GameRow (+ Pre/Live/Final variants), LiveDot, DayDivider
    Rankings/                — RankingsScreen, PollPicker, RankRow
    GameDetail/              — GameDetailScreen, LineScoreGrid, ScoringPlaysList, TeamStatsCompare
    Teams/                   — TeamsScreen (browse/search), TeamPage, FollowButton, NotificationBell
```

Files added under a synchronized root group are auto-included in its target(s)
(`objectVersion 77`); `StatSideShared/` belongs to both the app and widget targets.

## Key mechanics

### Week model
ESPN's `leagues[0].calendar` provides labeled periods (Regular Season, Postseason) whose `entries[]` carry `label`, `value`, `startDate`, `endDate` per week. Parse once per launch into `[WeekSlot]` and drive the strip from it — never hardcode week counts (Week 0 exists some years, CFP rounds shift). Current week comes from top-level `week.number` + `season.type`.

**Rollover rule:** the strip's default selection is the ESPN current week, except Sundays, where we pin to the week that just completed (Sunday is catch-up + new poll day; flip Monday morning). Implement as: if today is Sunday and ESPN says week N+1, show N.

### Section grouping
`ScoreboardStore` groups one week's games into ordered sections:

1. **Following** — any game where either competitor ∈ FollowingStore (skip section if empty)
2. **Top 25** — any game where either competitor has `curatedRank.current ≤ 25`
3. **One section per conference** — via `team.conferenceId`, ordered by relevance: followed team's conference first, then Power 4, then Group of 5, then Independents; unknown ids bucket into "Other"

Games intentionally appear in multiple sections. Within a section: chronological, with day dividers (Thu/Fri/Sat) only when the section spans multiple days. Conference chips scroll-anchor to sections (`ScrollViewReader`), never filter. The Live toggle is the only filter: it collapses each section to in-progress games and hides empty sections.

Conference id map (hardcode with an "Other" fallback; ids verified against ESPN groups): ACC 1, American 151, Big 12 4, Big Ten 5, C-USA 12, Independents 18, MAC 15, Mountain West 17, Pac-12 9, SEC 8, Sun Belt 37, FBS umbrella 80.

### Live updates
- Foreground + at least one live game: re-fetch scoreboard every 30s (`Task.sleep` loop, cancelled on background/scene change).
- No live games: no polling; pull-to-refresh only.
- Diff by event id and update in place so accordion/scroll state survives refreshes.

### Persistence
UserDefaults only, in two suites. **App Group suite** (`group.com.andyryanweir.sports`, via `AppGroup.defaults`): `following.teamIds: [String]` — shared with the widget and the App Intent — plus the widget's `widget.snapshot` blob and the one-shot `migration.followingToGroup.done` flag (follows are copied from standard defaults once; the standard copy stays for rollback safety). **Standard defaults**: all `ui.*` state and `notifications.enabled` — app-only, no reason to share. No cache of API responses in v1 beyond in-memory (URLCache gets default behavior for free) and the widget's logo byte-cache in the group container.

### Widget (StatSideWidgets)
`NextGameProvider` fetches the current-week scoreboard directly (the widget must be live without the app opening; WidgetKit's ~40–70/day reload budget is the politeness throttle). Families are systemMedium + systemLarge + accessoryRectangular — both system sizes render the same FotMob-style stacked list (`WidgetGameList`: ★ Following header, roomy rows, medium 2 games / large 5 plus an updated/as-of footer). Selection and reload policy are pure functions in `StatSideShared/GameSelection.swift`: live games poll at 15 min, an imminent kickoff pulls the next reload to kickoff+60s, quiet weeks go hourly; the provider selects 5 games for every family (one shared snapshot serves all placed instances). Every successful fetch writes a `WidgetSnapshot` to the group suite; a failed fetch re-serves it marked "as of h:mm" — the entry dated at the snapshot's save time, so the marker tells the truth. Logos are fetched in the provider (widget views can't load async) in both light and `500-dark` variants — the view picks per color scheme — and byte-cached in the group container; the dark URL is derived from the stored light one, never persisted. Widget taps deep-link via `statside://` → `onOpenURL` → `Router`; the scheme is intentionally unregistered (widgetURL delivers to the containing app without `CFBundleURLTypes`).

### Notifications
`NotificationScheduler` (Stores/) schedules one local reminder per followed game, 30 minutes before kickoff, nearest 24 games (headroom under iOS's 64-pending cap). Request ids encode the kickoff instant (`kickoff.{gameId}.{unixTime}`), so a moved kickoff, a cancellation, or a TBD time becoming real all resolve as a plain pending-vs-desired diff — no special cases. Resync runs on follow/unfollow, scene-active, and enable; data comes from `teamSchedule(teamId:)` per followed team (1–5 requests, resync-only). Permission is requested contextually — bell tap on TeamPage or a one-time post-first-follow alert — never at launch; a denied state routes the bell to the system's notification settings. The `NotificationCentering` protocol wraps `UNUserNotificationCenter` so tests inject a fake. Taps carry `userInfo["gameId"]` → `NotificationDelegate` → `Router`, the same path widget taps use.

### Theme
Semantic tokens, never raw colors in views: `.bgPrimary`, `.bgElevated`, `.textPrimary`, `.textSecondary`, `.divider`, `.liveAccent` (the red dot — the app's only accent). Light and dark are the same design inverted. Scores use `.monospacedDigit()`. Logos render through `LogoImage` (Theme/), backed by the `LogoCache` actor — dedupes in-flight fetches, remembers successes, retries transient failures on reappearance (full color, the monochrome exception). In dark mode `LogoImage` requests ESPN's `500-dark` team variant, derived by `URL.darkTeamLogoVariant` (StatSideShared/Models/LogoVariant.swift) because the scoreboard payload only carries the light URL; a team without a dark mark falls back to its light logo, and the 404 is negative-cached so it costs one request ever. Conference marks derive no variant and keep the `logoBacking` disc.

### Concurrency note
Project sets `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor`. `ESPNClient` should be explicitly `nonisolated`/`actor` so decoding stays off the main thread; everything else defaulting to MainActor is fine at this app's scale.

## API reference (shapes verified live 2026-07-21)

Base: `https://site.api.espn.com/apis/site/v2/sports/football/college-football`

### `/scoreboard?groups=80&limit=300&week={n}&seasontype={2|3}`
- Top level: `leagues[]`, `season{type,year}`, `week{number}`, `events[]`
- `leagues[0].calendar[]`: `{label, value, startDate, endDate, entries[{label, alternateLabel, detail, value, startDate, endDate}]}`
- `events[]`: `id, date, name, shortName, week{number}, status, competitions[]`
- `events[].status`: `clock, displayClock, period, type{id, name, state ("pre"|"in"|"post"), completed, detail, shortDetail}`
- `competitions[0].competitors[]`: `homeAway, score (string), records[{name, abbreviation, type, summary}], curatedRank, team{id, location, name, abbreviation, displayName, shortDisplayName, color, alternateColor, logo, conferenceId}`
- Network: `competitions[0].broadcasts[{market, names[]}]` and convenience string `broadcast`
- `competitions[0].timeValid: false` marks a kickoff whose time is unannounced — `date` is then a placeholder midnight ET. Mapped to `Game.timeTBD`; render "TBD", never the placeholder clock

### `/rankings`
- `rankings[]`: `{id, name, shortName, type, occurrence, headline, ranks[]}` — AP, Coaches, CFP when in season
- `ranks[]`: `{current, previous, points, firstPlaceVotes, trend, recordSummary, team{id, location, name, nickname, abbreviation, color, logo, logos[]}}`
- Movement = `previous` − `current`; `trend` is also provided as a string

### `/summary?event={id}`
- `boxscore.teams[]`: `{team, homeAway, statistics[{name, label, displayValue, value}]}`
- `boxscore.players[]`: per-team `statistics[]` with `labels[]`, `athletes[{athlete{displayName, jersey, headshot}, stats[]}]` — leaders/box score source
- `scoringPlays` via `drives.previous[].plays[]` (`scoringPlay: true`) and a top-level `scoringPlays[]` when present: `{period, clock, text, awayScore, homeScore, team, type}`
- `header.competitions[0].competitors[].linescores[]` — per-quarter line score
- `gameInfo`: `{venue{fullName, address}, attendance}`
- `drives.previous[]`: full drive log — the DRIVES section's source. `displayResult` ("Punt") beats the ALL-CAPS `result`; `description` is a pre-built "5 plays, 20 yards, 2:39" line; `start.period.number` drives the quarter markers

### Teams + schedules (shapes verified live 2026-07-20)

**`/teams?limit=1000` is useless for browse**: it returns all 755 teams across every division with *no conference data*, and ignores `groups=` filters. Conference membership comes from the standings API instead:

- **`https://site.api.espn.com/apis/v2/sports/football/college-football/standings?group=80`** (note: `apis/v2`, not `apis/site/v2`) — one request returns 11 FBS conference `children[]`, each with `standings.entries[].team` carrying id, names, and `logos[]`. This is the Teams-browse source. Offseason quirk: a conference can have zero entries (Sun Belt did on 2026-07-20); render what's there.

**`/teams/{id}/schedule`** — quirks vs. the scoreboard shape, all handled in dedicated DTOs:
- `score` is an object `{value, displayValue}`, not a string
- `record` is an array (type `total` carries the summary), not `records`
- `status` lives on `competitions[0]`, not the event
- broadcasts nest as `broadcasts[].media.shortName`
- `timeValid` rides on both the event and `competitions[0]` here (scoreboard carries it on the competition only); false = kickoff time unannounced, `date` is a placeholder midnight ET
- a bare request inherits ESPN's "current" season *type*, which is the empty preseason (`type: 1`, `events: []`) from February until kickoff — always pass `?season={year}&seasontype=2` explicitly (verified live 2026-08-09; `?season=` alone is not enough, the type stays preseason)
- postseason games only appear under `?season={year}&seasontype=3` — a separate request, merged client-side; a team with no bowl returns `events: []`. Every season therefore costs two requests; TeamPage caches each fetched season for the visit so re-selecting one refetches nothing
- top-level `season` is ESPN's *current* season, `requestedSeason` the one actually returned — `TeamSchedule.year` maps from `requestedSeason.year`, which is how the UI labels the season honestly (including the fallback below)
- `team.recordSummary`/`standingSummary` describe ESPN's **current** season even when a past one was requested (fixture: requested 2025 → `recordSummary: "0-0"`, `seasonSummary: "2026"`) — the mapper keeps them only when `season.year == requestedSeason.year` and nils them otherwise; past-season records derive from the games' `winner` flags instead
- `ESPNClient.teamSchedule(teamId:year:)` with `year: nil` falls back to `season - 1` when the current season maps to zero games (next season unpublished ~Feb–July), so TeamPage shows last season's results instead of "Schedule TBA". An **explicit** year never falls back — the team page's season selector must show exactly the season it claims

### `/summary` extras
`leaders[]` at the top level (per team: `passingYards`/`rushingYards`/`receivingYards` categories with `athlete` + `displayValue`) is the game-detail leaders source — simpler than reassembling from `boxscore.players`. Header competitors carry `linescores[].displayValue` and a `record` array.

## Failure posture

- Every DTO field optional; a partial row renders partially (no network? show time TBD; no record? omit it). Decode failure of one event drops that event, never the screen.
- Screen-level states: loading (skeleton rows), error (retry button, last-good data if any), empty (offseason/bye messaging).
- If ESPN breaks mid-season: domain models are the contract; write a CFBD-backed client conforming to the same protocol (`ScoresProviding`) and swap. Design `ESPNClient` behind that protocol from day one — it costs nothing now and is the whole insurance policy.
