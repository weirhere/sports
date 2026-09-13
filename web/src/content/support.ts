// The support page — the other half of what the App Store's two URL fields
// point at, and the one page in the app written to be read rather than
// scanned.
//
// It is markdown for the same reason the policy is: one renderer, and the
// text stays editable by whoever has to answer these questions rather than
// living inside JSX. Unlike the policy it mirrors nothing — there is no
// iOS-side document for it, and the FAQ is about both halves of the
// product, so the app-only answers say so.
//
// Rewritten from `docs/index.html`, the July page this replaces, which sold
// StatSide as a college football app with a season picker that has since
// left the Scores screen. Every answer below names something the app
// actually does today.

export const SUPPORT_MARKDOWN = `# Support

Found a bug, missing a feature, or seeing a score that's wrong? Email iamandyweir@gmail.com and say which game and what screen you were on, plus your iOS version if it's the app. You'll hear back from a human — the only one who works here.

## Which leagues does StatSide cover?

College football, the NFL, the NBA and the NHL. The season runs July through June, so there's no offseason: by the time football ends, basketball and hockey are halfway through.

## Why is this day empty?

Games are grouped by day, and not every day has any. Walk a day either side with the strip along the top, or tap the calendar beside it to jump to a date. On launch the app skips forward to the next day that has games rather than opening on an empty one, so an empty day is one you navigated to.

## Why does a game show up in more than one place?

On purpose. Following, the Top 25 and each conference section are each **complete** — a ranked team you follow appears in all three. Removing the repeats would mean one of those sections was quietly leaving games out.

## How do I follow a team?

Teams tab, then **Add teams**, and search or pick from the shortlist. Following a team pulls its games to the top of every day's slate, into the home-screen widget, and behind an optional reminder 30 minutes before kickoff.

Following a **table** — a conference, a division, the Top 25 — does something different: it moves that whole table higher up the slate instead of pouring its games into Following. Drag the cards on the Leagues tab to set the order they appear in.

## Why aren't kickoff reminders arriving?

The bell on a team page is one app-wide switch, not one per team, so check it's on — and check StatSide's notifications are allowed in iOS Settings. Reminders fire 30 minutes before kickoff for teams you follow, and a game whose kickoff time hasn't been announced yet doesn't get one, because there's nothing to be 30 minutes early for.

## Where do the scores come from?

Publicly available sports data, refreshed automatically while games are live. StatSide adds no data of its own, which is also why a score can lag a television broadcast by a few seconds.

## Is there an Android app?

No, and there's no plan for one. The website at statside.co shows the same scores in any browser; the home-screen widget and kickoff reminders are iPhone-only.

## What does StatSide know about me?

Nothing that identifies you. No accounts, no ads, no tracking — the teams you follow live on your device. The full [privacy policy](/privacy) is the long version.
`;
