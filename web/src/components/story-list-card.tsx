// A list of stories in one card — iOS `StoryListCard` (Features/News/): a
// header over `StoryRow`s with the roster's inset dividers. The team page's
// News tab (N9) and the News tab's feeds (E26).

import { CardHeader } from "@/components/card-header";
import { StoryRow } from "@/components/story-row";
import { Skeleton } from "@/components/ui/skeleton";
import type { NewsStory } from "@/lib/news";

export function StoryListCard({ stories }: { stories: NewsStory[] }) {
  return (
    <section className="card-surface pb-1">
      <CardHeader title="Latest" />
      {stories.map((story, index) => (
        <div key={story.id}>
          {index > 0 && <div className="ml-4 border-t border-divider" />}
          <StoryRow story={story} />
        </div>
      ))}
    </section>
  );
}

/** The card's shape while its stories are on the way. */
export function StoryListCardSkeleton() {
  return (
    <section className="card-surface pb-1" aria-busy="true">
      <CardHeader title="Latest" />
      {Array.from({ length: 4 }).map((_, index) => (
        <div key={index} className="flex flex-col gap-1.5 px-4 py-3">
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-3 w-24" />
        </div>
      ))}
    </section>
  );
}
