"use client";

import { useState } from "react";
import { motion, type Variants } from "framer-motion";
import { PrimaryCta, DownloadIcon, GitHubIcon, REPO_URL, RELEASES_URL } from "./Hero";

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

        {/* 2 — install (brew / curl) → download + GitHub */}
        <motion.div
          initial="hidden"
          whileInView="show"
          viewport={viewport}
          variants={{ hidden: {}, show: { transition: { staggerChildren: 0.14, delayChildren: 0.25 } } }}
          className="mt-20 flex w-full flex-col items-center gap-7 sm:mt-28"
        >
          <motion.div variants={fadeUp} className="w-full">
            <InstallBlock />
          </motion.div>

          <motion.div
            variants={fadeUp}
            className="flex flex-col items-center gap-3.5 sm:flex-row sm:gap-4"
          >
            <PrimaryCta href={RELEASES_URL} target="_blank" rel="noopener noreferrer">
              <DownloadIcon className="h-[18px] w-[18px]" />
              Download for Mac
            </PrimaryCta>

            <a
              href={REPO_URL}
              target="_blank"
              rel="noopener noreferrer"
              className="group inline-flex h-[52px] items-center gap-2.5 rounded-full border border-hair-2 bg-white/[0.03] px-7 font-sans text-[15px] font-semibold text-t1 backdrop-blur-sm transition-colors hover:border-amber/50 hover:bg-amber/[0.06]"
            >
              <GitHubIcon className="h-[18px] w-[18px] text-t2 transition-colors group-hover:text-t1" />
              View on GitHub
            </a>
          </motion.div>
        </motion.div>
      </div>
    </section>
  );
}

/* ── Install commands — Homebrew / curl, copy-to-clipboard ─────────────────────
   A segmented toggle over a single code pill. brew is the clean default; curl
   is the no-Homebrew fallback (long, so the pill scrolls rather than wraps). */

const INSTALLS = {
  brew: "brew install --cask jinleegg/wakie/wakie",
  curl: "curl -fsSL https://raw.githubusercontent.com/JinLeeGG/Wakie/main/deploy/install.sh | bash",
} as const;
type InstallTab = keyof typeof INSTALLS;

function InstallBlock() {
  const [tab, setTab] = useState<InstallTab>("brew");
  const [copied, setCopied] = useState(false);
  const cmd = INSTALLS[tab];

  const copy = async () => {
    try {
      await navigator.clipboard.writeText(cmd);
    } catch {
      /* clipboard unavailable — the visual feedback still confirms intent */
    }
    setCopied(true);
    setTimeout(() => setCopied(false), 1600);
  };

  return (
    <div className="mx-auto flex w-full max-w-[min(90vw,640px)] flex-col items-center gap-3">
      {/* segmented toggle */}
      <div className="flex items-center gap-1 rounded-full border border-hair bg-white/[0.02] p-1 font-sans text-[13px] font-semibold backdrop-blur-sm">
        {(Object.keys(INSTALLS) as InstallTab[]).map((t) => (
          <button
            key={t}
            type="button"
            onClick={() => {
              setTab(t);
              setCopied(false);
            }}
            className={`rounded-full px-4 py-1.5 transition-colors ${
              tab === t ? "bg-amber text-[#0a0c12]" : "text-t2 hover:text-t1"
            }`}
          >
            {t === "brew" ? "Homebrew" : "curl"}
          </button>
        ))}
      </div>

      {/* command pill */}
      <div className="flex h-[52px] w-full items-center gap-3 rounded-full border border-hair-2 bg-white/[0.02] pl-6 pr-3 backdrop-blur-sm">
        <code className="flex-1 overflow-x-auto whitespace-nowrap font-mono text-[13.5px] leading-none [scrollbar-width:none] [&::-webkit-scrollbar]:hidden">
          <span className="text-amber">$ </span>
          <span className="text-t1">{cmd}</span>
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
    </div>
  );
}
