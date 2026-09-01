// The Game info card (iOS gameInfoRows/venueRows): pre-game it carries the
// "what do I need to know" load — kickoff, network, venue, capacity +
// surface, weather. Live/final it returns as the venue card — where the
// game is (was) and how many showed up. Each row renders only when the
// payload actually knows it.

import type { LucideIcon } from "lucide-react";
import { Calendar, CloudSun, LandPlot, MapPin, Tv, Users } from "lucide-react";
import type { Game, GameDetail } from "@/lib/types";
import { DetailCard } from "./detail-card";
import { kickoffDayText, kickoffTimeText } from "./game-status";

interface GameInfoCardProps {
  game: Game;
  detail: GameDetail;
  /** "pre" = the full pre-game card; "venue" = the live/final one. */
  mode: "pre" | "venue";
}

export function GameInfoCard({ game, detail, mode }: GameInfoCardProps) {
  const rows = mode === "pre" ? preRows(game, detail) : venueRows(game, detail);
  if (rows.length === 0) return null;

  return (
    <DetailCard title="Game info">
      <ul className="py-1">
        {rows.map((row) => (
          <li
            key={row.key}
            className="flex items-center gap-3 px-4 py-[7px]"
          >
            <row.icon
              aria-hidden="true"
              className="h-4 w-4 shrink-0 text-text-secondary"
            />
            <span className="type-team-name tnum text-text-primary">
              {row.text}
            </span>
          </li>
        ))}
      </ul>
    </DetailCard>
  );
}

interface InfoRow {
  key: string;
  icon: LucideIcon;
  text: string;
}

function venueLine(game: Game): string | undefined {
  const cityState = [game.venue.city, game.venue.state]
    .filter(Boolean)
    .join(", ");
  const line = [game.venue.name, cityState].filter(Boolean).join(" · ");
  return line || undefined;
}

function preRows(game: Game, detail: GameDetail): InfoRow[] {
  const rows: InfoRow[] = [];

  if (game.scheduledAt) {
    const day = kickoffDayText(game.scheduledAt);
    rows.push({
      key: "kickoff",
      icon: Calendar,
      text: game.timeTBD
        ? `${day} · Kickoff TBD`
        : `${day} · ${kickoffTimeText(game.scheduledAt)}`,
    });
  }
  if (game.broadcast) {
    rows.push({ key: "broadcast", icon: Tv, text: game.broadcast });
  }
  const venue = venueLine(game);
  if (venue) {
    rows.push({ key: "venue", icon: MapPin, text: venue });
  }
  const capacity =
    detail.venueCapacity !== undefined
      ? `Capacity ${detail.venueCapacity.toLocaleString("en-US")}`
      : undefined;
  const surface =
    detail.venueSurface !== undefined
      ? detail.venueSurface === "grass"
        ? "Grass"
        : "Turf"
      : undefined;
  const field = [capacity, surface].filter(Boolean).join(" · ");
  if (field) {
    rows.push({ key: "field", icon: LandPlot, text: field });
  }
  const weather = [
    detail.weatherTemperature !== undefined
      ? `${detail.weatherTemperature}°`
      : undefined,
    detail.weatherCondition,
  ]
    .filter(Boolean)
    .join(" · ");
  if (weather) {
    rows.push({ key: "weather", icon: CloudSun, text: weather });
  }
  return rows;
}

function venueRows(game: Game, detail: GameDetail): InfoRow[] {
  const rows: InfoRow[] = [];
  const venue = venueLine(game);
  if (venue) {
    rows.push({ key: "venue", icon: MapPin, text: venue });
  }
  if (detail.attendance !== undefined) {
    rows.push({
      key: "attendance",
      icon: Users,
      text: `Attendance ${detail.attendance.toLocaleString("en-US")}`,
    });
  }
  return rows;
}
