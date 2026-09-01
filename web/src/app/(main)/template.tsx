"use client";

import { motion, useReducedMotion } from "framer-motion";

export default function MainTemplate({
  children,
}: {
  children: React.ReactNode;
}) {
  // Reduced motion flattens the entrance to a jump cut — framer-motion
  // animates inline styles, so the global CSS kill can't reach it.
  const reducedMotion = useReducedMotion();
  return (
    <motion.div
      initial={reducedMotion ? false : { opacity: 0, y: 8 }}
      animate={{ opacity: 1, y: 0 }}
      transition={
        reducedMotion
          ? { duration: 0 }
          : { duration: 0.25, ease: "easeOut" }
      }
    >
      {children}
    </motion.div>
  );
}
