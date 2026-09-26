import Link from "next/link";
import { AppearancePicker } from "./appearance-picker";

// The two documents the App Store requires a URL for, given a way to reach
// them from inside the product rather than only from a listing field.
//
// A footer is a new shape for this app — every other route is chrome plus
// cards, and FotMob's own web app has none. It earns its line anyway: a
// privacy policy nobody can find from the page they're on is a link in a
// form somewhere, not a policy, and the support page is the only route that
// tells a visitor how to reach a human.
//
// Quiet by construction: meta type, secondary ink, one hairline. It sits
// after the last card on every route, which on the Games slate is a long
// way down — exactly where a footer should be.
//
// **It also carries the Appearance picker** (iOS Settings, 2026-09-25). iOS
// puts that choice in a Settings sheet behind a gear on the Games masthead;
// the web has no Settings page, and one control is not worth building one
// for — a gear, a sheet and a heading to hold three segments. The footer is
// the closest analog: like the sheet it is on hand from anywhere without
// being in anyone's way, it is already where this app keeps the things you
// set once and forget, and it is where the web conventionally keeps a theme
// switch, so a visitor looking for one looks here first.
const LINKS = [
  { href: "/support", label: "Support" },
  { href: "/privacy", label: "Privacy" },
];

export function SiteFooter() {
  return (
    <footer className="mx-auto max-w-[var(--page-max)] px-4 pb-20 pt-8 sm:pb-6">
      <div className="border-t border-divider pt-4">
        <div className="flex flex-wrap items-center justify-between gap-x-4 gap-y-3">
          <nav aria-label="Site information" className="flex gap-4">
            {LINKS.map((link) => (
              <Link
                key={link.href}
                href={link.href}
                className="type-meta-medium text-text-secondary transition-colors hover:text-text-primary"
              >
                {link.label}
              </Link>
            ))}
          </nav>
          <AppearancePicker />
        </div>
        {/* Four leagues now, where the July page named only the NCAA. */}
        <p className="mt-3 max-w-[38rem] type-meta text-text-secondary">
          StatSide is an independent app and is not affiliated with or endorsed
          by the NCAA, the NFL, the NBA, the NHL, or any conference, team or
          school.
        </p>
      </div>
    </footer>
  );
}
