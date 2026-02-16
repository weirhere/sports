"use client";

import { cn } from "@/lib/utils";

interface LiveIndicatorProps {
  className?: string;
}

export function LiveIndicator({ className }: LiveIndicatorProps) {
  return (
    <span className={cn("inline-flex items-center gap-1.5", className)}>
      <span className="relative flex h-2 w-2">
        <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-red-500 opacity-75" />
        <span className="relative inline-flex h-2 w-2 rounded-full bg-red-500" />
      </span>
      <span className="text-xs font-semibold uppercase text-red-500">Live</span>
    </span>
  );
}
