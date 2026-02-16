import { GameCardSkeleton } from "@/components/game-card-skeleton";
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

      {/* Game cards skeleton */}
      <div className="mt-4 grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
        {Array.from({ length: 9 }).map((_, i) => (
          <GameCardSkeleton key={i} />
        ))}
      </div>
    </div>
  );
}
