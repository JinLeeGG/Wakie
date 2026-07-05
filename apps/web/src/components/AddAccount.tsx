"use client";

import { useEffect, useRef, useState } from "react";
import { motion, useInView, useReducedMotion, type Variants } from "framer-motion";
import GlassPanel from "./GlassPanel";

const EASE_WIN = [0.2, 0.85, 0.2, 1] as const;
const fadeUp: Variants = {
  hidden: { opacity: 0, y: 24 },
  show: { opacity: 1, y: 0, transition: { duration: 0.7, ease: EASE_WIN } },
};
const viewport = { once: true, margin: "-80px" } as const;

export default function AddAccount() {
  return (
    <section className="relative w-full px-6 py-24 sm:py-32">
      <motion.div
        initial="hidden"
        whileInView="show"
        viewport={viewport}
        variants={{ hidden: {}, show: { transition: { staggerChildren: 0.12 } } }}
        className="mx-auto grid max-w-6xl items-center gap-14 lg:grid-cols-2 lg:gap-20"
      >
        {/* left — copy */}
        <div className="text-center lg:text-left">
          <motion.span
            variants={fadeUp}
            className="font-mono text-[13px] uppercase tracking-[0.16em] text-amber"
          >
            Multi-account
          </motion.span>
          <motion.h2
            variants={fadeUp}
            className="mt-5 font-sans text-[clamp(2.5rem,5vw,3.75rem)] font-bold leading-[1.06] tracking-[-0.025em] text-t1"
          >
            Bring them all.
            <br />
            Track them together.
          </motion.h2>
          <motion.p variants={fadeUp} className="mt-6 text-[1.25rem] leading-relaxed text-t2">
            Add multiple AI accounts and
            <br className="hidden lg:block" /> monitor usage from a single view.
          </motion.p>
        </div>

        {/* right — the app's add-account modal, self-demonstrating */}
        <motion.div variants={fadeUp} className="flex justify-center lg:justify-end">
          <AddAccountCard />
        </motion.div>
      </motion.div>
    </section>
  );
}

/* ── Add-account modal replica ────────────────────────────────────────────────
   Port of docs/design/add-account.html (mirrors add_account_modal.dart).
   Immersive: in view, it demos itself — cycling providers while typing a
   matching label, with the CTA flipping browser ↔ Terminal. Any click takes
   over and stops the demo. */

type Provider = {
  id: string;
  name: string;
  icon: string;
  tile: string;
  terminal: boolean;
  demoLabel: string;
};

const PROVIDERS: Provider[] = [
  { id: "claude", name: "Claude", icon: "/icons/claude_app.png", tile: "#d97757", terminal: false, demoLabel: "Personal" },
  { id: "codex", name: "Codex", icon: "/icons/codex_app.png", tile: "#edf1f7", terminal: false, demoLabel: "Work" },
  { id: "anti", name: "Antigravity", icon: "/icons/antigravity_app.png", tile: "#1b1c21", terminal: true, demoLabel: "main" },
];

function AddAccountCard() {
  const [sel, setSel] = useState("claude");
  const [typed, setTyped] = useState("");
  const [touched, setTouched] = useState(false);

  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { margin: "-120px" });
  const reduce = useReducedMotion();

  // self-demo: select the next provider, then type its label
  useEffect(() => {
    if (!inView || touched || reduce) return;
    let alive = true;
    let idx = 0;
    const timers: ReturnType<typeof setTimeout>[] = [];
    const at = (ms: number, fn: () => void) =>
      timers.push(setTimeout(() => alive && fn(), ms));

    const cycle = () => {
      if (!alive) return;
      const cur = PROVIDERS[idx];
      setSel(cur.id);
      setTyped("");
      cur.demoLabel.split("").forEach((_, i) =>
        at(420 + i * 75, () => setTyped(cur.demoLabel.slice(0, i + 1))),
      );
      idx = (idx + 1) % PROVIDERS.length;
      at(3000, cycle);
    };
    cycle();
    return () => {
      alive = false;
      timers.forEach(clearTimeout);
    };
  }, [inView, touched, reduce]);

  const viaTerminal = PROVIDERS.find((p) => p.id === sel)?.terminal ?? false;

  return (
    <GlassPanel ref={ref} variant="solid" className="pointer-events-none w-[452px] max-w-full select-none">
      {/* header */}
      <div className="flex items-center py-5 pl-[22px] pr-4">
        <svg viewBox="0 0 100 100" className="h-5 w-5 flex-none" aria-hidden>
          <circle cx="50" cy="50" r="38" fill="none" stroke="#fff" strokeWidth="7" />
          <circle cx="50" cy="50" r="22" fill="#f6b23c" />
        </svg>
        <span className="ml-[11px] text-[19px] font-semibold text-t1">Add account</span>
        <span className="ml-auto grid h-[37px] w-[37px] cursor-pointer place-items-center rounded-[9px] text-t2 transition-colors hover:bg-white/5 hover:text-t1">
          <svg viewBox="0 0 24 24" fill="none" className="h-[19px] w-[19px]" aria-hidden>
            <path d="M6 6l12 12M18 6L6 18" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" />
          </svg>
        </span>
      </div>

      <div className="px-[22px] pb-[22px] pt-1">
        <Lab3 className="pt-4">Provider</Lab3>

        {PROVIDERS.map((p) => {
          const isSel = sel === p.id;
          return (
            <button
              key={p.id}
              type="button"
              onClick={() => { setTouched(true); setSel(p.id); }}
              className={`flex w-full items-center gap-[13px] rounded-xl border p-[13px] py-3 text-left transition-colors duration-300 [&+&]:mt-[11px] ${
                isSel
                  ? "border-amber/45 bg-amber/[0.07]"
                  : "border-hair bg-white/[0.03] hover:bg-white/[0.055]"
              }`}
            >
              <span
                className="grid h-[54px] w-[54px] flex-none place-items-center overflow-hidden rounded-[14px] ring-1 ring-inset ring-white/10"
                style={{ background: p.tile }}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={p.icon} alt="" width={46} height={46} className="block" />
              </span>
              <span className="text-[16px] font-semibold text-t1">{p.name}</span>
              <span
                className={`ml-auto grid h-[18px] w-[18px] flex-none place-items-center rounded-full border-[1.5px] transition-colors duration-300 ${
                  isSel ? "border-amber" : "border-hair-2"
                }`}
              >
                <span
                  className={`h-[9px] w-[9px] rounded-full bg-amber transition-transform duration-200 [transition-timing-function:cubic-bezier(.2,1.4,.4,1)] ${
                    isSel ? "scale-100" : "scale-0"
                  }`}
                />
              </span>
            </button>
          );
        })}

        <Lab3 className="pt-5">Label</Lab3>
        {/* field — self-typing during the demo, amber caret */}
        <div
          className="cursor-text rounded-xl border border-hair bg-white/[0.03] px-3.5 py-[3px]"
          onClick={() => setTouched(true)}
        >
          <div className="flex h-[41px] items-center font-sans text-[15.5px]">
            {typed ? (
              <span className="text-t1">{typed}</span>
            ) : (
              <span className="text-t3">e.g. Personal, Work, main</span>
            )}
            <span className="ml-px inline-block h-[18px] w-[1.5px] animate-pulse bg-amber" />
          </div>
        </div>

        <div className="flex items-start gap-[9px] px-0.5 pb-1 pt-4">
          <span className="flex-none text-[13px] leading-normal">🔒</span>
          <p className="text-[13px] leading-normal text-t2">
            Sign-in completes in{" "}
            <b className="font-medium text-t1">{viaTerminal ? "Terminal" : "your browser"} on this Mac</b>.
            Each account gets an <b className="font-medium text-t1">isolated slot</b>, and
            credentials stay on this Mac only.
          </p>
        </div>

        <motion.button
          type="button"
          whileHover={{ y: -1, filter: "brightness(1.05)" }}
          whileTap={{ scale: 0.98 }}
          className="mt-[26px] flex w-full items-center justify-center gap-[9px] rounded-[13px] border border-amber/60 bg-amber p-3.5 font-sans text-[16px] font-bold text-[#1a1205]"
        >
          Sign in with {viaTerminal ? "Terminal" : "browser"}
          <svg viewBox="0 0 24 24" fill="none" className="h-[17px] w-[17px]" aria-hidden>
            <path d="M5 12h13M13 6l6 6-6 6" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </motion.button>
      </div>
    </GlassPanel>
  );
}

function Lab3({ children, className = "" }: { children: React.ReactNode; className?: string }) {
  return (
    <div
      className={`px-0.5 pb-[11px] font-mono text-[10.5px] font-medium uppercase tracking-[0.14em] text-t3 ${className}`}
    >
      {children}
    </div>
  );
}
