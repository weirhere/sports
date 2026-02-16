import { ScoresView } from "./scores-view";
import { getGamesByWeek } from "@/lib/mock";
import { CURRENT_SEASON_YEAR } from "@/lib/constants";

const CURRENT_WEEK = 8;

export default function ScoresPage() {
  const games = getGamesByWeek(CURRENT_WEEK);

  return (
    <div>
      <ScoresView
        initialGames={games}
        initialWeek={CURRENT_WEEK}
        initialYear={CURRENT_SEASON_YEAR}
      />
    </div>
  );
}
