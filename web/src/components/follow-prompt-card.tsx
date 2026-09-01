"use client";

// The Following slot's empty state — the iOS `FollowPromptCard`: when the
// user follows nobody, this card does the teaching. Payoff first, one CTA
// into Teams, and a quiet way out. Monochrome.

import Link from "next/link";
import { Star } from "lucide-react";

interface FollowPromptCardProps {
  onDismiss: () => void;
}

export function FollowPromptCard({ onDismiss }: FollowPromptCardProps) {
  return (
    <div className="card-surface flex flex-col items-center px-4 pb-2 pt-6 text-center">
      <Star aria-hidden="true" className="h-6 w-6 text-text-secondary" />
      <p className="type-team-name-em mt-2 text-text-primary">
        Follow your teams
      </p>
      <p className="type-meta mt-1 text-text-secondary">
        They&apos;ll lead this screen every Saturday.
      </p>
      <Link
        href="/teams"
        className="type-chip mt-3 rounded-full bg-text-primary px-4 py-1.5 text-bg-primary transition-opacity hover:opacity-85"
      >
        Pick your teams
      </Link>
      <button
        type="button"
        onClick={onDismiss}
        className="type-meta mt-1 min-h-8 px-4 text-text-secondary transition-colors hover:text-text-primary"
      >
        Don&apos;t show again
      </button>
    </div>
  );
}
