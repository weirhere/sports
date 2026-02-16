import { cn } from "@/lib/utils";

interface ScoreDisplayProps {
  score: number | null;
  isWinner?: boolean;
  isLive?: boolean;
  className?: string;
}

export function ScoreDisplay({
  score,
  isWinner,
  isLive,
  className,
}: ScoreDisplayProps) {
  if (score === null) return null;

  return (
    <span
      className={cn(
        "font-score text-lg",
        isWinner && "font-bold",
        isLive && "text-foreground",
        !isWinner && !isLive && "text-muted-foreground",
        className
      )}
    >
      {score}
    </span>
  );
}
