/**
 * Per-route content width.
 *
 * The pages are single columns of cards, so an unbounded desktop page
 * stretches a game row until its score sits a hand's width from the team
 * name it belongs to. Every route caps itself, and the chrome that has to
 * line up with the content — the nav bar, the day strip — reads the cap
 * off the `--page-max` custom property `AppShell` sets on the shell root
 * rather than repeating a number.
 *
 * Scores is the narrow one (a 280px follow rail beside a ~660px slate);
 * the game page is a little wider, because its context rail sits beside a
 * main column that has to hold a box score.
 */
export function pageMaxWidth(pathname: string): string {
  if (pathname === "/") return "960px";
  if (pathname.startsWith("/game/")) return "1040px";
  return "80rem"; /* the max-w-7xl every other page has always had */
}
