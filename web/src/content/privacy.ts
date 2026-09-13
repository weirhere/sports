// The published privacy policy — a **mirror of `PRIVACY.md` at the repo
// root**, which is the source of truth. `privacy.test.ts` asserts the two
// are byte-identical, so editing one without the other fails Web CI.
//
// A copy, rather than a build-time read of the file itself, because
// Vercel builds this app with `web/` as its root directory: a
// `readFileSync` reaching above it would work locally and could fail in
// production, which is the one failure mode a privacy policy must not
// have. The copy is a copy CI cannot let drift, which is the same
// mechanism the parity ledger runs on.
//
// To change the policy: edit `PRIVACY.md`, then paste it between the
// backticks below. The test tells you if you forgot.

export const PRIVACY_MARKDOWN = `# StatSide Privacy Policy

*Effective date: September 13, 2026*

StatSide is a sports scores app for iPhone — college football, the NFL, the NBA and the NHL — with a companion website at statside.co. It is built to show you scores fast, and that's all it does.

## What the app collects

**Nothing.** StatSide has no accounts, no analytics, no advertising, and no tracking.

StatSide runs one small service of its own, and it is worth being precise about what it is. To keep a live game's card up to date on your Lock Screen, the app subscribes to a broadcast channel **for that game** — not for you. One update is sent to everyone watching the same game at once. The service stores which channel a game is on and nothing else: no device identifiers, no tokens, no account, nothing that says a particular person is watching a particular game. It has no way to tell you apart from anyone else using the app.

- The teams you follow and your display preferences are stored **only on your device** (and in your device backups, which you control). They are never transmitted to us or anyone else.
- StatSide contains no third-party SDKs of any kind.

## What the website collects

statside.co counts page views, through Vercel Web Analytics. It sets no cookies, builds no profile of you, and follows nobody across other sites: what it reports back is how many people opened a page, never who. There are no accounts and no advertising here either.

- The teams you follow on the website and your display preferences are stored **in your browser**, in local storage. They never leave it, and clearing your site data deletes them.

## Network requests

To display scores, rankings, and team information, StatSide requests publicly available sports data directly from its data provider over HTTPS. These requests work like a web browser visiting a page: the provider receives your IP address as part of ordinary internet routing, but StatSide sends no identifiers, no account information, and nothing about which teams you follow.

## Your data rights

Nothing StatSide collects identifies you, so there is nothing for us to access, correct, delete, or sell. Deleting the app removes everything it ever stored, and clearing your browser's site data does the same for the website.

## Children

StatSide collects no personal data from anyone, including children.

## Changes

If a future version of StatSide ever changes any of the above, this policy will be updated before that version ships, and the change will be called out in the App Store release notes.

## Contact

Questions: iamandyweir@gmail.com
`;
