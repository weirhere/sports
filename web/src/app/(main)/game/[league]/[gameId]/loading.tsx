import { Skeleton } from "@/components/ui/skeleton";

/**
 * Skeleton mirroring the detail layout: the game's own column on the left,
 * the context rail on the right (desktop), header card then content cards.
 */
export default function GameDetailLoading() {
  return (
    <div className="grid w-full gap-2 lg:grid-cols-[minmax(0,1fr)_320px] lg:items-start lg:gap-4">
      <div className="flex min-w-0 flex-col gap-2">
        {/* Header: two team columns around a center score/status column. */}
        <div className="card-surface px-4 py-5">
          <div className="flex items-start justify-between gap-4">
            <div className="flex flex-1 flex-col items-center gap-2">
              <Skeleton className="h-11 w-11 rounded-full" />
              <Skeleton className="h-4 w-20" />
            </div>
            <div className="flex flex-col items-center gap-2 pt-1">
              <Skeleton className="h-9 w-24" />
              <Skeleton className="h-3 w-16" />
            </div>
            <div className="flex flex-1 flex-col items-center gap-2">
              <Skeleton className="h-11 w-11 rounded-full" />
              <Skeleton className="h-4 w-20" />
            </div>
          </div>
        </div>

        {/* Content cards */}
        {Array.from({ length: 3 }).map((_, i) => (
          <div key={i} className="card-surface p-3">
            <Skeleton className="mb-3 h-4 w-24" />
            <div className="flex flex-col gap-2">
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-4 w-full" />
              <Skeleton className="h-4 w-2/3" />
            </div>
          </div>
        ))}
      </div>

      {/* Context rail */}
      <div className="card-surface p-3">
        <Skeleton className="mb-3 h-4 w-20" />
        <div className="flex flex-col gap-2">
          <Skeleton className="h-4 w-full" />
          <Skeleton className="h-4 w-3/4" />
        </div>
      </div>
    </div>
  );
}
