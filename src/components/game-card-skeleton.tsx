import { Skeleton } from "@/components/ui/skeleton";

function GameRowSkeleton() {
  return (
    <div className="flex items-center gap-3 px-4 py-3">
      {/* Status column */}
      <div className="flex w-12 shrink-0 items-center justify-center">
        <Skeleton className="h-3 w-8" />
      </div>

      {/* Teams */}
      <div className="flex min-w-0 flex-1 flex-col gap-1.5">
        <div className="flex items-center gap-2.5">
          <Skeleton className="h-5 w-5 rounded-full" />
          <Skeleton className="h-3.5 w-28" />
          <Skeleton className="ml-auto h-3.5 w-6" />
        </div>
        <div className="flex items-center gap-2.5">
          <Skeleton className="h-5 w-5 rounded-full" />
          <Skeleton className="h-3.5 w-24" />
          <Skeleton className="ml-auto h-3.5 w-6" />
        </div>
      </div>
    </div>
  );
}

/** Skeleton for a single conference container with game rows */
export function ConferenceGroupSkeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div className="overflow-hidden rounded-xl border bg-card shadow-sm">
      <div className="px-4 py-3">
        <Skeleton className="h-4 w-24" />
      </div>
      <div className="border-t">
        {Array.from({ length: rows }).map((_, i) => (
          <div key={i}>
            {i > 0 && <div className="mx-4 border-t" />}
            <GameRowSkeleton />
          </div>
        ))}
      </div>
    </div>
  );
}

/** @deprecated Use ConferenceGroupSkeleton for the scores page. Kept for team/conference pages. */
export function GameCardSkeleton() {
  return (
    <div className="rounded-lg border bg-card p-4">
      {/* Away team */}
      <div className="flex items-center gap-3">
        <Skeleton className="h-8 w-8 rounded-full" />
        <Skeleton className="h-4 w-32" />
        <Skeleton className="ml-auto h-5 w-8" />
      </div>

      <div className="my-2.5" />

      {/* Home team */}
      <div className="flex items-center gap-3">
        <Skeleton className="h-8 w-8 rounded-full" />
        <Skeleton className="h-4 w-28" />
        <Skeleton className="ml-auto h-5 w-8" />
      </div>

      {/* Status */}
      <div className="mt-3 flex items-center justify-between border-t pt-2.5">
        <Skeleton className="h-3 w-16" />
        <Skeleton className="h-3 w-12" />
      </div>
    </div>
  );
}
