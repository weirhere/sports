"use client";

// The Top 25 on the entity-page template — iOS `PollScreen`. Hero mark and
// title, a Standings / Games / Postseason tab set, the season chip on the
// toolbar row beside the follow pill, and each pane's own control in the
// strip beneath the tabs.
//
// The poll picker is a menu chip rather than a segmented control or a second
// page: AP, Coaches and CFP are the same 25 teams read by different voters,
// so they filter one table (iOS, 2026-09-05). The chosen poll scopes the
// Games tab too — its 25 teams are the slate's members, by the app's
// "any ranked participant" rule.

import { useEffect, useMemo, useState } from "react";
import Link from "next/link";
import Image from "next/image";
import { useRouter } from "next/navigation";
import {
  leagueLogoUrl,
  seasonYear,
  seasonYears,
  type League,
} from "@/lib/leagues";
import { pollLabel } from "@/lib/polls";
import type { Game, Poll, RankedTeam, Team } from "@/lib/types";
import { HeroHeader } from "@/components/hero-header";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import { SeasonMenuChip } from "@/components/season-menu-chip";
import { FollowPill } from "@/components/follow-pill";
import { MenuChip } from "@/components/menu-chip";
import { TeamLogo } from "@/components/team-logo";
import { ConferenceGamesList } from "@/components/conference-games-list";
import {
  SlateControlRow,
  toggledGrouping,
} from "@/components/slate-control-row";
import { PostseasonSection } from "@/components/postseason-section";
import {
  defaultRound,
  postseasonExhibition,
  postseasonRounds,
} from "@/lib/postseason";
import { gamesForTeam, type SlateGrouping } from "@/lib/conference-slate";
import { teamPath } from "@/lib/routes";
import { cn } from "@/lib/utils";

/** Mirrors the iOS `UIStateStore.pollChoice` preference. */
const POLL_CHOICE_KEY = "statside.ui.pollChoice";

export function PollView({
  league,
  polls,
  games,
  displayYear,
}: {
  league: League;
  /** The season's displayable polls; null = the fetch failed. */
  polls: Poll[] | null;
  /** The division's whole season, the ranked slate's source; null = failed. */
  games: Game[] | null;
  displayYear: number;
}) {
  const router = useRouter();
  const [tab, setTab] = useState("standings");
  const [pollChoice, setPollChoice] = useState<string>("ap");
  const [grouping, setGrouping] = useState<SlateGrouping>("week");
  const [teamChoice, setTeamChoice] = useState<string | undefined>();
  const [roundChoice, setRoundChoice] = useState<string | undefined>();

  useEffect(() => {
    // Read post-hydration on purpose: a lazy initializer would diverge from
    // the server-rendered markup.
    try {
      const stored = localStorage.getItem(POLL_CHOICE_KEY);
      // eslint-disable-next-line react-hooks/set-state-in-effect
      if (stored) setPollChoice(stored);
    } catch {
      // A browser that refuses storage still gets the default poll.
    }
  }, []);

  const seasonPolls = polls ?? [];
  const selectedPoll =
    seasonPolls.find((poll) => poll.type === pollChoice) ?? seasonPolls[0];

  const selectPoll = (poll: Poll) => {
    const type = poll.type ?? "ap";
    setPollChoice(type);
    try {
      localStorage.setItem(POLL_CHOICE_KEY, type);
    } catch {
      // Ignore storage errors — the choice still holds for this visit.
    }
  };

  const selectYear = (year: number) => {
    const query = year === seasonYear(league) ? "" : `?year=${year}`;
    router.push(`/rankings/poll${query}`);
  };

  // The season's slate narrowed to the poll's own teams — the app's "any
  // ranked participant" rule (2026-07-21), which is what a Top 25 slate has
  // always meant here.
  const rankedGames = useMemo(() => {
    if (!games || !selectedPoll) return undefined;
    const ranked = new Set(selectedPoll.ranks.map((entry) => entry.team.id));
    return games.filter(
      (game) =>
        ranked.has(game.homeTeam.team.id) || ranked.has(game.awayTeam.team.id)
    );
  }, [games, selectedPoll]);

  // The teams the chip can offer: this poll's 25, in rank order, so the menu
  // reads like the table above it.
  const filterableTeams: Team[] = useMemo(
    () => selectedPoll?.ranks.map((entry) => entry.team) ?? [],
    [selectedPoll]
  );
  // A pick survives a season or poll switch only where that table still
  // ranks the team — otherwise the pane would filter to a team this poll
  // never had.
  const activeTeam = filterableTeams.find((team) => team.id === teamChoice);
  const filteredGames = useMemo(
    () => gamesForTeam(rankedGames ?? [], activeTeam?.id),
    [rankedGames, activeTeam?.id]
  );

  // The postseason is the *division's*, not the poll's: a bracket narrowed
  // to ranked teams would be a bracket with games missing.
  const rounds = useMemo(
    () => postseasonRounds(games ?? [], league),
    [games, league]
  );
  const exhibition = useMemo(
    () => postseasonExhibition(games ?? [], league),
    [games, league]
  );
  const activeRound =
    roundChoice && rounds.some((round) => round.name === roundChoice)
      ? roundChoice
      : defaultRound(rounds);

  const tabs: HeroTab[] = [
    { id: "standings", label: "Standings" },
    { id: "games", label: "Games" },
    // A tab that would open on "no games" is worse than no tab.
    ...(rounds.length > 0
      ? [{ id: "postseason", label: "Postseason" }]
      : []),
  ];
  const activeTab = tabs.some((entry) => entry.id === tab) ? tab : "standings";

  const logoUrl = leagueLogoUrl(league);

  return (
    <div>
      <HeroHeader
        logo={
          logoUrl ? (
            // The league's own mark, not a trophy: "Top 25" never said whose,
            // which is fine while one league polls and wrong the moment a
            // second one does (iOS, 2026-09-06).
            <span className="inline-flex items-center justify-center rounded-full bg-logo-backing p-1.5">
              <Image
                src={logoUrl}
                alt=""
                width={44}
                height={44}
                className="h-11 w-11 object-contain"
                unoptimized
              />
            </span>
          ) : null
        }
        title="Top 25"
        subtitle={
          // ESPN's own line for the poll ("2026 AP Poll: Preseason") — which
          // poll, and how far into the season it is. On a past season it
          // names the year, so the page can't be mistaken for this week's.
          <span className="type-chip-em text-text-secondary">
            {selectedPoll?.headline ??
              (displayYear === seasonYear(league) ? "" : String(displayYear))}
          </span>
        }
        trailing={
          <>
            <SeasonMenuChip
              value={displayYear}
              years={seasonYears(league)}
              onSelect={selectYear}
            />
            {/* The Top 25 is followable — a third follow set, keyed by
                league so a league that grows a poll needs no migration. */}
            <FollowPill league={league} kind="poll" name="Top 25" />
          </>
        }
        tabs={<HeroTabBar tabs={tabs} selected={activeTab} onSelect={setTab} />}
        controls={
          activeTab === "standings" ? (
            seasonPolls.length > 1 ? (
              <MenuChip
                label={pollLabel(selectedPoll ?? seasonPolls[0])}
                ariaLabel={`Poll, ${pollLabel(selectedPoll ?? seasonPolls[0])}`}
                options={seasonPolls.map((poll) => ({
                  id: poll.id,
                  label: pollLabel(poll),
                  onSelect: () => selectPoll(poll),
                }))}
              />
            ) : undefined
          ) : activeTab === "games" ? (
            <SlateControlRow
              grouping={grouping}
              onToggle={(value) =>
                setGrouping((current) => toggledGrouping(current, value))
              }
              teams={filterableTeams}
              teamSelection={activeTeam?.id}
              onSelectTeam={setTeamChoice}
            />
          ) : undefined
        }
      />

      <div
        role="tabpanel"
        id={`panel-${activeTab}`}
        aria-labelledby={`tab-${activeTab}`}
        className="flex flex-col gap-2 py-2"
      >
        {activeTab === "standings" &&
          (polls === null ? (
            <RetryRow message="Couldn't load the poll." />
          ) : selectedPoll && selectedPoll.ranks.length > 0 ? (
            <PollTable poll={selectedPoll} />
          ) : (
            // A season ESPN has no poll for — the preseason before the first
            // vote drops, or a year the core API comes back empty on.
            <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
              No poll for this season.
            </section>
          ))}

        {activeTab === "games" &&
          (games === null ? (
            <RetryRow message="Couldn't load the schedule." />
          ) : filteredGames.length > 0 ? (
            <ConferenceGamesList games={filteredGames} grouping={grouping} />
          ) : activeTeam && (rankedGames?.length ?? 0) > 0 ? (
            <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
              <p className="type-team-name text-text-secondary">
                No {displayYear} games for {activeTeam.school}
              </p>
              <button
                type="button"
                onClick={() => setTeamChoice(undefined)}
                className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
              >
                Show all games
              </button>
            </section>
          ) : (
            <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
              Schedule TBA
            </section>
          ))}

        {activeTab === "postseason" && (
          <PostseasonSection
            rounds={rounds}
            exhibition={exhibition}
            selection={activeRound}
            onSelectRound={setRoundChoice}
          />
        )}
      </div>
    </div>
  );
}

function RetryRow({ message }: { message: string }) {
  const router = useRouter();
  return (
    <section className="card-surface flex flex-col items-center gap-3 px-4 py-8">
      <p className="type-team-name text-text-secondary">{message}</p>
      <button
        type="button"
        onClick={() => router.refresh()}
        className="rounded-full bg-bg-elevated px-4 py-1.5 type-chip-em text-text-primary transition-colors hover:bg-divider"
      >
        Retry
      </button>
    </section>
  );
}

/**
 * The poll in the standings tables' own column language — `#` / TEAM / OVR,
 * the same place gutter and the same 10pt rows, plus a MOV column, which is
 * the one thing a poll has that a standings table doesn't (iOS, 2026-09-05).
 */
function PollTable({ poll }: { poll: Poll }) {
  return (
    <section className="card-surface pb-1">
      {/* Visual-only captions — rows speak themselves as sentences. */}
      <div
        aria-hidden="true"
        className="flex items-center gap-3 px-4 pb-2 pt-3 type-row-meta-medium text-text-secondary"
      >
        <span className="w-4 shrink-0 text-right">#</span>
        <span className="w-5 shrink-0" />
        <span className="min-w-0 flex-1">TEAM</span>
        <span className="w-11 shrink-0 text-right">OVR</span>
        <span className="w-10 shrink-0 text-right">MOV</span>
      </div>
      {/* Keyed by team, not rank — polls can tie two teams at one rank (the
          2026 Coaches preseason had two No. 14s). */}
      {poll.ranks.map((ranked, index) => (
        <div key={ranked.team.id}>
          {index > 0 && <div className="ml-4 border-t border-divider" />}
          <RankRow ranked={ranked} />
        </div>
      ))}
    </section>
  );
}

/**
 * One ranked team. Movement is the one place besides live state that spends
 * colour — green up, red down — with arrows, so colour is never the only
 * signal. One link, one spoken sentence: "4. Georgia, 11 and 1, up 2".
 */
function RankRow({ ranked }: { ranked: RankedTeam }) {
  // ESPN sends previous 0 (or nothing) for a team unranked last week.
  const isNew = ranked.previousRank == null || ranked.previousRank === 0;
  const delta = isNew ? 0 : ranked.previousRank! - ranked.rank;

  return (
    <Link
      href={teamPath(ranked.team)}
      aria-label={rankSentence(ranked, isNew, delta)}
      className="flex items-center gap-3 py-2.5 pl-4 pr-4 transition-colors hover:bg-bg-header"
    >
      <span className="w-4 shrink-0 text-right tnum type-meta-em text-text-secondary">
        {ranked.rank}
      </span>
      <TeamLogo
        team={ranked.team}
        teamName={ranked.team.school}
        size="sm"
        className="shrink-0"
      />
      <span className="min-w-0 flex-1 truncate type-team-name text-text-primary">
        {ranked.team.school}
      </span>
      {ranked.firstPlaceVotes != null && ranked.firstPlaceVotes > 0 && (
        <span className="shrink-0 type-row-meta text-text-secondary">
          ({ranked.firstPlaceVotes})
        </span>
      )}
      <span className="w-11 shrink-0 text-right tnum type-team-name text-text-primary">
        {ranked.record || "—"}
      </span>
      <span className="w-10 shrink-0 text-right">
        {isNew ? (
          <span className="type-row-meta-medium text-text-secondary">NEW</span>
        ) : delta > 0 ? (
          <span className={cn("type-row-meta-medium text-rank-up")}>
            ▲ {delta}
          </span>
        ) : delta < 0 ? (
          <span className="type-row-meta-medium text-rank-down">▼ {-delta}</span>
        ) : (
          <span className="type-row-meta text-text-secondary">–</span>
        )}
      </span>
    </Link>
  );
}

function rankSentence(
  ranked: RankedTeam,
  isNew: boolean,
  delta: number
): string {
  const parts = [`${ranked.rank}. ${ranked.team.school}`];
  if (ranked.firstPlaceVotes != null && ranked.firstPlaceVotes > 0) {
    parts.push(`${ranked.firstPlaceVotes} first-place votes`);
  }
  if (ranked.record) parts.push(ranked.record.replaceAll("-", " and "));
  if (isNew) parts.push("newly ranked");
  else if (delta > 0) parts.push(`up ${delta}`);
  else if (delta < 0) parts.push(`down ${-delta}`);
  else parts.push("no change");
  return parts.join(", ");
}
