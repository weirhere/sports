import { Suspense } from "react";
import { SearchView } from "@/components/search-view";

export const metadata = {
  title: "Search | StatSide",
};

export default function SearchPage() {
  // The view reads its query and scope from the URL (`useSearchParams`), so
  // it renders under a boundary: the page stays static, and the params
  // resolve on the client.
  return (
    <Suspense fallback={null}>
      <SearchView />
    </Suspense>
  );
}
