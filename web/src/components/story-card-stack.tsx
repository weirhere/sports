// Stories one to a card, full width, stacked — iOS `StoryCardStack`
// (Features/News/, 2026-10-19; FotMob's Latest, Mobbin `bfd98a17`): the
// photo on top, the headline and byline under it. The News tab's Latest and
// Transfers pages, and each league's share of its Leagues page ("image on
// top, text on bottom", never the thumbnail row).
//
// No stack of its own: the caller's column spaces the cards, so a page can
// put headings between runs of them.

import { FeaturedStory } from "@/components/featured-story";
import type { NewsStory } from "@/lib/news";

export function StoryCardStack({
  stories,
  priority = false,
}: {
  stories: NewsStory[];
  /** The first card's photo loads eagerly: it's above the fold. */
  priority?: boolean;
}) {
  return (
    <>
      {stories.map((story, index) => (
        <section key={story.id} className="card-surface">
          <FeaturedStory story={story} priority={priority && index === 0} />
        </section>
      ))}
    </>
  );
}
