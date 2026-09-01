import { TeamsBrowse } from "./teams-browse";

export const metadata = {
  title: "Teams | College Football Hub",
};

/**
 * The Teams tab: browse and search the FBS by conference, fed by the live
 * team directory (/api/teams). All state is client-side — follows, section
 * collapse, and the inline filter — so the page itself is just the shell.
 */
export default function TeamsPage() {
  return <TeamsBrowse />;
}
