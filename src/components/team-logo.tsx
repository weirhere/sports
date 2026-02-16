import Image from "next/image";
import { ESPN_LOGO_BASE } from "@/lib/constants";

const SIZES = {
  sm: 24,
  md: 32,
  lg: 48,
  xl: 64,
} as const;

interface TeamLogoProps {
  espnId: number;
  teamName: string;
  size?: keyof typeof SIZES;
  className?: string;
}

export function TeamLogo({
  espnId,
  teamName,
  size = "md",
  className,
}: TeamLogoProps) {
  const px = SIZES[size];

  return (
    <Image
      src={`${ESPN_LOGO_BASE}/${espnId}.png`}
      alt={teamName}
      width={px}
      height={px}
      className={className}
      unoptimized
    />
  );
}
