// Where the iOS app lives, for the web app's download CTAs.
//
// **One URL, matching the app's own.** `ShareSignOff.appStoreLink`
// (StatSideShared/Models/Game+ShareText.swift) has shipped the locale-less
// form in every share since 1.0, and this is the same product link. The
// `/us/` variant Apple's web UI hands you pins the US storefront; the bare
// `/app/id{n}` form lets Apple send each visitor to their own, which is the
// right behavior for a link that also rides shared messages.
//
// **No campaign tokens.** Apple's `pt`/`ct` parameters are analytics, and
// the app takes none (CLAUDE.md: no analytics in v1). A tracking token here
// would be the first.

/** The App Store numeric id — the Smart App Banner's `app-id`. */
export const APP_STORE_APP_ID = "6793266645";

/** The product page, storefront-agnostic. */
export const APP_STORE_URL = `https://apps.apple.com/app/id${APP_STORE_APP_ID}`;
