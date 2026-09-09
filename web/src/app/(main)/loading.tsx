import { ConferenceGroupSkeleton } from "@/components/game-card-skeleton";
import { Skeleton } from "@/components/ui/skeleton";

/** Mirrors the scores layout: the follow rail's column, then the slate. */
export default function ScoresLoading() {
  return (
    <div>
      {/* Day strip skeleton */}
      <div className="flex gap-2 overflow-hidden border-b pb-2">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton key={i} className="h-8 w-16 shrink-0 rounded-full" />
        ))}
      </div>

      <div className="mt-6 grid gap-[var(--sidebar-gap)] lg:grid-cols-[var(--sidebar-w)_minmax(0,1fr)] lg:items-start">
        <div className="hidden lg:block">
          <Skeleton className="h-40 w-full rounded-[10px]" />
        </div>

        <div className="min-w-0">
          {/* Day header skeleton */}
          <Skeleton className="h-6 w-48" />

          {/* Conference group skeletons */}
          <div className="mt-4 space-y-3">
            {Array.from({ length: 4 }).map((_, i) => (
              <ConferenceGroupSkeleton key={i} rows={i === 0 ? 4 : 3} />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
