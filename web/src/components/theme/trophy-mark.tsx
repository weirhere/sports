import { Trophy } from "lucide-react";
import { cn } from "@/lib/utils";

/**
 * The Top 25 row's mark on the Leagues tab: a trophy, in the same 24px box
 * `ConferenceLogo` takes, so its name starts on the same rail as every
 * crest beside it (iOS, 2026-09-21).
 *
 * A trophy rather than the league's mark: on a hub where every other row
 * wears a real crest, a football among four leagues identified nothing its
 * neighbours didn't. The trophy says what kind of table this is. The Scores
 * section header keeps the league mark (`tableLogoUrl`), where the question
 * is whose poll.
 */
export function TrophyMark({ className }: { className?: string }) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        "inline-flex h-6 w-6 shrink-0 items-center justify-center text-text-primary",
        className
      )}
    >
      <Trophy className="h-[17px] w-[17px]" fill="currentColor" strokeWidth={2} />
    </span>
  );
}
