import { Skeleton } from "@/components/ui/skeleton";

/** The reader's shape: a header card, then the text's card. */
export default function StoryLoading() {
  return (
    <div className="mx-auto flex w-full max-w-[38rem] flex-col gap-2">
      <div className="card-surface flex flex-col gap-2 px-4 py-5">
        <Skeleton className="h-3 w-12" />
        <Skeleton className="h-7 w-full" />
        <Skeleton className="h-7 w-2/3" />
        <Skeleton className="h-3 w-40" />
      </div>
      <div className="card-surface flex flex-col gap-2 px-4 py-4">
        {Array.from({ length: 6 }).map((_, index) => (
          <Skeleton key={index} className="h-4 w-full" />
        ))}
      </div>
    </div>
  );
}
