import { Skeleton } from "@/components/ui/skeleton";

/** The hub is a row list — skeleton rows shaped like its cards. */
export default function RankingsLoading() {
  return (
    <div className="flex flex-col gap-2" aria-hidden="true">
      <Skeleton className="mx-3 mt-2 h-4 w-24" />
      {Array.from({ length: 8 }).map((_, i) => (
        <div
          key={i}
          className="card-surface flex min-h-12 items-center gap-3 px-4 py-[7px]"
        >
          <Skeleton className="h-6 w-6 rounded-full" />
          <Skeleton className="h-4 w-28" />
          <Skeleton className="ml-auto h-4 w-16" />
        </div>
      ))}
    </div>
  );
}
