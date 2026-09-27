# News: a pattern brief

**Status:** **accepted and built, 2026-09-27.** Written as a proposal the same day; Andy's call was to build it with this brief as the source of truth. It un-ices part of BACKLOG's Icebox line *"News content (may be never; scores-first is the identity)"* and nothing more. Backlog: E25. The decisions are rows in [`decisions.md`](decisions.md) and [`web-parity.md`](web-parity.md).

News attaches to games and teams, reads natively, and ends in a follow. There's no News tab, no photos, and nothing labeled "related" that isn't. 16 decisions follow, each traced to the FotMob screen it came from.

Every reference is FotMob iOS on Mobbin, because that's the only app researched. **Adopt** takes the FotMob pattern as is, **Adapt** changes it to fit StatSide, **Don't take** cites the FotMob screen being declined, and **Park** means not now.

## Reference screens

| Ref | Screen |
|---|---|
| R1 | [News tab · For you](https://mobbin.com/screens/bfd98a17-3d48-4413-92e8-d7c68067079e) |
| R2 | [News tab · Transfers](https://mobbin.com/screens/3a3740f0-55ca-47d1-8a8e-f13c08da7659) |
| R3 | [For you filter sheet](https://mobbin.com/screens/ef642ae4-14ac-4845-a795-fc9904cd21c3) |
| R4 | [Final match · Facts](https://mobbin.com/screens/6c1b4111-3a96-4b03-9859-aebf5c45a4bf) (also [Sunderland v Everton](https://mobbin.com/screens/f4018c82-d935-4d69-a0e8-85bbe5ea7515)) |
| R5 | [Pre-match · Preview](https://mobbin.com/screens/b9e862bd-e136-4f9e-9231-13e0ebe35d7d) |
| R6 | [Article · top](https://mobbin.com/screens/fcf0d79f-1900-4aa8-b259-0cd408518346) |
| R7 | [Article · tail](https://mobbin.com/screens/e76a73ae-03b8-4beb-b46e-138ede13d8d7) |
| R8 | [Match · Related news](https://mobbin.com/screens/714b46d5-6d14-4e30-b1b4-f7156ce6db2b) |
| R9 | [Team · News tab](https://mobbin.com/screens/3655d081-0df1-47f4-a010-5c792bef52f7) |
| R10 | [Player · News card](https://mobbin.com/screens/74f4694b-05f4-464d-bb26-45f8d7a13795) |
| R11 | [Team · Daily summary](https://mobbin.com/screens/9078ecec-a2fc-49e8-a751-eb3ed62261ed) |
| R12 | [News widgets](https://mobbin.com/screens/88e2cccc-0a6c-43ec-9f00-7ad4e55a0d54) |

Flows: [News](https://mobbin.com/flows/6b380a74-8f75-4159-af29-7aad2dc57d07) · [Article detail](https://mobbin.com/flows/c834c5a9-b1d4-4bcf-8b19-93eba7ded2bf) · [Filtering news](https://mobbin.com/flows/1cafbc7d-c079-45fe-95fa-2386213c39ea) · [Team detail](https://mobbin.com/flows/24ca03a2-e9e2-4bb7-9172-00a8b8f9d033)

## Where news lives

### N1 · Don't take · No News tab. News appears only attached to a game or a team.

*Superseded 2026-09-27 (E26): Andy added a News tab, second in the bottom bar, with For you and a page per league. Stories still attach to games and teams too.*
**From FotMob:** R1

FotMob gives News the 2nd slot in its tab bar. StatSide's charter keeps scores first, and the Scores sort order is the product. Attaching news to entities gets most of the value without a destination competing with Scores.

### N2 · Adapt · A finished game's page opens with a recap card, directly under the header.
**From FotMob:** R4

FotMob leads the Facts tab with the match report, above highlights and Player of the Match. Source: the summary's `article` block, which the game page already fetches, so this costs **0 extra requests**. Show it only when the game is final, `article.type == "Recap"` and `article.gameId` matches the event. All 3 league fixtures (`summary-final-live.json`, `nba-summary.json`, `nhl-summary.json`) carry one: AP, 3.3k to 7.7k characters of `story`. Card: 2-line headline, then `AP · 2h ago`.

### N3 · Adapt · A pre-game page shows a preview card only when the summary's article is a Preview.
**From FotMob:** R5

FotMob slots the preview story between the prediction poll and venue info. Same card as N2, gated on `article.type == "Preview"`. **Probed 2026-09-27:** an NFL pre-game summary (ARI @ SF) carries an AP Preview with its `gameId`; a live NFL game and one that had just gone final carried no article, and the NBA and NHL preseason games carried none. Live games get no article card either way, since live state spends the visual budget. **As built:** the preview follows the Game info card, because when and where to watch is still the first pre-game question; the recap leads a final's Summary tab.

## The reader

### N4 · Adopt · Tapping a story opens a native reader in-app, never Safari.
**From FotMob:** R6

FotMob renders articles natively, inside its own nav stack. A recap's `story` HTML is already in the summary payload; convert it to paragraphs of `AttributedString`. Team-feed stories (N9) need one request to `links.api.self` on tap. A story with no body text doesn't get a row at all, so no row ever bounces the user out to espn.com.

### N5 · Adopt · Reader order: headline, source and exact time, dek, the game's own score row, then body.
**From FotMob:** R6

FotMob puts a score card for the match inside the article, above the body. StatSide reuses `GameRow` there, tappable back to the game page, and only for stories carrying a `gameId`. The dek is `article.description`.

### N6 · Adapt · The reader ends with "In this story": one row per tagged team, each with the existing follow pill.
**From FotMob:** R7

FotMob closes every article with Follow pills for its teams and competitions, so reading turns into follows. ESPN's `categories` give `type: team` with a `teamId`, which maps straight to a follow. Competition pills are dropped: follows are team-shaped by decision (BACKLOG, "Follows stay team-shaped"). Teams outside our 4 leagues are dropped silently.

### N7 · Adopt · Lists use relative time; the reader uses exact time.
**From FotMob:** R1, R6

FotMob shows `SI · 8 hours ago` in feeds and `Nov 5, 2025 at 5:06 AM` on the article. Same split here: `2h ago` / `Yesterday` / `Sep 24` in rows, full date and time in the reader.

## What a list shows

### N8 · Don't take · No photos anywhere in News. Rows are text: headline, then source and time.
**From FotMob:** R1, R4, R9

Every FotMob news surface leans on full-color photography. The color budget has 5 exceptions and press photos aren't one of them; the full-size headshot on the player page is the only photo in the app, and it's a fact about the player. **Andy's call** if photos should become a 6th exception.

### N9 · Adapt · Team pages get a News tab, last in the tab row, filtered to stories that are actually about the team.
**From FotMob:** R9

FotMob puts News 2nd on a team page; StatSide puts it last, after the pages about scores. *(Superseded 2026-09-27, E26: News is second on the team page too, after Overview.)* Source: `/news?team={id}&limit=25`, fetched when the tab is first opened and cached for the session (the Player Games tab pattern).

ESPN's `team=` filter is loose: every result is tagged with the team, but most are league roundups (Michigan's feed led with SP+ rankings for all 138 FBS teams). Keep only stories tagging **2 teams or fewer**. Probe on 2026-09-27: Michigan kept 6 of 25, the Knicks 11 of 25. Empty state: *"No Michigan stories right now."*

### N10 · Don't take · Keep Recap, Preview, HeadlineNews and Story types; drop Media and Eticket.
**From FotMob:** R8

FotMob mixes YouTube highlights into its lists. ESPN's `Media` items link out to the SportsCenter app or web with no playable asset we can use, and `Eticket` is ticket commerce, which the Icebox already keeps out.

### N11 · Don't take · No "Related news" list on game pages or in the reader.
**From FotMob:** R8, R7

FotMob runs Related news under both. ESPN's summary does carry a `news.articles` block, but it's the league feed with no relation to the game: the CFP final fixture (Jan 20) carries a July story about Tennessee's QBs. Labeling it "related" would be false.

## Not taking

### N12 · Don't take · No personalized feed and no news filter sheet.
**From FotMob:** R3

Follows from N1. If a feed ever lands, FotMob's rule is the one to take: rank by the order of your follows, with no separate interest picker.

### N13 · Don't take · No news on player pages.
**From FotMob:** R10

FotMob puts a News card at the foot of the player Profile. BACKLOG already answers this one: "No player news, per the charter." *(Superseded 2026-09-27, E26: the player page has a News tab, second after Profile.)*

### N14 · Don't take · No generated summaries.
**From FotMob:** R11

FotMob writes a Daily summary on team Overview. StatSide has no backend and no model, and it has only ever published text and numbers ESPN sent (the Career tab was held to the same line).

### N15 · Don't take · No news in widgets.
**From FotMob:** R12

FotMob ships News and Trending widgets. StatSide's widget is scores; a headline would take space from the next game.

### N16 · Park · A Transfers-style module for recruiting commitments and pro trades.
**From FotMob:** R2

FotMob's Transfer Center puts structured from-club → to-club cards above prose. The shape fits college commitments and NFL/NBA/NHL trades. No ESPN source has been probed, so it stays parked. *(2026-09-27: the pro half shipped as a Trades tab on pro team and league pages, BACKLOG E24, #234. It prints ESPN's transaction sentences, since `/transactions` carries no from/to or fee for cards like FotMob's. College commitments stay parked: ESPN has no feed.)*

## Open for Andy

- **N8, photos.** Built text-only, as recommended. Photos would be the budget's 6th exception, and every news surface would then carry uncontrolled color. Parked as an E25 P3.
- ~~**N3, preview probe.**~~ Resolved 2026-09-27, above.
- ~~**N9, NFL team feed.**~~ Resolved 2026-09-27 through the web's News route: the Vikings kept 6 of 25.

## As built

- **Host.** The team feed uses `site.web.api.espn.com`. On `site.api` the same path answers 403 to a browser or empty User-Agent; `site.web.api` answers all of them. The reader's body comes from `content.core.api.espn.com/v1/sports/news/{id}`, which the feed links as `links.api.self`.
- **Type.** No new tokens. Headline `heroTitle`, paragraphs `teamName`, subheads and row headlines `teamNameEmphasis`, meta `meta`. Cards are `CardHeader` + `cardSurface()`; the game row is `GameRow` in `NextGameCard`'s recipe; follow rows are `TeamFollowRow(opensTeam: true)`.
- **Web.** `web/src/lib/news.ts` and `web/src/lib/espn/news.ts` port the model, parser and mapper; `StoryRow` and `StoryMeta` in `web/src/components/`; the reader is `/story/{league}/{id}`, which rebuilds a story from the content API by id, so its score row always links. Tests: `web/src/lib/news.test.ts`, over the same fixtures.
- **Code.** `NewsStory`, `StoryText`, `NewsTimestamp` (StatSideShared/Models), `NewsClient` + `NewsMapper` (StatSideShared/Networking), and `sports/Features/News/`: `StoryRow`, `StoryReader`, `StoryBodyCard`, `StoryTeamsCard`, `StoryListCard`, `StoryDestination`, and the News tab's `NewsScreen` with `NewsFeedStore` (E26). Tests: `sportsTests/NewsTests.swift`.
