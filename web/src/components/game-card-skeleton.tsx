import { Skeleton } from "@/components/ui/skeleton";

function GameRowSkeleton() {
  return (
    <div className="flex items-center gap-3 px-4 py-3">
      {/* Team lines, mirroring the GameRow shape */}
      <div className="flex min-w-0 flex-1 flex-col gap-1.5">
        <div className="flex items-center gap-2">
          <Skeleton className="h-5 w-5 rounded-full" />
          <Skeleton className="h-3 w-28" />
        </div>
        <div className="flex items-center gap-2">
          <Skeleton className="h-5 w-5 rounded-full" />
          <Skeleton className="h-3 w-24" />
        </div>
      </div>
      {/* Hairline + status column */}
      <div className="h-11 w-px shrink-0 bg-divider" />
      <div className="flex w-20 shrink-0 flex-col gap-1.5">
        <Skeleton className="h-2.5 w-14" />
        <Skeleton className="h-2.5 w-10" />
      </div>
    </div>
  );
}

/** Skeleton for one section accordion (header + game rows). */
export function ConferenceGroupSkeleton({ rows = 3 }: { rows?: number }) {
  return (
    <div className="card-surface">
      <div className="bg-bg-header px-4 py-3">
        <Skeleton className="h-3.5 w-24" />
      </div>
      <div>
        {Array.from({ length: rows }).map((_, i) => (
          <div key={i}>
            {i > 0 && <div className="ml-4 border-t border-divider" />}
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
