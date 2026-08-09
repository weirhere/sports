# StatSide

A college football scores app for iPhone. One sport, done fast, in black and white.

The target user checks scores twenty times on a fall Saturday and is tired of ad-stuffed everything-apps where college football is one tab among thirty. Speed and focus are the product: the landing screen answers "what's the state of college football right now" in one thumb, one scroll.

**Scores** — your followed teams first, then Top 25, then every conference, as accordions. Games appear in every section they belong to; sections are complete rather than deduplicated. **Rankings** — AP, Coaches, and CFP once it exists. **Teams** — browse or search, follow, see a schedule. Plus a home-screen widget for your next game and a local reminder 30 minutes before kickoff.

Week is the unit of time, not the day — fans think in weeks, and a date scroller would spend most of the season showing empty Tuesdays.

## Requirements

- Xcode 26.x (iOS 26 SDK)
- Deployment target **iOS 18.0** — don't reach for iOS 26-only APIs without an `#available` guard
- iPhone only. iPad, Mac, and Vision idioms are explicitly out of scope for v1
- No package manager step: **zero third-party dependencies**, by decision

## Build and run

```bash
xcodebuild -project sports.xcodeproj -scheme sports -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Or open `sports.xcodeproj` and hit run. The `sports` scheme builds the app and embeds the `StatSideWidgets` extension.

One gotcha worth knowing: build from a directory outside `~/Documents`. iCloud extended attributes on files there break code signing.

## Tests

```bash
xcodebuild test -project sports.xcodeproj -scheme sports -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -parallel-testing-enabled NO
```

`sportsTests` is fast and hermetic — decoding against fixtures, week rollover, section bucketing, notification scheduling, accessibility label shapes.

`sportsUITests` drives the real app against the live ESPN API. It needs `-parallel-testing-enabled NO`, and a simulator left at an accessibility text size will fail it in misleading ways. See **Running the UI tests** in [CLAUDE.md](CLAUDE.md) before debugging a failure there.

## Layout

| Path | What lives there |
|---|---|
| `sports/` | The app — `App/`, `Theme/`, `Stores/`, `Intents/`, `Features/{Scores,Rankings,GameDetail,Teams}/` |
| `StatSideShared/` | Models, networking, theme tokens — compiled into **both** the app and the widget |
| `StatSideWidgets/` | Widget extension (next-game widget) |
| `Config/` | Entitlements and export options |
| `docs/` | Landing page, privacy page, App Store listing and screenshots, social assets |

Both `sports/` and `StatSideShared/` are Xcode *synchronized root groups*: a file added on disk joins the target automatically, so `project.pbxproj` never needs hand-editing to add files.

## Data

There is no backend, no account, and no analytics. The app talks directly to ESPN's unofficial college football API.

That API is undocumented and can change without notice, so every response field is optional in the decoders and a missing field degrades a row rather than crashing. ESPN's shapes stay in DTO structs and are mapped to domain models at the client boundary, which keeps the blast radius of a source change to one layer — `ScoresProviding` is the seam. A CollegeFootballData.com client implements the same protocol; it's opt-in via the `data.provider` and `cfbd.apiKey` defaults and needs a key.

The scoreboard is polled no faster than every 30s, only while the app is foregrounded and games are live. Be a polite guest.

## Design system

Black, white, and grays for all chrome, text, and backgrounds, in both light and dark. Colour is spent in exactly three places, and nowhere else:

1. **Logos** — team and conference, in full colour. Grayscale would make Michigan and Iowa look like the same team.
2. **The live indicator** — a pulsing dot and score emphasis, in the app's single red.
3. **Rankings movement** — green up, red down, the same red. Arrows carry the meaning too, so colour is never the only signal.

If a design problem seems to need a new colour, it needs weight, size, or spacing instead.

## Docs

- [CLAUDE.md](CLAUDE.md) — working agreement: principles, constraints, conventions, the decisions log, and the don'ts. **Read before writing code.**
- [ARCHITECTURE.md](ARCHITECTURE.md) — layering, folder layout, and the field-level ESPN API reference
- [ROADMAP.md](ROADMAP.md) — phases and the north star
- [BACKLOG.md](BACKLOG.md) — everything planned, by priority. Nothing gets built that isn't here
- [PRIVACY.md](PRIVACY.md) — the privacy policy (no data collected)
