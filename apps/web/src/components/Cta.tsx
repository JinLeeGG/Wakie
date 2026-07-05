"use client";

import { useState } from "react";
import { motion, type Variants } from "framer-motion";
import { PrimaryCta, DownloadIcon } from "./Hero";

const EASE_WIN = [0.2, 0.85, 0.2, 1] as const;

const fadeUp: Variants = {
  hidden: { opacity: 0, y: 24 },
  show: { opacity: 1, y: 0, transition: { duration: 0.7, ease: EASE_WIN } },
};
const viewport = { once: true, margin: "-100px" } as const;

/* Final CTA — no cards, no panels. Three elements floating on the cosmos,
   top to bottom: massive type → one-line install command → download button. */

export default function Cta() {
  return (
    <section
      id="download"
      className="relative w-full overflow-hidden px-6 pb-28 pt-32 sm:pt-40"
    >
      {/* faint amber ambience behind the whole moment — light, not a surface */}
      <div
        aria-hidden
        className="pointer-events-none absolute inset-x-0 top-1/4 -z-10 h-1/2 bg-[radial-gradient(50%_60%_at_50%_50%,rgba(255,196,101,0.06),transparent_70%)]"
      />

      <div className="flex flex-col items-center justify-center text-center">
        {/* 1 — the massive type, first and dominant */}
        <motion.h2
          initial={{ opacity: 0, y: 80, scale: 0.95 }}
          whileInView={{ opacity: 1, y: 0, scale: 1 }}
          viewport={viewport}
          transition={{ duration: 1.1, ease: EASE_WIN }}
          className="w-full select-none whitespace-nowrap text-center font-sans text-[10.5vw] font-bold leading-[0.95] tracking-tighter"
        >
          <span className="bg-gradient-to-b from-[#f8f9fc] via-[#eef1f6] to-[#98a0b0] bg-clip-text text-transparent">
            Start{" "}
          </span>
          <span className="bg-gradient-to-b from-[#ffd79a] via-amber to-amber-deep bg-clip-text text-transparent">
            TokenMaxxing
          </span>
        </motion.h2>

        {/* 2 — install line + download button, side by side */}
        <motion.div
          initial="hidden"
          whileInView="show"
          viewport={viewport}
          variants={{ hidden: {}, show: { transition: { staggerChildren: 0.14, delayChildren: 0.25 } } }}
          className="mt-20 flex flex-col items-center justify-center gap-4 sm:mt-28 sm:flex-row sm:gap-5"
        >
          <motion.div variants={fadeUp}>
            <InstallLine />
          </motion.div>

          <motion.div variants={fadeUp}>
            <PrimaryCta href="#download">
              <DownloadIcon className="h-[18px] w-[18px]" />
              Download for Mac
            </PrimaryCta>
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}

/* ── One-line install command ─────────────────────────────────────────────────
   A single thin inline code pill with a copy icon. No chrome, no tabs. */

const CMD = "curl -sS https://get.wakie.ai | sh";

function InstallLine() {
  const [copied, setCopied] = useState(false);

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(CMD);
    } catch {
      /* clipboard unavailable — the visual feedback still confirms intent */
    }
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  };

  return (
    <div className="flex h-[52px] items-center gap-3 rounded-full border border-hair-2 bg-white/[0.02] pl-6 pr-4 backdrop-blur-sm">
      <code className="whitespace-nowrap font-mono text-[14px] leading-none">
        <span className="text-amber">$ </span>
        <span className="text-t1">curl </span>
        <span className="text-t3">-sS </span>
        <span className="text-t2">https://get.wakie.ai </span>
        <span className="text-t3">| </span>
        <span className="text-t1">sh</span>
      </code>

      <button
        type="button"
        onClick={copy}
        aria-label="Copy command"
        className="grid h-8 w-8 flex-none place-items-center rounded-full text-t3 transition-colors hover:bg-white/[0.05] hover:text-t1"
      >
        {copied ? (
          <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4 text-ok" aria-hidden>
            <path d="M4.5 12.5l5 5 10-11" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        ) : (
          <svg viewBox="0 0 24 24" fill="none" className="h-4 w-4" aria-hidden>
            <rect x="9" y="9" width="11" height="11" rx="2.5" stroke="currentColor" strokeWidth="1.7" />
            <path d="M5.5 14.5A2.5 2.5 0 014 12.2V6.5A2.5 2.5 0 016.5 4h5.7a2.5 2.5 0 012.3 1.5" stroke="currentColor" strokeWidth="1.7" strokeLinecap="round" />
          </svg>
        )}
      </button>
    </div>
  );
}
