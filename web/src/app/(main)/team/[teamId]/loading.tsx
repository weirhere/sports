import { Skeleton } from "@/components/ui/skeleton";

export default function TeamLoading() {
  return (
    <div>
      {/* Hero skeleton — mirrors HeroHeader's card-color surface. */}
      <div className="-mx-4 -mt-3 bg-bg-card px-4 pt-4">
        <div className="flex items-center gap-3">
          <Skeleton className="h-14 w-14 rounded-full" />
          <div className="flex-1 space-y-2">
            <Skeleton className="h-6 w-44" />
            <Skeleton className="h-4 w-24" />
          </div>
          <Skeleton className="h-8 w-24 rounded-full" />
        </div>
        <div className="mt-1 flex items-center gap-10 py-3.5">
          <Skeleton className="h-4 w-16" />
          <Skeleton className="h-4 w-14" />
          <Skeleton className="h-4 w-18" />
        </div>
      </div>

      <div className="flex flex-col gap-2 py-2">
        <Skeleton className="h-24 w-full rounded-[10px]" />
        <Skeleton className="h-28 w-full rounded-[10px]" />
      </div>
    </div>
  );
}
