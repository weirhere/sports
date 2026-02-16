import Link from "next/link";
import { FBS_CONFERENCES, FCS_CONFERENCES } from "@/config/conferences";
import { MOCK_TOP_25 } from "@/lib/mock/rankings";
import { TeamLogo } from "@/components/team-logo";
import { Separator } from "@/components/ui/separator";
import { ScrollArea, ScrollBar } from "@/components/ui/scroll-area";

export const metadata = {
  title: "Conferences | College Football Hub",
};

function RankedTeamCard({
  rank,
  team,
  record,
}: {
  rank: number;
  team: { espnId: number; school: string; id: string };
  record: string;
}) {
  return (
    <Link
      href={`/team/${team.id}`}
      className="flex shrink-0 items-center gap-3 rounded-lg border bg-card px-4 py-3 transition-colors hover:bg-accent/50"
    >
      <span className="font-score text-lg font-bold text-muted-foreground">
        {rank}
      </span>
      <TeamLogo espnId={team.espnId} teamName={team.school} size="md" />
      <div>
        <p className="text-sm font-semibold">{team.school}</p>
        <p className="text-xs text-muted-foreground">{record}</p>
      </div>
    </Link>
  );
}

function ConferenceCard({
  id,
  name,
  shortName,
}: {
  id: string;
  name: string;
  shortName: string;
}) {
  return (
    <Link
      href={`/conferences/${id}`}
      className="flex items-center gap-3 rounded-lg border bg-card p-4 transition-colors hover:bg-accent/50"
    >
      <div>
        <p className="text-sm font-semibold">{shortName}</p>
        <p className="text-xs text-muted-foreground">{name}</p>
      </div>
    </Link>
  );
}

export default function ConferencesPage() {
  return (
    <div className="space-y-8">
      {/* AP Top 25 */}
      <section>
        <h2 className="mb-4 text-xl font-bold">AP Top 25</h2>
        <ScrollArea className="w-full">
          <div className="flex gap-3 pb-3">
            {MOCK_TOP_25.map((rt) => (
              <RankedTeamCard
                key={rt.rank}
                rank={rt.rank}
                team={rt.team}
                record={rt.record}
              />
            ))}
          </div>
          <ScrollBar orientation="horizontal" />
        </ScrollArea>
      </section>

      {/* FBS Conferences */}
      <section>
        <h2 className="mb-4 text-xl font-bold">FBS Conferences</h2>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {FBS_CONFERENCES.map((conf) => (
            <ConferenceCard
              key={conf.id}
              id={conf.id}
              name={conf.name}
              shortName={conf.shortName}
            />
          ))}
        </div>
      </section>

      <Separator />

      {/* FCS Conferences */}
      <section>
        <h2 className="mb-4 text-xl font-bold text-muted-foreground">
          FCS Conferences
        </h2>
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {FCS_CONFERENCES.map((conf) => (
            <ConferenceCard
              key={conf.id}
              id={conf.id}
              name={conf.name}
              shortName={conf.shortName}
            />
          ))}
        </div>
      </section>
    </div>
  );
}
