import { useRef, useCallback, useEffect } from "react";

interface UseSwipeOptions {
  onSwipeLeft?: () => void;
  onSwipeRight?: () => void;
  /** Minimum horizontal distance in px to trigger a swipe (default: 50) */
  threshold?: number;
  /** Set to false to temporarily disable swipe detection */
  enabled?: boolean;
}

/**
 * How far the pointer may travel before the gesture stops being a tap.
 *
 * This is the web's `SwipeSafeButtonStyle` (iOS, 2026-09-06). A browser
 * fires `click` whenever pointerdown and pointerup land on the same element,
 * however far the finger travelled in between — and a full-width game row is
 * *wider* than any swipe, so a day swipe that starts on a row commits the day
 * AND opens the game on the way out. That shipped on iOS in 2.0 for exactly
 * the same reason.
 *
 * Narrow controls need no guard: a swipe leaves their bounds, so the browser
 * cancels the click on its own.
 *
 * Deliberately looser than the swipe threshold — the click is swallowed for
 * any real drag, not only for one that changed the day, so an
 * under-threshold drag that snaps back doesn't open a game either.
 */
const TAP_TOLERANCE_PX = 10;

/**
 * Lightweight horizontal swipe detection using pointer events.
 * Returns a callback ref to attach to the swipeable container element.
 *
 * Uses pointer events (pointerdown/pointerup) so it works on both
 * touch devices and desktop (mouse drag).
 * Only fires when the gesture is primarily horizontal
 * (|deltaX| > threshold AND |deltaX| > |deltaY|).
 *
 * Vertical drags are never affected: the page's own scrolling claims those,
 * and the browser cancels the press.
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
  useEffect(() => {
    onSwipeLeftRef.current = onSwipeLeft;
    onSwipeRightRef.current = onSwipeRight;
    enabledRef.current = enabled;
    thresholdRef.current = threshold;
  });

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

    function swallowNextClick() {
      const onClick = (event: MouseEvent) => {
        event.preventDefault();
        event.stopPropagation();
      };
      // Capture phase, once: it has to run before the link's own handler,
      // and it must not outlive this gesture — a stuck listener would eat
      // the next real tap.
      el?.addEventListener("click", onClick, { capture: true, once: true });
      // A drag that ends outside any clickable child fires no click at all,
      // so the listener needs its own way out.
      setTimeout(() => {
        el?.removeEventListener("click", onClick, { capture: true });
      }, 0);
    }

    function handlePointerUp(e: PointerEvent) {
      if (!enabledRef.current || !startPos.current) return;

      const deltaX = e.clientX - startPos.current.x;
      const deltaY = e.clientY - startPos.current.y;
      startPos.current = null;

      // Anything past a tap's tolerance was a drag, whatever it committed.
      if (Math.abs(deltaX) > TAP_TOLERANCE_PX) swallowNextClick();

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

    function handlePointerCancel() {
      startPos.current = null;
    }

    el.addEventListener("pointerdown", handlePointerDown);
    el.addEventListener("pointerup", handlePointerUp);
    el.addEventListener("pointercancel", handlePointerCancel);

    cleanupRef.current = () => {
      el.removeEventListener("pointerdown", handlePointerDown);
      el.removeEventListener("pointerup", handlePointerUp);
      el.removeEventListener("pointercancel", handlePointerCancel);
    };
  }, []);

  return { ref };
}
