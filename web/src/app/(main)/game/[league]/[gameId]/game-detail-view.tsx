"use client";

// The game page (iOS GameDetailScreen): header on the card surface, then a
// tab row and the cards in the iOS order — line score, scoring, team stats,
// leaders. Live games poll every 30s through useLiveGame; a pre-game summary
// never demotes a live snapshot (the merge lives in the hook).
//
// **Summary / Plays / Box score / H2H**, and a tab only exists where its data
// does: a game ESPN hasn't filled in shows Summary and the series alone. Plays
// sits in the middle because chronology comes before rosters, and the Drives
// card lives inside it: leaving it on Summary would print the same rows in two
// tabs.
//
// H2H reads the pushed row rather than the summary, so it is offered from the
// first frame — which is the point: before kickoff it is the only other tab
// there is, and "who usually wins this" is the pre-game question. That does
// mean a pre-kick page now shows a tab row where it deliberately showed none;
// a row of two real answers is not the chrome-saying-nothing that rule was
// written against.
//
// Desktop splits that into two columns: the game itself on the left, and
// the context that surrounds it — where it's played, who showed up, what
// it does to the tables — in a rail on the right. The iPhone's single
// column keeps the same reading order, so the rail's cards land after the
// drives rather than between them; on a phone that's still "the game,
// then the context".

import type { ConferenceStandingsGroup, GameDetail } from "@/lib/types";
import { useState } from "react";
import { useLiveGame } from "@/lib/hooks/use-live-game";
import { useOnDemand } from "@/lib/hooks/use-on-demand";
import { getHeadToHead } from "@/lib/api";
import { HeroTabBar, type HeroTab } from "@/components/hero-tab-bar";
import {
  SlateToggleChip,
} from "@/components/slate-control-row";
import { scoringCardTitle, seasonYear } from "@/lib/leagues";
import { showsScores } from "./game-status";
import { GameHeader } from "./game-header";
import {
  GameInfoCard,
  VenueCard,
  gameInfoHasContent,
  venueHasContent,
} from "./game-info-cards";
import { GetTheAppCard } from "@/components/get-the-app";
import { LiveSituationCard } from "./live-situation-card";
import { LineScoreCard } from "./line-score-card";
import { ScoringPlaysCard } from "./scoring-plays-card";
import { TeamStatsCard, hasTeamStats } from "./team-stats-card";
import { LeadersCard } from "./leaders-card";
import {
  MatchupStandingsCard,
  matchupStandingsHasContent,
} from "./matchup-standings-card";
import { BoxScoreList } from "./box-score-list";
import { DrivePlayList, PeriodPlayList } from "./play-lists";
import { HeadToHeadPane } from "./head-to-head-pane";

interface GameDetailViewProps {
  initialData: GameDetail;
  /** Current-season conference standings; null when the fetch missed —
   * a miss just hides the matchup card. */
  standings: ConferenceStandingsGroup[] | null;
}

export function GameDetailView({
  initialData,
  standings,
}: GameDetailViewProps) {
  const data = useLiveGame(initialData.game.id, initialData);
  const { game } = data;
  const scores = showsScores(game);
  const [tab, setTab] = useState("summary");
  // Two answers to one question, the Games tabs' own control language: All
  // plays or Scoring, so turning one on turns the other off.
  const [scoringOnly, setScoringOnly] = useState(false);

  const hasLinescores =
    (game.awayTeam.linescores?.length ?? 0) > 0 ||
    (game.homeTeam.linescores?.length ?? 0) > 0;
  const scoringPlays = data.scoringPlays ?? [];
  const leaders = data.leaders ?? [];
  const drives = data.drives ?? [];
  const plays = data.plays ?? [];
  const boxScore = data.boxScore ?? [];

  // Football's plays live inside its drives; every other league's arrive
  // flat. Which list the Plays tab renders follows from that.
  const hasPlays = drives.length > 0 || plays.length > 0;
  // Whether a series is even askable. Both sides have to be named — an id is
  // what the meetings are filtered by — and a team cannot play itself.
  const awayId = game.awayTeam.team.id;
  const homeId = game.homeTeam.team.id;
  const hasHeadToHead = awayId !== "" && homeId !== "" && awayId !== homeId;
  const tabs: HeroTab[] = [
    { id: "summary", label: "Summary" },
    ...(hasPlays ? [{ id: "plays", label: "Plays" }] : []),
    ...(boxScore.length > 0 ? [{ id: "boxScore", label: "Box score" }] : []),
    ...(hasHeadToHead ? [{ id: "h2h", label: "H2H" }] : []),
  ];
  // A tab whose data went away between polls falls back rather than
  // rendering an empty pane.
  const activeTab = tabs.some((entry) => entry.id === tab) ? tab : "summary";

  // The series is fetched when its tab is first opened, not with the page —
  // twenty requests is a lot to spend on a tab most visits never reach.
  // Latched on the tap that opens it rather than watched for afterwards: once
  // asked for it stays asked for, so flipping back costs nothing.
  const [seriesRequested, setSeriesRequested] = useState(false);
  const selectTab = (id: string) => {
    setTab(id);
    if (id === "h2h") setSeriesRequested(true);
  };
  const series = useOnDemand(
    seriesRequested ? `${game.league}:${game.id}` : undefined,
    () => getHeadToHead(game.league, game.id)
  );
  const hasScoringPlays =
    drives.length > 0
      ? drives.some((drive) => (drive.plays ?? []).some((p) => p.isScoringPlay))
      : plays.some((play) => play.isScoringPlay);

  // Past-season games (reached by direct link) must not wear the current
  // season's standings — the fetch is always the current tables.
  // Read on **this game's league's** clock: a college-football rollover
  // would call June "next season" while the Stanley Cup was still being
  // played for, and February the same for the NFL.
  const isCurrentSeason =
    game.scheduledAt !== "" &&
    seasonYear(game.league, new Date(game.scheduledAt)) ===
      seasonYear(game.league);
  const standingsVisible =
    standings !== null &&
    isCurrentSeason &&
    matchupStandingsHasContent(
      game.awayTeam.team,
      game.homeTeam.team,
      standings
    );

  const venueVisible = venueHasContent(game, data);
  const infoVisible = gameInfoHasContent(game, data, standings);
  // "Scoring" in football, "Goals" in hockey, and no card at all in
  // basketball — ~98 buckets a game is the box score with worse formatting.
  const scoringTitle = scoringCardTitle(game.league);

  const showsTabs = tabs.length > 1;

  return (
    <div className="flex w-full flex-col gap-2">
      {/* The header sits on the card surface, and the tab row with it —
          headers match the cards on every entity page. */}
      <div className="flex flex-col">
        <GameHeader game={game} />
        {showsTabs && (
          <div className="-mt-2 rounded-b-[10px] bg-bg-card px-4">
            <HeroTabBar tabs={tabs} selected={activeTab} onSelect={selectTab} />
          </div>
        )}
      </div>

      {activeTab === "summary" && (
        // Desktop splits the summary into two columns: the game itself on
        // the left, and the context that surrounds it — where it's played,
        // who showed up, what it does to the tables — in a rail on the
        // right. The iPhone's single column keeps the same reading order.
        <div className="grid w-full gap-2 lg:grid-cols-[minmax(0,1fr)_320px] lg:items-start lg:gap-4">
          <div className="flex min-w-0 flex-col gap-2">
            {/* The Gamecast strip leads while a game is live: the down, the
                spot and the last play are what the page is being opened for
                at 3:30 on a Saturday. It is built from the drive in
                progress, which ESPN drops at final — so it retires itself. */}
            {data.situation && (
              <LiveSituationCard game={game} situation={data.situation} />
            )}
            {hasLinescores && <LineScoreCard game={game} />}
            {scoringPlays.length > 0 && scoringTitle && (
              <ScoringPlaysCard
                plays={scoringPlays}
                title={scoringTitle}
                game={game}
              />
            )}
            {scores && hasTeamStats(data.awayStats, data.homeStats) && (
              <TeamStatsCard
                awayTeam={game.awayTeam}
                homeTeam={game.homeTeam}
                awayStats={data.awayStats}
                homeStats={data.homeStats}
              />
            )}
            {leaders.length > 0 && (
              <LeadersCard
                leaders={leaders}
                awayTeam={game.awayTeam}
                homeTeam={game.homeTeam}
              />
            )}
          </div>

          <div className="flex min-w-0 flex-col gap-2">
            {/* One card was answering two questions: when and where to
                watch is one, the ground it's played on is another. Pre-kick
                every section on the left is empty, so the pair carries the
                whole "what do I need to know" load — but the questions
                outlive the kickoff, so both stay once a game starts. */}
            {infoVisible && (
              <GameInfoCard game={game} detail={data} standings={standings} />
            )}
            {venueVisible && <VenueCard game={game} detail={data} />}
            {standingsVisible && (
              <MatchupStandingsCard
                away={game.awayTeam.team}
                home={game.homeTeam.team}
                standings={standings}
              />
            )}
            {/* Last in the rail, and last in the phone's single column: a
                game page is where a shared link lands (the OpenGraph card,
                2026-09-09), so this is the one screen whose visitor may
                never have heard of the app — and the foot of the page they
                just read is where saying so is earned rather than sold. */}
            <GetTheAppCard />
          </div>
        </div>
      )}

      {activeTab === "plays" && (
        <div className="flex flex-col gap-2">
          <div className="flex items-center gap-2">
            <SlateToggleChip
              title="All plays"
              isOn={!scoringOnly}
              hint="Shows every play"
              onToggle={() => setScoringOnly(false)}
            />
            <SlateToggleChip
              title="Scoring"
              isOn={scoringOnly}
              hint="Shows only the plays that scored"
              onToggle={() => setScoringOnly(true)}
            />
          </div>
          {scoringOnly && !hasScoringPlays ? (
            <section className="card-surface px-4 py-8 text-center type-team-name text-text-secondary">
              No scoring plays yet.
            </section>
          ) : drives.length > 0 ? (
            <DrivePlayList
              drives={drives}
              game={game}
              scoringOnly={scoringOnly}
            />
          ) : (
            <PeriodPlayList
              plays={plays}
              game={game}
              scoringOnly={scoringOnly}
            />
          )}
        </div>
      )}

      {activeTab === "boxScore" && (
        <BoxScoreList boxScore={boxScore} game={game} />
      )}

      {activeTab === "h2h" && (
        <HeadToHeadPane
          away={game.awayTeam.team}
          home={game.homeTeam.team}
          state={series.state}
          onRetry={series.reload}
        />
      )}
    </div>
  );
}
