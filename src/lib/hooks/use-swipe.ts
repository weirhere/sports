import { useRef, useCallback } from "react";

interface UseSwipeOptions {
  onSwipeLeft?: () => void;
  onSwipeRight?: () => void;
  /** Minimum horizontal distance in px to trigger a swipe (default: 50) */
  threshold?: number;
  /** Set to false to temporarily disable swipe detection */
  enabled?: boolean;
}

/**
 * Lightweight horizontal swipe detection using pointer events.
 * Returns a callback ref to attach to the swipeable container element.
 *
 * Uses pointer events (pointerdown/pointerup) so it works on both
 * touch devices and desktop (mouse drag).
 * Only fires when the gesture is primarily horizontal
 * (|deltaX| > threshold AND |deltaX| > |deltaY|).
 */
export function useSwipe<T extends HTMLElement = HTMLDivElement>({
  onSwipeLeft,
  onSwipeRight,
  threshold = 50,
  enabled = true,
}: UseSwipeOptions) {
  const startPos = useRef<{ x: number; y: number } | null>(null);
  const cleanupRef = useRef<(() => void) | null>(null);

  // Store latest values in refs so listeners always see current state
  const onSwipeLeftRef = useRef(onSwipeLeft);
  const onSwipeRightRef = useRef(onSwipeRight);
  const enabledRef = useRef(enabled);
  const thresholdRef = useRef(threshold);
  onSwipeLeftRef.current = onSwipeLeft;
  onSwipeRightRef.current = onSwipeRight;
  enabledRef.current = enabled;
  thresholdRef.current = threshold;

  // Callback ref — runs when the element mounts/unmounts
  const ref = useCallback((el: T | null) => {
    // Clean up previous listeners
    cleanupRef.current?.();
    cleanupRef.current = null;

    if (!el) return;

    function handlePointerDown(e: PointerEvent) {
      if (!enabledRef.current) return;
      startPos.current = { x: e.clientX, y: e.clientY };
    }

    function handlePointerUp(e: PointerEvent) {
      if (!enabledRef.current || !startPos.current) return;

      const deltaX = e.clientX - startPos.current.x;
      const deltaY = e.clientY - startPos.current.y;
      startPos.current = null;

      // Only trigger on primarily horizontal swipes
      if (
        Math.abs(deltaX) < thresholdRef.current ||
        Math.abs(deltaX) < Math.abs(deltaY)
      ) {
        return;
      }

      if (deltaX < 0) {
        onSwipeLeftRef.current?.();
      } else {
        onSwipeRightRef.current?.();
      }
    }

    el.addEventListener("pointerdown", handlePointerDown);
    el.addEventListener("pointerup", handlePointerUp);

    cleanupRef.current = () => {
      el.removeEventListener("pointerdown", handlePointerDown);
      el.removeEventListener("pointerup", handlePointerUp);
    };
  }, []);

  return { ref };
}
