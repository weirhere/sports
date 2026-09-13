import Link from "next/link";

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
const LINKS = [
  { href: "/support", label: "Support" },
  { href: "/privacy", label: "Privacy" },
];

export function SiteFooter() {
  return (
    <footer className="mx-auto max-w-[var(--page-max)] px-4 pb-20 pt-8 sm:pb-6">
      <div className="border-t border-divider pt-4">
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
