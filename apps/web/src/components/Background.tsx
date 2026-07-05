"use client";

import { motion, useReducedMotion } from "framer-motion";

/* Page-level ambient background. Lives OUTSIDE the sections as a fixed layer,
   so the aurora glow, dust and vignette flow seamlessly across section
   boundaries (no clipped-blob seam lines). Bottom → top:
   aurora blobs → star dust → vignette → film grain. */

/* Static star dust — tiny points, weighted toward the top half. Alphas are
   capped at 0.15: the layer is fixed, so anything brighter reads as monitor
   smudge while content scrolls past it. */
const DUST = [
  ["14%", "18%", 0.15], ["78%", "12%", 0.13], ["32%", "9%", 0.11],
  ["88%", "34%", 0.13], ["7%", "42%", 0.11], ["62%", "22%", 0.15],
  ["47%", "6%", 0.11], ["93%", "58%", 0.09], ["22%", "64%", 0.09],
  ["70%", "72%", 0.11], ["38%", "83%", 0.09], ["84%", "88%", 0.11],
  ["11%", "77%", 0.09], ["55%", "48%", 0.09],
] as const;

const dustImage = DUST.map(
  ([x, y, a]) => `radial-gradient(1.5px 1.5px at ${x} ${y}, rgba(235,240,250,${a}), transparent 100%)`,
).join(",");

/* Film grain — inline SVG turbulence, kills banding on the dark gradients. */
const GRAIN =
  "url(\"data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='140' height='140'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.9' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E\")";

export default function Background() {
  const reduce = useReducedMotion();

  return (
    <div aria-hidden className="pointer-events-none fixed inset-0 -z-10 overflow-hidden">
      {/* aurora blobs */}
      <div className="absolute inset-0 flex items-center justify-center opacity-80 mix-blend-screen">
        <motion.div
          className="absolute h-[650px] w-[800px] rounded-[100%] bg-[rgba(90,30,190,0.28)] blur-[120px]"
          animate={
            reduce
              ? undefined
              : { x: [-60, 40, -60], y: [-30, 40, -30], scale: [1, 1.15, 1], rotate: [0, 45, 0] }
          }
          transition={{ duration: 22, repeat: Infinity, ease: "easeInOut" }}
        />
        <motion.div
          className="absolute h-[550px] w-[700px] rounded-[100%] bg-[rgba(255,196,101,0.16)] blur-[100px]"
          animate={
            reduce
              ? undefined
              : { x: [50, -50, 50], y: [40, -20, 40], scale: [1, 1.2, 1], rotate: [0, -30, 0] }
          }
          transition={{ duration: 28, repeat: Infinity, ease: "easeInOut" }}
        />
        <motion.div
          className="absolute h-[700px] w-[600px] rounded-[100%] bg-[rgba(30,60,180,0.26)] blur-[140px]"
          animate={
            reduce
              ? undefined
              : { x: [30, -30, 30], y: [-50, 30, -50], scale: [1.1, 0.9, 1.1], rotate: [-20, 20, -20] }
          }
          transition={{ duration: 25, repeat: Infinity, ease: "easeInOut" }}
        />
      </div>

      {/* star dust */}
      <div className="absolute inset-0" style={{ backgroundImage: dustImage }} />

      {/* vignette — keeps copy on quiet space, now viewport-fixed (no seams) */}
      <div className="absolute inset-0 bg-[radial-gradient(ellipse_70%_55%_at_50%_42%,transparent,rgba(5,6,11,0.6))]" />

      {/* film grain */}
      <div
        className="absolute inset-0 opacity-[0.05]"
        style={{ backgroundImage: GRAIN, backgroundSize: "140px 140px" }}
      />
    </div>
  );
}
