// A story at full width — iOS `FeaturedStory` (Features/News/): the photo at
// 16:9, then the headline and who wrote it. FotMob's lead card (Mobbin
// `bfd98a17`): a section's first story, and every story in For you's Latest.
// No card of its own; the section or the list decides the surface, and the
// card's clip rounds the photo's top corners.

import Link from "next/link";
import type { NewsStory } from "@/lib/news";
import { StoryMeta } from "@/components/story-meta";
import { StoryPhoto } from "@/components/story-photo";
import { storyPath } from "@/lib/routes";

export function FeaturedStory({
  story,
  priority = false,
}: {
  story: NewsStory;
  priority?: boolean;
}) {
  return (
    <Link
      href={storyPath(story)}
      data-photo={story.imageUrl ? "true" : "false"}
      className="flex flex-col gap-2 pb-3 transition-colors data-[photo=false]:pt-3 hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none"
    >
      {story.imageUrl && (
        <StoryPhoto
          url={story.imageUrl}
          sizes="(min-width: 768px) 720px, 100vw"
          priority={priority}
          className="aspect-video w-full"
        />
      )}
      <span className="flex flex-col gap-1 px-4">
        <span className="line-clamp-4 break-words type-story-featured text-text-primary">
          {story.headline}
        </span>
        <StoryMeta story={story} time="relative" className="truncate" />
      </span>
    </Link>
  );
}
