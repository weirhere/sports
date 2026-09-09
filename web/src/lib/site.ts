// Where this app lives, for the absolute URLs that only make sense off-site:
// `metadataBase` and the OpenGraph image a Slack or X unfurl fetches.
//
// A link preview is built by the *recipient's* server, not the sender's
// browser, so a relative URL is useless to it — every og: URL has to be
// absolute and publicly reachable, which is the whole reason this constant
// exists rather than the code just saying "/".

/** The production domain. Preview deploys override it via VERCEL_URL. */
export const PRODUCTION_ORIGIN = "https://statside.co";

/**
 * The origin to build absolute metadata URLs against:
 * - `NEXT_PUBLIC_SITE_URL` when set (local overrides, custom deploys)
 * - the production domain on a production deploy
 * - a preview's own deployment URL, so a preview's unfurl shows the preview
 *
 * The production check comes BEFORE `VERCEL_URL` deliberately: on a
 * production deploy that variable holds the deployment's own
 * `*.vercel.app` hostname, not the custom domain, so trusting it would
 * publish every canonical and every preview image under a URL nobody
 * recognises.
 */
export function siteOrigin(): string {
  const explicit = process.env.NEXT_PUBLIC_SITE_URL;
  if (explicit) return explicit.replace(/\/$/, "");
  if (process.env.VERCEL_ENV === "production") return PRODUCTION_ORIGIN;
  const vercel = process.env.VERCEL_URL;
  if (vercel) return `https://${vercel}`;
  return PRODUCTION_ORIGIN;
}

export function siteUrl(): URL {
  return new URL(siteOrigin());
}
