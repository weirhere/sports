import type { Metadata } from "next";
import { Prose } from "@/components/prose";
import { SUPPORT_MARKDOWN } from "@/content/support";

export const metadata: Metadata = {
  title: "Support | StatSide",
  description:
    "How to reach a human about StatSide, plus answers on leagues, following teams, kickoff reminders and where the scores come from.",
};

/**
 * The support page — App Store Connect's Support URL, and the only place in
 * the product that answers a question in a sentence.
 *
 * Same story as the policy beside it: the field pointed at a Pages site in
 * a separate repo that stopped serving, so both URLs in the live listing
 * were 404s. Static, for the same reason.
 */
export default function SupportPage() {
  return (
    <div className="card-surface p-5 sm:p-7">
      <Prose markdown={SUPPORT_MARKDOWN} />
    </div>
  );
}
