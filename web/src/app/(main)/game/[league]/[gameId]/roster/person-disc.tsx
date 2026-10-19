"use client";

// A player's photo in a quiet disc, with the jersey number showing through
// wherever ESPN has no photo (iOS `PersonDisc`): on a field the number is
// how a player is found. A photo that 404s falls back to the number too.

import { useState } from "react";
import Image from "next/image";
import { headshotThumbnail } from "@/lib/logos";
import { cn } from "@/lib/utils";

export function PersonDisc({
  jersey,
  headshotUrl,
  size = 32,
  className,
  style,
}: {
  jersey?: string;
  headshotUrl?: string;
  size?: number;
  className?: string;
  style?: React.CSSProperties;
}) {
  const [failed, setFailed] = useState(false);
  const src = headshotUrl ? (headshotThumbnail(headshotUrl) ?? headshotUrl) : undefined;
  return (
    <span
      aria-hidden="true"
      className={cn(
        "relative inline-flex shrink-0 items-center justify-center overflow-hidden rounded-full bg-bg-elevated",
        className
      )}
      style={{ width: size, height: size, ...style }}
    >
      <span
        className="tnum font-semibold text-text-secondary"
        style={{ fontSize: Math.round(size * 0.34) }}
      >
        {jersey ?? ""}
      </span>
      {src && !failed && (
        <Image
          src={src}
          alt=""
          width={size}
          height={size}
          unoptimized
          loading="lazy"
          onError={() => setFailed(true)}
          className="absolute inset-0 h-full w-full object-cover"
        />
      )}
    </span>
  );
}

/** A coach's monogram or photo in the same disc (iOS `CoachHeadshot`). */
export function InitialsDisc({ name, size = 32 }: { name: string; size?: number }) {
  const initials = name
    .split(" ")
    .filter((word) => word.length > 0)
    .slice(0, 2)
    .map((word) => word[0]!.toUpperCase())
    .join("");
  return (
    <span
      aria-hidden="true"
      className="inline-flex shrink-0 items-center justify-center rounded-full bg-bg-elevated font-semibold text-text-secondary"
      style={{ width: size, height: size, fontSize: Math.round(size * 0.34) }}
    >
      {initials}
    </span>
  );
}
