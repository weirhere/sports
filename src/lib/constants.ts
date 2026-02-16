export const CURRENT_SEASON_YEAR = 2025;
export const SEASON_TYPE = "regular"; // "regular", "postseason"
export const MAX_REGULAR_WEEKS = 15;
export const POLL_INTERVAL_LIVE = 30_000; // 30s for live games
export const POLL_INTERVAL_IDLE = 60_000; // 60s when no live games
export const ESPN_LOGO_BASE = "https://a.espncdn.com/i/teamlogos/ncaa/500";
export const ESPN_API_BASE =
  "https://site.api.espn.com/apis/site/v2/sports/football/college-football";

export const WEEKS: { number: number; label: string }[] = [
  { number: 0, label: "Week 0" },
  { number: 1, label: "Week 1" },
  { number: 2, label: "Week 2" },
  { number: 3, label: "Week 3" },
  { number: 4, label: "Week 4" },
  { number: 5, label: "Week 5" },
  { number: 6, label: "Week 6" },
  { number: 7, label: "Week 7" },
  { number: 8, label: "Week 8" },
  { number: 9, label: "Week 9" },
  { number: 10, label: "Week 10" },
  { number: 11, label: "Week 11" },
  { number: 12, label: "Week 12" },
  { number: 13, label: "Week 13" },
  { number: 14, label: "Week 14" },
  { number: 15, label: "Week 15" },
  { number: 16, label: "Bowls" },
];
