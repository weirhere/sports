import { Skeleton } from "@/components/ui/skeleton";

export default function GameDetailLoading() {
  return (
    <div>
      {/* Game header skeleton */}
      <div className="mb-6 rounded-lg border bg-card p-6">
        <div className="flex items-center justify-center gap-12">
          <div className="flex flex-col items-center gap-2">
            <Skeleton className="h-16 w-16 rounded-full" />
            <Skeleton className="h-5 w-24" />
          </div>
          <div className="flex flex-col items-center gap-2">
            <Skeleton className="h-10 w-32" />
            <Skeleton className="h-4 w-16" />
          </div>
          <div className="flex flex-col items-center gap-2">
            <Skeleton className="h-16 w-16 rounded-full" />
            <Skeleton className="h-5 w-24" />
          </div>
        </div>
      </div>

      {/* Tabs skeleton */}
      <div className="mb-4 flex gap-2">
        <Skeleton className="h-9 w-24 rounded-md" />
        <Skeleton className="h-9 w-28 rounded-md" />
        <Skeleton className="h-9 w-24 rounded-md" />
      </div>

      <div className="space-y-2">
        {Array.from({ length: 6 }).map((_, i) => (
          <Skeleton key={i} className="h-10 w-full rounded" />
        ))}
      </div>
    </div>
  );
}
