// A section of stories in one card — iOS `StorySection` (Features/News/,
// 2026-09-27, FotMob's For you): the first story featured at full width, the
// next four as rows, then "See more" to the page holding the rest. For you's
// Trending and team sections, and each league page of the News tab.

import Link from "next/link";
import { ChevronRight } from "lucide-react";
import { arrangedStories, type NewsStory } from "@/lib/news";
import { FeaturedStory } from "@/components/featured-story";
import { StoryRow } from "@/components/story-row";
import { Skeleton } from "@/components/ui/skeleton";


export function StorySection({
  stories,
  seeMoreHref,
  priority = false,
}: {
  stories: NewsStory[];
  /** Where "See more" goes; none draws no row. */
  seeMoreHref?: string;
  priority?: boolean;
}) {
  const [lead, ...rest] = arrangedStories(stories);
  if (!lead) return null;
  return (
    <section className={seeMoreHref ? "card-surface" : "card-surface pb-1"}>
      <FeaturedStory story={lead} priority={priority} />
      {rest.map((story) => (
        <div key={story.id}>
          <div className="ml-4 border-t border-divider" />
          <StoryRow story={story} />
        </div>
      ))}
      {seeMoreHref && (
        <Link
          href={seeMoreHref}
          className="flex items-center justify-between border-t border-divider px-4 py-3 type-team-name-em text-text-primary transition-colors hover:bg-bg-elevated focus-visible:bg-bg-elevated focus-visible:outline-none"
        >
          See more
          <ChevronRight aria-hidden="true" className="h-3 w-3 text-text-secondary" />
        </Link>
      )}
    </section>
  );
}

/** A section's shape while its stories are on the way. */
export function StorySectionSkeleton() {
  return (
    <section className="card-surface pb-1" aria-busy="true">
      <Skeleton className="aspect-video w-full rounded-none" />
      <div className="flex flex-col gap-1.5 px-4 py-3">
        <Skeleton className="h-5 w-full" />
        <Skeleton className="h-3 w-24" />
      </div>
      {Array.from({ length: 3 }).map((_, index) => (
        <div key={index} className="flex items-center gap-3 border-t border-divider px-4 py-2">
          <Skeleton className="aspect-[3/2] w-24 shrink-0 rounded-md" />
          <div className="flex flex-1 flex-col gap-1.5">
            <Skeleton className="h-4 w-full" />
            <Skeleton className="h-3 w-20" />
          </div>
        </div>
      ))}
    </section>
  );
}
