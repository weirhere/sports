import { ScoresView } from "./scores-view";
import { getGamesByWeek } from "@/lib/mock";

const CURRENT_WEEK = 8;

export default function ScoresPage() {
  const games = getGamesByWeek(CURRENT_WEEK);

  return (
    <div>
      <ScoresView initialGames={games} initialWeek={CURRENT_WEEK} />
    </div>
  );
}
