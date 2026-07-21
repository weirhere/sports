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
- [ ] **P1** Day dividers inside sections spanning multiple days (Thu/Fri/Sat, whisper-quiet). Field note 2026-07-20: ESPN's 2026 "Week 1" spans two weekends (Aug 22–Sep 8), so weekday alone is ambiguous — dividers need dates ("Sat Aug 29"), and pre-row kick times may too.
- [ ] **P1** Conference section ordering personalizes: followed team's conference first, then P4 → G5 → Independents.
- [ ] **P1** Screen states: skeleton loading, error-with-retry (keep last good data), offseason/empty week state with next-kickoff countdown.

## E2 — Game detail

- [ ] **P1** Header: teams, records, score, status; linescore grid by quarter (incl. OT columns).
- [ ] **P1** Scoring plays list, chronological with period markers.
- [ ] **P1** Team stats comparison (total yards, pass/rush, 3rd down, TOs, possession) as opposing mono bars.
- [ ] **P1** Leaders (pass/rush/receive per team).
- [ ] **P2** Live auto-refresh on this screen while game is in progress.
- [ ] **P2** Drive log (data already in `drives.previous[]`).

## E3 — Rankings

- [ ] **P1** AP Top 25 default; segmented picker for Coaches and CFP (CFP appears only when ESPN returns it).
- [ ] **P1** Rank row: rank, logo, team, record, movement arrow (▲/▼/–, derived from `previous` − `current`), first-place votes where present. Monochrome arrows; movement shown by weight not color.
- [ ] **P2** Tap rank row → team page.

## E4 — Teams + following

- [ ] **P1** Team browse: searchable FBS list grouped by conference.
- [ ] **P1** Follow/unfollow, persisted. Acceptance: follows survive relaunch; Scores Following section updates immediately.
- [ ] **P1** Team page: identity header, record, current-season schedule with results, follow button.
- [ ] **P2** Onboarding moment: first launch prompts "pick your teams" (skippable).

## E5 — Season hardening (in-season, field-notes-driven)

- [ ] **P1** First-live-game verification pass (earliest: Week 1, Aug 22): live/final row variants on-device, Live toggle, 30s polling logs, in-place update preserving scroll/accordion state. Everything is unit/preview-verified but ESPN serves only pre-game states until then.
- [ ] **P1** Performance pass with a full Saturday slate (60+ events, all sections expanded).
- [ ] **P2** Rankings ghost-week handling (poll updates Sunday while week still shows Saturday's games).
- [ ] **P2** Week rollover edge cases: Week 0, Army-Navy solo week, CFP date ranges.
- [ ] **P2** Accessibility pass: Dynamic Type, VoiceOver labels on rows ("Georgia 24, Tennessee 17, 3rd quarter"), contrast check on grays.

## Icebox (deliberately not now)

- Widgets / Live Activities (likely the killer feature; after row design is proven in-app)
- Notifications
- College basketball (the offseason answer: same schools, same follows)
- FCS/lower divisions
- News content (may be never; scores-first is the identity)
- App Store release + data licensing (CFBD or paid provider)
- iPad/Mac/visionOS layouts

## Open questions

1. **App name.** "sports" is the repo, not the name. Monochrome + CFB suggests something spare. (Parking lot: Gridiron? Kickoff? Saturday?)
2. **Live accent color.** Red assumed; confirm it's the *only* accent, or go full monochrome with a pulsing white/black dot? Decide when the row is on a real screen.
3. **Top 25 section: ranked-vs-ranked only, or any game involving a ranked team?** Current assumption: any ranked participant. Revisit if the section gets bloated on full slates.
4. **FCS games that leak into `groups=80` responses** (FBS-vs-FCS matchups): confirm they render sanely in the FBS opponent's conference section.
5. **Following a conference** (not just teams) — worth it? Wait for field notes.
