// The follow control on browse rows, drawn — iOS `FollowCapsule`
// (2026-09-27, replacing the stars): a grey-filled "Follow" capsule while
// not following, an outlined "Following" one once you are. A word says what
// a click does where a star only hinted, and the fill-to-outline swap is
// weight, not color.
//
// Only the label. `FollowCapsuleButton` wraps it for rows where it is its
// own control; a row that is itself the toggle (the Add teams sheet,
// onboarding) draws it bare, to say which way the row is set.

import { cn } from "@/lib/utils";

export function FollowCapsule({ followed }: { followed: boolean }) {
  return (
    <span
      aria-hidden="true"
      className={cn(
        "inline-grid shrink-0 place-items-center rounded-full border px-3 py-1.5 type-meta-em text-text-primary transition-colors",
        followed
          ? "border-text-primary/35 bg-transparent"
          : "border-transparent bg-bg-inset"
      )}
    >
      {/* Both words laid out in one cell, one shown: the capsule is always
          as wide as "Following", so a click never resizes it and every
          row's control shares one leading edge. */}
      <span className="invisible col-start-1 row-start-1">Following</span>
      <span className="col-start-1 row-start-1">
        {followed ? "Following" : "Follow"}
      </span>
    </span>
  );
}

/** A `FollowCapsule` as its own button, beside a row that navigates. */
export function FollowCapsuleButton({
  followed,
  name,
  onToggle,
}: {
  followed: boolean;
  /** Spoken in the label — a list of identical "Follow" buttons gives a
   *  screen reader nothing to distinguish. */
  name: string;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onToggle}
      aria-label={followed ? `Unfollow ${name}` : `Follow ${name}`}
      aria-pressed={followed}
      // 34px tall: the iOS row control's tap target.
      className="flex min-h-[34px] shrink-0 items-center"
    >
      <FollowCapsule followed={followed} />
    </button>
  );
}
