"use client";

// A team mark that honors dark mode: ESPN's `500-dark` variant renders on
// the black background (Ohio State's black lettering vanishes otherwise),
// derived via `darkTeamLogoVariant` — the payload never carries the dark
// URL. A missing dark asset 404s → fall back to the light mark.

import { useState } from "react";
import Image from "next/image";
import { darkTeamLogoVariant } from "@/lib/logos";
import { cn } from "@/lib/utils";

interface TeamMarkProps {
  logoUrl: string;
  alt: string;
  size: number;
  className?: string;
}

export function TeamMark({ logoUrl, alt, size, className }: TeamMarkProps) {
  const darkUrl = darkTeamLogoVariant(logoUrl);
  const [darkFailed, setDarkFailed] = useState(false);
  const useDarkVariant = darkUrl !== null && !darkFailed;

  return (
    <>
      <Image
        src={logoUrl}
        alt={alt}
        width={size}
        height={size}
        unoptimized
        className={cn(useDarkVariant && "dark:hidden", className)}
      />
      {useDarkVariant && (
        <Image
          src={darkUrl}
          alt={alt}
          width={size}
          height={size}
          unoptimized
          onError={() => setDarkFailed(true)}
          className={cn("hidden dark:block", className)}
        />
      )}
    </>
  );
}
