"use client";

export default function Error({
  error,
  reset,
}: {
  error: Error & { digest?: string };
  reset: () => void;
}) {
  // Surface the underlying failure for debugging; the UI stays generic.
  console.error(error);
  return (
    <div className="flex min-h-[50vh] flex-col items-center justify-center gap-3 text-center">
      <h2 className="type-hero-title text-text-primary">
        Something went wrong
      </h2>
      <p className="type-team-name text-text-secondary">
        An error occurred while loading this page.
      </p>
      <button
        type="button"
        onClick={reset}
        className="mt-2 rounded-full bg-text-primary px-5 py-2 type-chip-em text-bg-primary transition-opacity hover:opacity-90"
      >
        Try again
      </button>
    </div>
  );
}
