import Image from "next/image";
import { Shield } from "lucide-react";
import { cn } from "@/lib/utils";

interface ConferenceLogoProps {
  /** Full URL of the conference mark; falls back to a glyph when absent. */
  src?: string | null;
  /** Conference name, used as the image alt text. */
  name: string;
  className?: string;
}

/**
 * A conference mark at 18px. In dark mode the wrapper shows a light
 * `logo-backing` disc (~3px padding) so navy marks (Big Ten, ACC) don't
 * sink into black — the iOS `logoBacking` treatment. In light mode the
 * backing token is transparent, so the disc is invisible but the layout
 * stays identical across modes.
 *
 * Team logos are handled elsewhere (team-logo.tsx owns team-mark
 * fetching, including dark variants) — this component is conference
 * marks only.
 */
export function ConferenceLogo({ src, name, className }: ConferenceLogoProps) {
  return (
    <span
      className={cn(
        "inline-flex shrink-0 items-center justify-center rounded-full bg-logo-backing p-[3px]",
        className
      )}
    >
      {src ? (
        <Image
          src={src}
          alt={name}
          width={18}
          height={18}
          className="h-[18px] w-[18px] object-contain"
          unoptimized
        />
      ) : (
        <Shield
          aria-hidden="true"
          className="h-[18px] w-[18px] text-text-secondary"
        />
      )}
    </span>
  );
}
