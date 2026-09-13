import type { Metadata } from "next";
import { Prose } from "@/components/prose";
import { PRIVACY_MARKDOWN } from "@/content/privacy";

export const metadata: Metadata = {
  title: "Privacy Policy | StatSide",
  description:
    "StatSide collects no personal data: no accounts, no advertising, no tracking. The teams you follow stay on your device.",
};

/**
 * The privacy policy, at the URL App Store Connect's Privacy Policy field
 * points at.
 *
 * That field used to hold `weirhere.github.io/statside-site/privacy.html`,
 * served by Pages from a separate repo because this one was private. This
 * one has been public since 2026-09-03, the separate repo went private, and
 * Pages stopped serving — so the link in the live App Store listing was a
 * 404, which is the kind of thing a required field cannot be. It lives on
 * the app's own domain now, one deploy, no copy step between two repos.
 *
 * Static by construction: the text is an imported constant, so this page
 * prerenders and never touches the network. A privacy policy that could
 * fail to load is worse than a plain one.
 */
export default function PrivacyPage() {
  return (
    <div className="card-surface p-5 sm:p-7">
      <Prose markdown={PRIVACY_MARKDOWN} />
    </div>
  );
}
