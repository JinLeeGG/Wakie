"use client";

import { useEffect, useRef, useState } from "react";
import { motion, useInView, useReducedMotion, type Variants } from "framer-motion";

const EASE_WIN = [0.2, 0.85, 0.2, 1] as const;

const fadeUp: Variants = {
  hidden: { opacity: 0, y: 24 },
  show: { opacity: 1, y: 0, transition: { duration: 0.7, ease: EASE_WIN } },
};
const viewport = { once: true, margin: "-80px" } as const;

/* The audit readout — the whole security story told the way a developer
   would actually verify it. Syntax-highlighted: keys muted, good states
   green, the headline number amber. */
const CMD = "wakie audit --network";
const AUDIT: [string, string, string][] = [
  ["outbound connections", "0 bytes", "font-semibold text-amber"],
  ["credentials", "keychain · local", "text-ok"],
  ["prompts stored", "none", "text-ok"],
  ["cloud sync", "—", "text-t3"],
  ["binaries", "official CLIs only", "text-ok"],
];

const lineIn: Variants = {
  hidden: { opacity: 0, y: 6 },
  show: { opacity: 1, y: 0, transition: { duration: 0.35, ease: EASE_WIN } },
};

export default function Security() {
  const termRef = useRef<HTMLDivElement>(null);
  const inView = useInView(termRef, { once: true, margin: "-100px" });
  const reduce = useReducedMotion();

  const [typedLen, setTypedLen] = useState(0);
  const [done, setDone] = useState(false);

  // type the command, then reveal the readout line by line
  useEffect(() => {
    if (!inView) return;
    if (reduce) {
      setTypedLen(CMD.length);
      setDone(true);
      return;
    }
    let i = 0;
    const id = setInterval(() => {
      i += 1;
      setTypedLen(i);
      if (i >= CMD.length) {
        clearInterval(id);
        setTimeout(() => setDone(true), 300);
      }
    }, 42);
    return () => clearInterval(id);
  }, [inView, reduce]);

  return (
    <section id="security" className="relative w-full px-4 py-20 sm:px-6 sm:py-32 md:py-40">
      <motion.div
        initial="hidden"
        whileInView="show"
        viewport={viewport}
        variants={{ hidden: {}, show: { transition: { staggerChildren: 0.14 } } }}
        className="mx-auto flex max-w-4xl flex-col items-center text-center"
      >
        <motion.span
          variants={fadeUp}
          className="font-mono text-[13px] uppercase tracking-[0.16em] text-amber"
        >
          Security
        </motion.span>

        {/* massive type — the section IS the typography */}
        <motion.h2
          variants={fadeUp}
          className="mt-5 font-sans text-[clamp(2rem,6vw,4.5rem)] font-bold leading-[1.04] tracking-[-0.03em] text-t1"
        >
          No login.
          <br />
          100% <span className="text-amber">local</span>.
        </motion.h2>

        <motion.p variants={fadeUp} className="mt-4 text-lg text-t2 md:mt-6 md:text-xl">
          Your credentials never leave your Mac.
        </motion.p>

        {/* proof, not promises: a quiet terminal audit that runs itself */}
        <motion.div variants={fadeUp} className="mt-10 w-full max-w-2xl md:mt-16">
          <div
            ref={termRef}
            className="overflow-hidden rounded-2xl border border-hair-2 bg-white/[0.02] text-left shadow-[0_0_50px_rgba(255,196,101,0.06),0_30px_80px_-24px_rgba(0,0,0,0.7),inset_0_1px_0_rgba(255,255,255,0.08)] backdrop-blur-xl"
          >
            {/* title bar */}
            <div className="flex items-center gap-2 border-b border-hair bg-white/[0.015] px-4 py-3">
              <span className="h-[11px] w-[11px] rounded-full bg-[#ff5f57]/60" />
              <span className="h-[11px] w-[11px] rounded-full bg-[#febc2e]/60" />
              <span className="h-[11px] w-[11px] rounded-full bg-[#28c840]/60" />
              <span className="ml-3 font-mono text-[11.5px] text-t3">wakie — audit — 80×14</span>
            </div>

            {/* body */}
            <div className="px-4 py-4 font-mono text-[12.5px] leading-[2] sm:px-5 sm:py-5 sm:text-[14px]">
              {/* typed command */}
              <div className="text-t1">
                <span className="text-amber">$</span> {CMD.slice(0, typedLen)}
                {!done && (
                  <span className="ml-px inline-block h-[14px] w-[8px] translate-y-[2px] animate-pulse bg-amber/70" />
                )}
              </div>

              {/* readout — reveals line by line once typing finishes */}
              <motion.div
                initial="hidden"
                animate={done ? "show" : "hidden"}
                variants={{ hidden: {}, show: { transition: { staggerChildren: 0.14, delayChildren: 0.1 } } }}
                className="mt-2"
              >
                {AUDIT.map(([k, v, cls]) => (
                  <motion.div key={k} variants={lineIn} className="flex items-baseline gap-3">
                    <span className="whitespace-nowrap text-t3">{k}</span>
                    <span className="mb-[6px] min-w-4 flex-1 border-b border-dotted border-white/10" />
                    <span className={`whitespace-nowrap tabular-nums ${cls}`}>{v}</span>
                  </motion.div>
                ))}

                <motion.div variants={lineIn} className="mt-3 flex items-center gap-2 text-ok">
                  <span>✓</span>
                  <span>nothing leaves this Mac</span>
                </motion.div>

                <motion.div variants={lineIn} className="mt-1 flex items-center text-t3">
                  <span className="text-amber">$</span>
                  <span className="ml-2 inline-block h-[15px] w-[8px] animate-pulse bg-amber/70" />
                </motion.div>
              </motion.div>
            </div>
          </div>
        </motion.div>
      </motion.div>
    </section>
  );
}
