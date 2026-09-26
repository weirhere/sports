// The app's name in the nav bar.
//
// **Plain, and no glyph** (Andy, 2026-09-10: *"change the StatSide logo
// back to the original version. i'm not liking this 'stylized' version"*,
// then *"not with the football icon, just the wordmark"*). That is the
// original lockup's type without the 🏈 it used to lead with — so it
// supersedes W7's drawn-mark treatment (the condensed width axis, the
// Stat/Side weight split, −3% tracking) while keeping the one thing iOS
// 2026-09-09 got right: the glyph doesn't come back. A stock icon beside a
// stock system-font string reads as a placeholder logo.
//
// **21px heavy, no tracking** — iOS `Wordmark`'s masthead values (Andy's
// call at 21 when iOS followed this revert, 2026-09-10). The web shipped the
// revert first at 17 bold with `tracking-tight`, and the two surfaces drifted
// apart on the one element that is the same brand on both; the tight
// tracking was itself a remnant of the treatment being reverted.
//
// The real answer to a placeholder wordmark is a drawn one, which needs a
// licence and a designer. This is honest about being system type in the
// meantime rather than dressing it up as something else.

export function Wordmark({ className }: { className?: string }) {
  return (
    <span
      className={`whitespace-nowrap type-page-title ${className ?? ""}`}
    >
      StatSide
    </span>
  );
}
