"use client";

// A story's "AP · 2h ago" line (iOS N7). The time is the reader's own —
// relative in a list, exact in the reader — and the server can't know the
// reader's clock or zone, so until hydration the line says who wrote it and
// nothing else, `AppearancePicker`'s rule for browser-only facts: say less
// rather than guess and correct a frame later.

import { useSyncExternalStore } from "react";
import { exactTime, relativeTime, storyMeta, type NewsStory } from "@/lib/news";
import { cn } from "@/lib/utils";

const noSubscribe = () => () => {};

export function StoryMeta({
  story,
  time,
  className,
}: {
  story: NewsStory;
  time: "relative" | "exact";
  className?: string;
}) {
  const isClient = useSyncExternalStore(noSubscribe, () => true, () => false);
  const when =
    isClient && story.published
      ? time === "relative"
        ? relativeTime(story.published)
        : exactTime(story.published)
      : undefined;
  const meta = storyMeta(story, when);
  if (!meta && !story.published) return null;
  // Held open while the time is still to come, so the line doesn't push
  // the card's height when it lands.
  return <span className={cn("type-meta text-text-secondary", className)}>{meta ?? " "}</span>;
}
