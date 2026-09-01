# StatSide web

The web companion to StatSide, the iOS college football scores app. A Next.js app being brought to feature parity with the iOS app — web mirrors iOS exactly, so anything the iOS app doesn't have is being removed rather than maintained.

Currently runs on mock data; the ESPN data layer under `src/lib/espn/` is wired up but disabled by default (`USE_ESPN=true` in `.env.local` enables it).

## Develop

```sh
npm install
npm run dev
```

Lint, typecheck, and build with `npm run lint`, `npm run typecheck`, and `npm run build`.

## Context

- Product and design decisions live in the repo root `CLAUDE.md` (the iOS app is the source of truth).
- The original web product spec is in [`PRD.md`](./PRD.md).
