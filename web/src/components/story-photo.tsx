"use client";

// A story's photo, cropped to its box — iOS `StoryPhoto` (Features/News/).
// Full color: news photography is the color budget's sixth exception
// (2026-09-27), drawn only in story cards, rows and the reader's hero.
// Until it lands, and if it never does, the box is the elevated gray a logo
// waits on — a failed load drops the image rather than showing the
// browser's broken-image mark.
//
// `unoptimized`, like the roster's headshots: the photos come from two ESPN
// hosts, and resizing them is ESPN's CDN's job, not an image quota's.

import Image from "next/image";
import { useState } from "react";
import { cn } from "@/lib/utils";

export function StoryPhoto({
  url,
  className,
  sizes,
  priority = false,
}: {
  url?: string;
  className?: string;
  sizes: string;
  priority?: boolean;
}) {
  const [failedUrl, setFailedUrl] = useState<string>();
  return (
    <div className={cn("relative overflow-hidden bg-bg-elevated", className)} aria-hidden="true">
      {url && url !== failedUrl && (
        <Image
          src={url}
          alt=""
          fill
          sizes={sizes}
          unoptimized
          priority={priority}
          onError={() => setFailedUrl(url)}
          className="object-cover"
        />
      )}
    </div>
  );
}
