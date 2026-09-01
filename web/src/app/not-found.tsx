import Link from "next/link";

export default function NotFound() {
  return (
    <div className="flex min-h-screen flex-col items-center justify-center gap-3 bg-bg-recessed text-center">
      <h1 className="type-hero-title text-text-primary">404</h1>
      <p className="type-team-name text-text-secondary">
        The page you&apos;re looking for doesn&apos;t exist.
      </p>
      <Link
        href="/"
        className="mt-2 rounded-full bg-text-primary px-5 py-2 type-chip-em text-bg-primary transition-opacity hover:opacity-90"
      >
        Back to scores
      </Link>
    </div>
  );
}
