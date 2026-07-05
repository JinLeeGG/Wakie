"use client";

import { useEffect, useRef, useState } from "react";
import { AnimatePresence, motion, useInView, useReducedMotion, type Variants } from "framer-motion";
import GlassPanel from "./GlassPanel";
import { OrbitMark } from "./Hero";

const EASE_WIN = [0.2, 0.85, 0.2, 1] as const;

const fadeUp: Variants = {
  hidden: { opacity: 0, y: 24 },
  show: { opacity: 1, y: 0, transition: { duration: 0.7, ease: EASE_WIN } },
};
const viewport = { once: true, margin: "-80px" } as const;

export default function Features() {
  return (
    <section id="features" className="relative w-full px-6 py-32 sm:py-40">
      <motion.div
        initial="hidden"
        whileInView="show"
        viewport={viewport}
        variants={{ hidden: {}, show: { transition: { staggerChildren: 0.12 } } }}
        className="mx-auto flex max-w-6xl flex-col items-center text-center"
      >
        <motion.span
          variants={fadeUp}
          className="font-mono text-[13px] uppercase tracking-[0.16em] text-amber"
        >
          The dashboard
        </motion.span>
        <motion.h2
          variants={fadeUp}
          className="mt-5 font-sans text-[clamp(2.5rem,5vw,3.75rem)] font-bold tracking-[-0.025em] text-t1"
        >
          Six accounts. One glance.
        </motion.h2>
        <motion.p variants={fadeUp} className="mt-6 text-[1.25rem] leading-relaxed text-t2">
          Never waste time hunting down your AI usage again.
        </motion.p>

        {/* the app window, floating over the page */}
        <motion.div
          variants={fadeUp}
          className="mt-16 w-full overflow-x-auto pb-2 [scrollbar-width:none]"
        >
          <DashboardPreview />
        </motion.div>


      </motion.div>
    </section>
  );
}

/* ── Dashboard replica ────────────────────────────────────────────────────────
   1:1 port of docs/design/dashboard-mockup.html (the shipping app's design
   canvas): summary pills, column header, six account rows with the real
   provider icons, and the footer with shortcuts + toggles. Static visual. */

type Tone = "ok" | "warn" | "crit";
const TONE: Record<Tone, { text: string; fill: string; glow: string }> = {
  ok: { text: "text-ok", fill: "#5fd39a", glow: "rgba(95,211,154,0.5)" },
  warn: { text: "text-warn", fill: "#ffbf5c", glow: "rgba(255,191,92,0.45)" },
  crit: { text: "text-crit", fill: "#ff7a85", glow: "rgba(255,122,133,0.5)" },
};

type MeterData = { pct: number; tone: Tone; reset: string } | null;
type Row = {
  icon: string;
  tile: string;
  name: string;
  tier: string;
  email: string;
  auto: boolean;
  current: MeterData;
  weekly: MeterData;
  status?: "fresh" | "low";
  quip: string; // header tagline shown while the demo highlight visits this row
};

const GREETING = "Good morning, John.";

const ROWS: Row[] = [
  { icon: "/icons/claude_app.png", tile: "#d97757", name: "Claude 1", tier: "PRO", email: "you@gmail.com", auto: true,
    current: { pct: 100, tone: "ok", reset: "5:39pm" }, weekly: { pct: 4, tone: "crit", reset: "Jul 7 (6:59am)" }, status: "fresh",
    quip: "Fresh window. Spend it well." },
  { icon: "/icons/claude_app.png", tile: "#d97757", name: "Claude 2", tier: "PRO", email: "work@gmail.com", auto: true,
    current: { pct: 100, tone: "ok", reset: "5:39pm" }, weekly: { pct: 3, tone: "crit", reset: "2h 51m" }, status: "fresh",
    quip: "Weekly resets in 2h 51m. Hang tight." },
  { icon: "/icons/claude_app.png", tile: "#d97757", name: "Claude 3", tier: "PRO", email: "side@gmail.com", auto: true,
    current: { pct: 18, tone: "crit", reset: "4:09pm" }, weekly: { pct: 91, tone: "ok", reset: "Jul 9 (1:59am)" }, status: "low",
    quip: "Claude 3 is running hot. Time to switch." },
  { icon: "/icons/codex_app.png", tile: "#edf1f7", name: "Codex 1", tier: "PLUS", email: "main@gmail.com", auto: true,
    current: { pct: 99, tone: "ok", reset: "7:07pm" }, weekly: { pct: 33, tone: "warn", reset: "Jul 6 (10:44pm)" }, status: "fresh",
    quip: "Codex 1 is basically untouched." },
  { icon: "/icons/codex_app.png", tile: "#edf1f7", name: "Codex 2", tier: "FREE", email: "free@gmail.com", auto: false,
    current: null, weekly: { pct: 95, tone: "ok", reset: "Aug 3 (2:07pm)" },
    quip: "Codex 2 is napping. Wake it anytime." },
  { icon: "/icons/antigravity_app.png", tile: "#1b1c21", name: "Antigravity 1", tier: "PRO", email: "anti@gmail.com", auto: false,
    current: { pct: 100, tone: "ok", reset: "—" }, weekly: { pct: 99, tone: "ok", reset: "Jul 7 (6:21am)" }, status: "fresh",
    quip: "Antigravity 1? Full tank." },
];

const SUMMARY = [
  { k: "Accounts", v: "6", amber: false, glyph: "plus" },
  { k: "Est. API value · 7d", v: "$34", amber: true },
  { k: "Resets in", v: "3h 31m", amber: false },
  { k: "Daily wake", v: "10:37am", amber: true, glyph: "chevron" },
] as const;

function DashboardPreview() {
  // immersive: once in view, a soft highlight walks the rows as if hovered
  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { margin: "-140px" });
  const reduce = useReducedMotion();
  const [active, setActive] = useState(-1);

  useEffect(() => {
    if (!inView || reduce) {
      setActive(-1);
      return;
    }
    const id = setInterval(() => setActive((a) => (a + 1) % ROWS.length), 3500);
    return () => clearInterval(id);
  }, [inView, reduce]);

  return (
    <GlassPanel ref={ref} className="pointer-events-none mx-auto w-full min-w-[900px] max-w-[1000px] select-none text-left">
      {/* header — tagline reacts to whichever row the demo highlight visits */}
      <div className="flex items-center justify-between gap-4 px-[26px] pb-[18px] pt-6">
        <div className="relative h-[31px] min-w-0 flex-1 overflow-hidden">
          <AnimatePresence mode="wait">
            <motion.div
              key={active >= 0 ? ROWS[active].quip : GREETING}
              initial={{ y: 16, opacity: 0 }}
              animate={{ y: 0, opacity: 1 }}
              exit={{ y: -16, opacity: 0 }}
              transition={{ duration: 0.26, ease: EASE_WIN }}
              className="truncate text-[28px] font-bold leading-[1.1] tracking-[-0.01em] text-t1"
            >
              {active >= 0 ? ROWS[active].quip : GREETING}
            </motion.div>
          </AnimatePresence>
        </div>
        <span className="flex flex-none items-center gap-[7px] rounded-full border border-hair bg-white/5 px-3 py-1.5 font-mono text-[12px] text-t2">
          <span className="h-1.5 w-1.5 rounded-full bg-ok shadow-[0_0_8px_rgba(95,211,154,0.7)]" />
          Updated just now
        </span>
      </div>

      {/* summary pills */}
      <div className="flex gap-[11px] px-[26px] pb-[14px]">
        {SUMMARY.map((s) => (
          <div
            key={s.k}
            className="flex-1 rounded-[14px] border border-hair bg-white/5 px-4 py-3"
          >
            <div className="font-mono text-[12.5px] font-medium uppercase tracking-[0.104em] text-t2">
              {s.k}
            </div>
            <div className="mt-1.5 flex items-center justify-between gap-2.5">
              <div
                className={`font-mono text-[22px] font-semibold tabular-nums ${s.amber ? "text-amber" : "text-t1"}`}
              >
                {s.v}
              </div>
              {"glyph" in s && s.glyph === "plus" && <SqIcon d="M12 5v14M5 12h14" />}
              {"glyph" in s && s.glyph === "chevron" && <SqIcon d="M7 10l5 5 5-5" />}
            </div>
          </div>
        ))}
      </div>

      {/* column header */}
      <div className="grid grid-cols-[300px_1fr_1fr_170px] items-center gap-4 px-7 pb-2 pt-0.5">
        <span className="flex items-center justify-between font-mono text-[12.5px] uppercase tracking-[0.104em] text-t3">
          <span>Account</span>
          <span>Auto</span>
        </span>
        <Colhead>Current</Colhead>
        <Colhead>Weekly</Colhead>
        <span className="text-right font-mono text-[12.5px] uppercase tracking-[0.104em] text-t3">
          Status
        </span>
      </div>

      {/* rows */}
      <div className="px-3.5 pb-2">
        {ROWS.map((r, i) => (
          <div
            key={r.name}
            className="relative isolate grid grid-cols-[300px_1fr_1fr_170px] items-center gap-4 rounded-[14px] px-3.5 py-2.5 [&+&]:mt-0.5"
          >
            {/* ONE shared highlight block that physically glides between rows
                (layoutId FLIP) — no fade-out/fade-in, it travels. */}
            {active === i && (
              <motion.div
                layoutId="rowHighlight"
                transition={{ type: "spring", stiffness: 380, damping: 36 }}
                className="absolute inset-0 -z-10 rounded-[14px] border border-hair bg-white/[0.055]"
              />
            )}
            {/* account cell */}
            <div className="flex min-w-0 items-center gap-3">
              <span
                className="grid h-[54px] w-[54px] flex-none place-items-center rounded-[14px] ring-1 ring-inset ring-white/10"
                style={{ background: r.tile }}
              >
                {/* eslint-disable-next-line @next/next/no-img-element */}
                <img src={r.icon} alt="" width={46} height={46} className="block" />
              </span>
              <div className="min-w-0 flex-1">
                <div className="flex min-w-0 items-baseline gap-2">
                  <span className="truncate text-[18px] font-semibold text-t1">{r.name}</span>
                  <span className="flex-none font-mono text-[10.5px] font-semibold tracking-[0.05em] text-amber">
                    {r.tier}
                  </span>
                </div>
                <div className="mt-0.5 truncate font-mono text-[11.5px] text-t3">{r.email}</div>
              </div>
              <Toggle on={r.auto} />
            </div>

            <Meter data={r.current} delay={0.15 + i * 0.1} />
            <Meter data={r.weekly} delay={0.25 + i * 0.1} />

            {/* status — melts away as the highlight arrives; buttons spring in
                once it has settled, and exit instantly when it leaves */}
            <div className="relative flex h-8 items-center justify-end">
              <motion.span
                animate={{ opacity: active === i ? 0 : 1 }}
                transition={{ duration: 0.2, ease: "easeOut" }}
                className="absolute right-0"
              >
                {r.status === "low" && (
                  <span className="flex items-center gap-1.5 font-mono text-[12px] font-medium text-crit">
                    <span className="h-1.5 w-1.5 rounded-full bg-crit shadow-[0_0_8px_rgba(255,122,133,0.6)]" />
                    Low
                  </span>
                )}
                {r.status === "fresh" && (
                  <span className="flex items-center gap-1.5 font-mono text-[12px] font-medium text-ok">
                    <span className="h-1.5 w-1.5 rounded-full bg-ok shadow-[0_0_8px_rgba(95,211,154,0.7)]" />
                    Fresh
                  </span>
                )}
              </motion.span>

              <AnimatePresence>
                {active === i && (
                  <motion.div
                    initial={{ opacity: 0, x: 10, scale: 0.97 }}
                    animate={{
                      opacity: 1,
                      x: 0,
                      scale: 1,
                      transition: { delay: 0.16, type: "spring", stiffness: 420, damping: 30 },
                    }}
                    exit={{ opacity: 0, x: 6, transition: { duration: 0.1, ease: "easeIn" } }}
                    className="absolute right-0 flex items-center gap-2"
                  >
                    <button
                      type="button"
                      className="whitespace-nowrap rounded-full border border-crit/25 bg-crit/[0.08] px-[13px] py-[7px] font-mono text-[12px] font-semibold leading-none text-crit transition-colors hover:border-crit/40 hover:bg-crit/[0.15]"
                    >
                      Remove
                    </button>
                    <button
                      type="button"
                      className="whitespace-nowrap rounded-full border border-amber/60 bg-amber px-[13px] py-[7px] font-mono text-[12px] font-semibold leading-none text-[#1a1205] transition-[filter] hover:brightness-105"
                    >
                      Update ↵
                    </button>
                  </motion.div>
                )}
              </AnimatePresence>
            </div>
          </div>
        ))}
      </div>

      {/* footer */}
      <div className="flex items-center justify-between border-t border-hair px-[26px] py-4">
        <div className="flex gap-[18px] font-mono text-[12px] text-t3">
          <span className="flex items-center">
            <Kbd>⌘R</Kbd>Refresh all
          </span>
          <span className="flex items-center">
            <Kbd>⌘N</Kbd>Add account
          </span>
        </div>
        <div className="flex items-center gap-5">
          <FootToggle label="Wake from sleep" />
          <FootToggle label="Launch at login" />
          <span className="flex items-center gap-1.5 font-mono text-[13.5px] text-t2">
            <OrbitMark className="h-4 w-4 text-amber" />
            <span>
              <span className="text-amber">W</span>
              <span className="text-t1">a</span>
              <span className="text-amber">k</span>
              <span className="text-t1">i</span>
              <span className="text-amber">e</span>
            </span>
            <span className="text-t3">1.0.0</span>
          </span>
        </div>
      </div>
    </GlassPanel>
  );
}

/* ── replica atoms ── */

function Colhead({ children }: { children: React.ReactNode }) {
  return (
    <span className="font-mono text-[12.5px] uppercase tracking-[0.104em] text-t3">
      {children}
    </span>
  );
}

function Meter({ data, delay = 0 }: { data: MeterData; delay?: number }) {
  if (!data) {
    return (
      <div>
        <div className="mb-1.5 flex items-baseline justify-between gap-2">
          <span className="font-mono text-[17px] font-semibold text-t3">—</span>
        </div>
        <div className="h-[5px] rounded-full bg-white/[0.06]" />
      </div>
    );
  }
  const t = TONE[data.tone];
  return (
    <div>
      <div className="mb-1.5 flex items-baseline justify-between gap-2">
        <span className={`whitespace-nowrap font-mono text-[17px] font-semibold tabular-nums ${t.text}`}>
          {data.pct}%<span className="ml-[5px] text-[11px] font-medium text-t3">left</span>
        </span>
        <span className="whitespace-nowrap font-mono text-[13.5px] tabular-nums text-t3">
          {data.reset}
        </span>
      </div>
      <div className="h-[5px] overflow-hidden rounded-full bg-white/[0.09]">
        {/* immersive: bars fill from zero when the panel scrolls into view */}
        <motion.div
          initial={{ width: "0%" }}
          whileInView={{ width: `${data.pct}%` }}
          viewport={{ once: true, margin: "-100px" }}
          transition={{ duration: 0.9, ease: EASE_WIN, delay }}
          className="h-full rounded-full"
          style={{
            background: t.fill,
            boxShadow: `0 0 12px ${t.glow}`,
          }}
        />
      </div>
    </div>
  );
}

function Toggle({ on }: { on: boolean }) {
  return (
    <span
      className={`relative h-[17px] w-[30px] flex-none rounded-full transition-colors ${on ? "bg-amber-deep" : "bg-white/[0.14]"}`}
    >
      <span
        className={`absolute left-0.5 top-0.5 h-[13px] w-[13px] rounded-full bg-white transition-transform ${on ? "translate-x-[13px]" : ""}`}
      />
    </span>
  );
}

function FootToggle({ label }: { label: string }) {
  return (
    <span className="hidden items-center gap-[9px] font-mono text-[12.5px] text-t3 lg:flex">
      <Toggle on />
      {label}
    </span>
  );
}

function Kbd({ children }: { children: React.ReactNode }) {
  return (
    <kbd className="mr-1.5 rounded-md border border-hair bg-white/5 px-2 py-0.5 font-mono text-[11.5px] text-t2">
      {children}
    </kbd>
  );
}

function SqIcon({ d }: { d: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className="h-5 w-5 text-t2" aria-hidden>
      <path d={d} stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
    </svg>
  );
}
