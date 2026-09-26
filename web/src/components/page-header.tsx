// A root tab's own masthead: the page's name at the leading edge, its
// controls at the trailing one — the web twin of iOS `PageHeader`
// (sports/Theme/PageHeader.swift, Andy, 2026-09-21).
//
// Every root tab draws its title through this one component — Games,
// Leagues, Teams and Search — so the name sits in the same place, at the
// same size, on every tab. Until now each page carried a screen-reader-only
// `<h1>` and nothing visible, on the reasoning that the tab bar already
// names the page; iOS settled that a tab names itself, left-aligned, in one
// row, and the web follows it.
//
// **The row floor is the rule; the value is the web's own.** iOS states 52pt
// because that is its Games capsule's height (a 44pt tap target plus the
// capsule's padding). What the floor is *for* is that every tab's row comes
// out the same height whatever its trailing control is — or whether it has
// one — so the content below starts at the same place and a tab change
// doesn't jog the page. Here that is 44px, the web's own tap-target minimum
// and the height of the one trailing control that exists today (Teams' add
// button). A trailing control taller than that would raise every tab's row,
// so it shouldn't be one. The `pb-2` below the row is the header's own, and
// each tab renders it outside its list's `gap`, so the header-to-content
// distance is this component's to set and can't drift per page.

import type { ReactNode } from "react";

interface PageHeaderProps {
  title: string;
  /** Right-aligned controls on the title's own line. */
  trailing?: ReactNode;
}

export function PageHeader({ title, trailing }: PageHeaderProps) {
  return (
    // The floor is on the row, the padding outside it: `min-h` counts
    // padding under border-box, so the two on one box would shrink the row.
    <header className="px-1 pb-2">
      <div className="flex min-h-11 items-center gap-2">
        {/* One line, always: a masthead that wraps is two rows tall on one
            tab and one on the next, which is the jog this exists to stop. */}
        <h1 className="min-w-0 truncate type-page-title text-text-primary">
          {title}
        </h1>
        {trailing !== undefined && (
          <div className="ml-auto flex shrink-0 items-center gap-2">
            {trailing}
          </div>
        )}
      </div>
    </header>
  );
}
