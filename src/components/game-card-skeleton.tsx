import { Skeleton } from "@/components/ui/skeleton";

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
