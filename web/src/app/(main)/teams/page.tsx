import Link from "next/link";
import { FBS_CONFERENCES } from "@/config/conferences";
import { MOCK_TEAMS } from "@/lib/mock/teams";
import { TeamLogo } from "@/components/team-logo";

export const metadata = {
  title: "Teams | College Football Hub",
};

/**
 * The Teams tab: FBS conferences with their teams, from mock data.
 * A minimal browse shell for the 4-tab shape — the full Teams browse
 * (follow toggles, search field, directory data) lands in a later phase.
 */
export default function TeamsPage() {
  return (
    <div className="space-y-3">
      <h1 className="type-hero-title">Teams</h1>

      {FBS_CONFERENCES.map((conference) => {
        const teams = MOCK_TEAMS.filter(
          (t) => t.conferenceId === conference.id
        );
        if (teams.length === 0) return null;

        return (
          <section key={conference.id} className="card-surface">
            <Link
              href={`/conference/${conference.id}`}
              className="flex items-center justify-between bg-bg-header px-4 py-2.5 transition-colors hover:bg-accent/50"
            >
              <span className="type-section-header uppercase tracking-wide text-text-secondary">
                {conference.name}
              </span>
              <span className="type-meta text-text-secondary">
                {teams.length} teams
              </span>
            </Link>
            <div>
              {teams.map((team, i) => (
                <div key={team.id}>
                  {i > 0 && <div className="mx-4 border-t border-divider" />}
                  <Link
                    href={`/team/${team.id}`}
                    className="flex items-center gap-3 px-4 py-2.5 transition-colors hover:bg-accent/30"
                  >
                    <TeamLogo
                      espnId={team.espnId}
                      teamName={team.school}
                      size="sm"
                    />
                    <div className="min-w-0 flex-1">
                      <p className="type-team-name-em truncate">
                        {team.school}
                      </p>
                      <p className="type-meta text-text-secondary">
                        {team.name}
                      </p>
                    </div>
                  </Link>
                </div>
              ))}
            </div>
          </section>
        );
      })}
    </div>
  );
}
