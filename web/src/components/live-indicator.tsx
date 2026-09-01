import { LiveDot } from "@/components/theme/live-dot";
import { cn } from "@/lib/utils";

interface LiveIndicatorProps {
  className?: string;
}

export function LiveIndicator({ className }: LiveIndicatorProps) {
  return (
    <span className={cn("inline-flex items-center gap-1.5", className)}>
      <LiveDot />
      <span className="text-xs font-semibold uppercase text-live">Live</span>
    </span>
  );
}
