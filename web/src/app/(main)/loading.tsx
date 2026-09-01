import { ConferenceGroupSkeleton } from "@/components/game-card-skeleton";
import { Skeleton } from "@/components/ui/skeleton";

export default function ScoresLoading() {
  return (
    <div>
      {/* Week selector skeleton */}
      <div className="flex gap-2 overflow-hidden border-b pb-2">
        {Array.from({ length: 8 }).map((_, i) => (
          <Skeleton key={i} className="h-8 w-16 shrink-0 rounded-full" />
        ))}
      </div>

      {/* Day header skeleton */}
      <Skeleton className="mt-6 h-6 w-48" />

      {/* Conference group skeletons */}
      <div className="mt-4 space-y-3">
        {Array.from({ length: 4 }).map((_, i) => (
          <ConferenceGroupSkeleton key={i} rows={i === 0 ? 4 : 3} />
        ))}
      </div>
    </div>
  );
}
