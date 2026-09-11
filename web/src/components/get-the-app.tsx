// The iOS download CTA — the web app's only outbound pitch.
//
// StatSide the web app and StatSide the iPhone app are two implementations
// of one product, and until now the web half never said the other existed.
// That gap has a specific cost: the OpenGraph card (2026-09-09) means a
// shared game link unfurls beautifully in Slack and on X, and every one of
// those taps lands on a page with no way to the App Store — the hole the
// backlog named as "a way back to the App Store from the web page".
//
// Three shapes, because the placements ask different things:
//
//   - `GetTheAppPill` rides the nav bar at every width, a persistent,
//     one-line way out that costs no vertical space. It **inverts** — ink
//     ground, page-coloured text — the app's language for "this is the
//     action", the same pairing the Today button and the selected day chip
//     wear.
//   - `GetTheAppCard` leads the Scores follow rail: FotMob's own web app
//     puts its promo cards in exactly this slot, and the rail is the one
//     column on the page that isn't the slate — nothing is pushed down to
//     make room for it.
//   - The same card closes a game page's rail, the screen a shared link
//     lands on, where the visitor may never have heard of the app.
//
// Monochrome, like everything else that isn't a logo — the graphic draws
// the app in the app's own ramp, and spends exactly one dot of the live
// accent, because a slate with nothing live in it isn't the pitch.

import { APP_STORE_URL } from "@/lib/app-store";

const LABEL = "Get StatSide for iPhone on the App Store";

/**
 * A new tab, not this one: the visitor is mid-slate, and on a desktop
 * browser an App Store link is a full navigation away from the game they
 * were reading. On iOS it hands off to the App Store app and the tab it
 * opened closes itself.
 */
const LINK_PROPS = {
  href: APP_STORE_URL,
  target: "_blank",
  rel: "noreferrer",
  "aria-label": LABEL,
} as const;

/**
 * Apple's mark, inline so it inherits `currentColor` and inverts with the
 * button it sits in. Deliberately the logo alone and not the "Download on
 * the App Store" badge: that artwork is a licensed asset with its own
 * colour and clear-space rules, so it would be both the colour budget's
 * fourth exception and a binary to keep in sync. The apple in
 * `lucide-react` is a piece of fruit, not this.
 */
function AppleLogo({ className }: { className?: string }) {
  return (
    <svg
      viewBox="0 0 24 24"
      fill="currentColor"
      aria-hidden="true"
      className={className}
    >
      <path d="M16.365 1.43c0 1.14-.493 2.27-1.177 3.08-.744.9-1.99 1.57-2.987 1.57-.12 0-.23-.02-.3-.03-.01-.06-.04-.22-.04-.39 0-1.15.572-2.27 1.206-2.98.804-.94 2.142-1.64 3.248-1.68.03.13.05.28.05.43zm4.565 15.71c-.03.07-.463 1.58-1.518 3.12-.945 1.34-1.94 2.71-3.43 2.71-1.517 0-1.9-.88-3.63-.88-1.698 0-2.302.91-3.67.91-1.377 0-2.332-1.26-3.428-2.8-1.287-1.82-2.323-4.63-2.323-7.28 0-4.28 2.797-6.55 5.552-6.55 1.448 0 2.675.95 3.6.95.865 0 2.222-1.01 3.902-1.01.635 0 2.91.06 4.442 2.18-.127.07-2.573 1.5-2.573 4.5 0 3.45 3.043 4.69 3.076 4.71z" />
    </svg>
  );
}

export function GetTheAppPill() {
  return (
    <a
      {...LINK_PROPS}
      className="ml-auto inline-flex h-8 shrink-0 items-center gap-1.5 rounded-full bg-text-primary px-3 type-meta-em text-bg-primary transition-opacity hover:opacity-85"
    >
      {/* Nudged up a hair: the mark's optical centre sits below its box,
          which is the leaf. */}
      <AppleLogo className="-mt-px h-3.5 w-3.5" />
      Get the app
    </a>
  );
}

export function GetTheAppCard() {
  return (
    <section className="card-surface flex flex-col px-4 pt-4">
      {/* A headline, not the wordmark. The mark is already in the nav bar a
          few pixels above this card, and repeating it made the card read as
          a second masthead rather than as an offer — a card's first line
          should say what it wants, and this one wants a platform named. */}
      <h2 className="type-section-header-prominent text-text-primary">
        StatSide for iPhone
      </h2>
      <p className="mt-1.5 type-meta text-text-secondary">
        Every score on your home screen — with a widget and kickoff reminders.
      </p>
      <a
        {...LINK_PROPS}
        className="mt-3 inline-flex items-center justify-center gap-2 rounded-full bg-text-primary px-4 py-2 type-chip-em text-bg-primary transition-opacity hover:opacity-85"
      >
        <AppleLogo className="-mt-px h-4 w-4" />
        Download on the App Store
      </a>
      {/* The phone runs off the bottom edge rather than sitting inside a
          margin: a device shot that ends before the card does reads as a
          picture *of* a phone, where one that leaves the frame reads as the
          app continuing past it. */}
      <AppScreenGraphic />
    </section>
  );
}

/**
 * The app, drawn rather than photographed — a screenshot would be a PNG to
 * re-shoot every time the slate's type or spacing moved, and at this size
 * it would be an unreadable grey smear anyway. This is the same slate the
 * page beside it renders, abstracted to its shapes: a day strip with today
 * filled, then three game cards, one of them live.
 *
 * Every value is a theme token, so it re-paints in dark mode with the rest
 * of the page and never needs a second asset.
 */
function AppScreenGraphic() {
  const row = (y: number, live: boolean) => (
    <g key={y}>
      <rect
        x="18"
        y={y}
        width="124"
        height="30"
        rx="5"
        fill="var(--bg-card)"
      />
      {/* Two team marks and their names. */}
      <circle cx="28" cy={y + 10} r="4" fill="var(--divider)" />
      <circle cx="28" cy={y + 21} r="4" fill="var(--divider)" />
      <rect
        x="36"
        y={y + 7}
        width="34"
        height="5"
        rx="2.5"
        fill="var(--text-secondary)"
      />
      <rect
        x="36"
        y={y + 18}
        width="27"
        height="5"
        rx="2.5"
        fill="var(--text-secondary)"
      />
      {/* Scores, and the status column the hairline divides off. */}
      <rect
        x="92"
        y={y + 7}
        width="9"
        height="5"
        rx="2.5"
        fill="var(--text-primary)"
      />
      <rect
        x="92"
        y={y + 18}
        width="9"
        height="5"
        rx="2.5"
        fill="var(--text-primary)"
      />
      <rect x="108" y={y + 6} width="1" height="18" fill="var(--divider)" />
      {live && <circle cx="117" cy={y + 12} r="2.5" fill="var(--rank-up)" />}
      <rect
        x={live ? 123 : 114}
        y={y + 10}
        width={live ? 14 : 23}
        height="4"
        rx="2"
        fill="var(--text-secondary)"
      />
    </g>
  );

  return (
    <svg
      viewBox="0 0 160 132"
      aria-hidden="true"
      className="mx-auto mt-4 block w-full max-w-[220px]"
    >
      {/* The handset: bottom-left past the viewBox, so it is cut by the
          card's own edge rather than by a line of its own. */}
      <rect
        x="8"
        y="6"
        width="144"
        height="160"
        rx="18"
        fill="var(--bg-recessed)"
        stroke="var(--divider)"
      />
      <rect
        x="68"
        y="14"
        width="24"
        height="4"
        rx="2"
        fill="var(--divider)"
      />
      {/* The wordmark's weight split, at the one size where it is a shape
          and not a word. */}
      <rect
        x="18"
        y="26"
        width="22"
        height="7"
        rx="3"
        fill="var(--text-primary)"
      />
      <rect
        x="41"
        y="26"
        width="20"
        height="7"
        rx="3"
        fill="var(--text-secondary)"
      />
      {/* The day strip — today filled, the way the selected chip inverts. */}
      <rect
        x="18"
        y="42"
        width="26"
        height="10"
        rx="5"
        fill="var(--bg-elevated)"
      />
      <rect
        x="48"
        y="42"
        width="30"
        height="10"
        rx="5"
        fill="var(--text-primary)"
      />
      <rect
        x="82"
        y="42"
        width="26"
        height="10"
        rx="5"
        fill="var(--bg-elevated)"
      />
      <rect
        x="112"
        y="42"
        width="26"
        height="10"
        rx="5"
        fill="var(--bg-elevated)"
      />
      {[60, 94, 128].map((y, i) => row(y, i === 0))}
    </svg>
  );
}
