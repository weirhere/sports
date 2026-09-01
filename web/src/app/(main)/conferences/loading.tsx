import { Skeleton } from "@/components/ui/skeleton";

export default function ConferencesLoading() {
  return (
    <div className="space-y-8">
      {/* Rankings skeleton */}
      <div>
        <Skeleton className="mb-4 h-7 w-32" />
        <div className="flex gap-3 overflow-hidden">
          {Array.from({ length: 6 }).map((_, i) => (
            <Skeleton key={i} className="h-16 w-48 shrink-0 rounded-lg" />
          ))}
        </div>
      </div>

      {/* Conferences skeleton */}
      <div>
        <Skeleton className="mb-4 h-7 w-40" />
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-3">
          {Array.from({ length: 9 }).map((_, i) => (
            <Skeleton key={i} className="h-16 rounded-lg" />
          ))}
        </div>
      </div>
    </div>
  );
}
