# StatSide web

The web companion to StatSide, the iOS college football scores app. A Next.js app being brought to feature parity with the iOS app — web mirrors iOS exactly, so anything the iOS app doesn't have is being removed rather than maintained.

Runs on live ESPN data through `src/lib/espn/` — there is no mock mode and no `USE_ESPN` switch any more.

## Develop

```sh
npm install
npm run dev
```

Lint, typecheck, and build with `npm run lint`, `npm run typecheck`, and `npm run build`.

## Link previews

A game page carries the OpenGraph card a link wears when it's pasted into
Slack, posted on X, or unfurled anywhere else — `opengraph-image.tsx` beside
the game page renders it, and `og-card.ts` derives every string in it.

Worth knowing before touching either:

- **iMessage doesn't use this.** The iOS app hands Messages its own preview
  image via `LPLinkMetadata`. Every *other* unfurler builds the card on its
  own server from this page's `og:` tags, which is the only reason this
  exists.
- **It renders on the server, so it commits to Eastern** and says so
  ("12:30 PM ET"). The app renders a kickoff in the reader's own zone
  because it knows it; one image shown to everyone can't.
- **It must never fail.** An unfurler that gets a 500 shows no image at all,
  so a missing logo degrades to a disc, a missing font to the default, and
  an unknown game id to a wordmark card. Satori's child-count rule is the
  live trap here — see the note at the top of `opengraph-image.tsx`.
- **The domain is `statside.co`**, set in `src/lib/site.ts`. It has to be
  absolute: the machine reading these tags is not the one that served them.
- **College football only.** These URLs resolve through the CFB provider, so
  an NFL, NBA or NHL event id 404s — the iOS app's other leagues can't point
  at this page yet.

Check a card without deploying: `npm run dev`, then open
`/game/<espnEventId>/opengraph-image-k9cnhd` (the suffix is Next's, and it
changes when the file does — read it off `npm run build`'s route list).

## Context

- Product and design decisions live in the repo root `CLAUDE.md` (the iOS app is the source of truth).
- The original web product spec is in [`PRD.md`](./PRD.md).
