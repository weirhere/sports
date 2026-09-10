import { TeamsList } from "./teams-list";

export const metadata = {
  title: "Teams | StatSide",
};

/**
 * The Teams tab: the teams you follow, one card each, with an Add teams sheet
 * over the whole directory. Browsing by conference is the Leagues hub's job
 * and finding one team by name is search's; this tab is the handful that are
 * yours (iOS, 2026-09-05). All state is client-side, so the page is a shell.
 */
export default function TeamsPage() {
  return <TeamsList />;
}
