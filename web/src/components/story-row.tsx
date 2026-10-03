// One story in a list — iOS `StoryRow` (Features/News/): the photo small at
// the leading edge, the headline, then who wrote it and how long ago (N7).
// FotMob's row under its lead card. The thumbnail is the row's "a page is
// behind this" cue; a story with no photo falls back to the chevron.

import Link from "next/link";
import { ChevronRight } from "lucide-react";
import type { NewsStory } from "@/lib/news";
import { StoryMeta } from "@/components/story-meta";
import { StoryPhoto } from "@/components/story-photo";
import { storyPath } from "@/lib/routes";

export function StoryRow({ story }: { story: NewsStory }) {
  return (
    <Link
      href={storyPath(story)}
      className="flex items-center gap-3 px-4 py-2 transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none"
    >
      {story.imageUrl && (
        <StoryPhoto
          url={story.imageUrl}
          sizes="96px"
          className="aspect-[3/2] w-24 shrink-0 rounded-md"
        />
      )}
      <span className="flex min-w-0 flex-1 flex-col gap-0.5">
        <span className="line-clamp-3 break-words type-team-name-em text-text-primary">
          {story.headline}
        </span>
        <StoryMeta story={story} time="relative" className="truncate" />
      </span>
      {!story.imageUrl && (
        <ChevronRight aria-hidden="true" className="h-3 w-3 shrink-0 text-text-secondary" />
      )}
    </Link>
  );
}
