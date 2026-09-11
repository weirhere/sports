/**
 * The content width — **one number for every route** (Andy, 2026-09-10:
 * *"the max width on the scores/games page should be the same max width on
 * all the other pages so there is no content shift"*).
 *
 * The pages are single columns of cards, so an unbounded desktop page
 * stretches a game row until its score sits a hand's width from the team
 * name it belongs to (#112). That is still true — the cap didn't go away,
 * it stopped being three different caps. Games was 960, a game page 1040
 * and everything else 80rem, so the nav bar, the wordmark and the first
 * card all jumped horizontally on every tab change: the bar is `mx-auto`
 * against this value, so a page 320px wider moves its contents 160px left.
 *
 * **1040px, the game page's own**, because it is the one number that costs
 * nothing to adopt. It is already the widest two-column layout in the app
 * and the only one sized around a real constraint — a box score beside a
 * 320px context rail. Games gains ~80px of slate, which the row spends on
 * the team-name column (the status column is fixed), and the card lists on
 * Leagues, Teams and Search lose 240px they were only using to stretch a
 * standings row.
 *
 * The chrome that has to line up with the content reads it off the
 * `--page-max` custom property `AppShell` sets on the shell root, rather
 * than repeating the number.
 */
export const PAGE_MAX = "1040px";
