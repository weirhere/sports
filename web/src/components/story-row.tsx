// One story in a list — iOS `StoryRow` (Features/News/, E25): the headline,
// then who wrote it and how long ago (N7). Text only, by decision (N8): the
// rows every other news app leads with a photo are the app's type hierarchy
// here, and the one image is the chevron a row with a page behind it draws.

import Link from "next/link";
import { ChevronRight } from "lucide-react";
import type { NewsStory } from "@/lib/news";
import { StoryMeta } from "@/components/story-meta";
import { storyPath } from "@/lib/routes";

export function StoryRow({ story }: { story: NewsStory }) {
  return (
    <Link
      href={storyPath(story)}
      className="flex items-center gap-3 px-4 py-2 transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none"
    >
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="line-clamp-3 break-words type-team-name-em text-text-primary">
          {story.headline}
        </span>
        <StoryMeta story={story} time="relative" className="truncate" />
      </span>
      <ChevronRight aria-hidden="true" className="h-3 w-3 shrink-0 text-text-secondary" />
    </Link>
  );
}
