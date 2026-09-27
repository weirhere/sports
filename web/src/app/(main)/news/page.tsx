import { NewsView } from "./news-view";

export const metadata = {
  title: "News | StatSide",
};

/**
 * The News tab (iOS E26): every league's stories in one place. For you
 * reads the follows stored in the browser, so the page is a shell and the
 * view does the fetching.
 */
export default function NewsPage() {
  return <NewsView />;
}
