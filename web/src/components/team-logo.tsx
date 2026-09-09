import Image from "next/image";
import { teamLogoBase } from "@/lib/leagues";
import type { Team } from "@/lib/types";

const SIZES = {
  sm: 24,
  md: 32,
  lg: 48,
  xl: 64,
} as const;

interface TeamLogoProps {
  /**
   * The whole team, never a bare id.
   *
   * ESPN's team ids collide across leagues, and this component used to
   * build its URL from an id against a hardcoded **college** bucket — so
   * every pro team wore whatever college program shared its number: New
   * England (NFL 17) rendered Claremont-Mudd-Scripps, and Seattle (26)
   * rendered UCLA. The league is what disambiguates the bucket, and the
   * payload's own `logoUrl` beats deriving one at all.
   */
  team: Pick<Team, "espnId" | "league" | "logoUrl">;
  teamName: string;
  size?: keyof typeof SIZES;
  className?: string;
}

/**
 * The mark ESPN published, or one derived from the league's own bucket.
 *
 * Derivation is the fallback, not the rule: the NHL files its logos by
 * abbreviation (`nhl/500/scoreboard/sea.png`), so an id-derived URL 404s
 * there however right the bucket is. Every league's payload carries a
 * `logo`, and the mapper already prefers it.
 */
export function teamLogoSrc(
  team: Pick<Team, "espnId" | "league" | "logoUrl">
): string {
  return team.logoUrl || `${teamLogoBase(team.league)}/${team.espnId}.png`;
}

export function TeamLogo({
  team,
  teamName,
  size = "md",
  className,
}: TeamLogoProps) {
  const px = SIZES[size];

  return (
    <Image
      src={teamLogoSrc(team)}
      alt={teamName}
      width={px}
      height={px}
      className={className}
      unoptimized
    />
  );
}
