"use client";

import { useEffect, useRef, useState } from "react";
import { motion, useInView, useReducedMotion, type Variants } from "framer-motion";

const EASE_WIN = [0.2, 0.85, 0.2, 1] as const;
const fadeUp: Variants = {
  hidden: { opacity: 0, y: 24 },
  show: { opacity: 1, y: 0, transition: { duration: 0.7, ease: EASE_WIN } },
};
const viewport = { once: true, margin: "-80px" } as const;

export default function MorningAlarm() {
  return (
    <section id="wake" className="relative w-full px-6 py-24 sm:py-32">
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
            Wake schedule
          </motion.span>
          <motion.h2
            variants={fadeUp}
            className="mt-5 font-sans text-[clamp(2.5rem,5vw,3.75rem)] font-bold leading-[1.06] tracking-[-0.025em] text-t1"
          >
            Wake your AI
            <br />
            before you do.
          </motion.h2>
          <motion.p variants={fadeUp} className="mt-6 text-[1.25rem] leading-relaxed text-t2">
            Set a schedule. New sessions start automatically,
            <br className="hidden lg:block" /> even while your Mac sleeps.
          </motion.p>
        </div>

        {/* right — the app's daily-wake wheel picker, self-demonstrating */}
        <motion.div variants={fadeUp} className="flex justify-center lg:justify-end">
          {/* sized to visually match the Add-account modal next door (452px):
              248px × 1.35 ≈ 335px wide, similar height */}
          <div className="scale-[1.2] origin-center sm:scale-[1.35] lg:origin-right">
            <DailyWakeCard />
          </div>
        </motion.div>
      </motion.div>
    </section>
  );
}

/* ── Daily-wake wheel picker replica ──────────────────────────────────────────
   Port of the app's summary pill + wheel menu. Immersive: when scrolled into
   view it demos itself — the wheel spins 8:35 → 9:36 → 10:37, then the Set
   button presses. Clicking any number takes over and stops the demo. */

const ROW_H = 36;
const HOURS = [6, 7, 8, 9, 10, 11, 12, 13];
const MINS = [31, 32, 33, 34, 35, 36, 37, 38, 39, 40, 41];
// AM/PM is its own 2-item wheel: with AM selected, PM sits below — no ghost rows
const AP = ["", "", "AM", "PM", ""];

const spring = { type: "spring", stiffness: 160, damping: 24 } as const;

function DailyWakeCard() {
  const [open, setOpen] = useState(true);
  const [h, setH] = useState(8);
  const [m, setM] = useState(35);
  const [press, setPress] = useState(false);
  const [touched, setTouched] = useState(false);

  const ref = useRef<HTMLDivElement>(null);
  const inView = useInView(ref, { margin: "-120px" });
  const reduce = useReducedMotion();

  // self-demo loop: spin to 10:37, press Set, hold, repeat
  useEffect(() => {
    if (!inView || touched) return;
    if (reduce) {
      setH(10);
      setM(37);
      return;
    }
    let alive = true;
    const timers: ReturnType<typeof setTimeout>[] = [];
    const at = (ms: number, fn: () => void) =>
      timers.push(setTimeout(() => alive && fn(), ms));

    const run = () => {
      if (!alive) return;
      at(0, () => { setH(8); setM(35); });
      at(1000, () => { setH(9); setM(36); });
      at(1900, () => { setH(10); setM(37); });
      at(2900, () => setPress(true));
      at(3140, () => setPress(false));
      at(6600, run);
    };
    run();
    return () => {
      alive = false;
      timers.forEach(clearTimeout);
    };
  }, [inView, touched, reduce]);

  const fmt = `${h}:${String(m).padStart(2, "0")}am`;
  const yFor = (list: number[], v: number) => -(list.indexOf(v) - 2) * ROW_H;

  const pick = (setter: (v: number) => void) => (v: number) => {
    setTouched(true);
    setter(v);
  };

  return (
    <div ref={ref} className="pointer-events-none w-[248px] select-none">
      {/* summary pill */}
      <button
        type="button"
        onClick={() => { setTouched(true); setOpen(!open); }}
        className={`w-full rounded-[14px] border px-4 py-3 text-left transition-colors ${
          open ? "border-amber/45 bg-amber/[0.06]" : "border-hair bg-white/5"
        }`}
      >
        <div className="font-mono text-[12.5px] font-medium uppercase tracking-[0.104em] text-t2">
          Daily wake
        </div>
        <div className="mt-1.5 flex items-center justify-between gap-2.5">
          <span className="font-mono text-[22px] font-semibold tabular-nums text-amber">{fmt}</span>
          <svg
            viewBox="0 0 24 24"
            fill="none"
            className={`h-6 w-6 transition-transform duration-150 ${open ? "rotate-180 text-amber" : "text-t1"}`}
            aria-hidden
          >
            <path d="M7 10l5 5 5-5" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round" />
          </svg>
        </div>
      </button>

      {/* wheel menu */}
      {open && (
        <motion.div
          initial={{ opacity: 0, y: -6, scale: 0.98 }}
          animate={{ opacity: 1, y: 0, scale: 1 }}
          transition={{ duration: 0.22, ease: EASE_WIN }}
          className="mt-[9px] overflow-hidden rounded-[14px] border border-hair-2 bg-[rgb(18,20,28)] p-1.5 shadow-[0_26px_64px_-18px_rgba(0,0,0,0.8),inset_0_1px_0_rgba(255,255,255,0.12)]"
        >
          <div className="px-[9px] pb-2 pt-1.5 font-mono text-[12.5px] uppercase tracking-[0.104em] text-t2">
            Wake at
          </div>

          {/* wheel — 5 visible rows, real scrolling columns */}
          <div className="relative h-[180px] overflow-hidden px-1 font-mono text-[22px] font-semibold tabular-nums">
            {/* selection band — fixed on the middle row */}
            <div className="pointer-events-none absolute inset-x-1 top-[72px] z-10 h-9 rounded-[9px] border border-amber/20 bg-amber/[0.08]" />
            {/* fade masks top/bottom, like a real wheel */}
            <div className="pointer-events-none absolute inset-x-0 top-0 z-20 h-9 bg-gradient-to-b from-[rgb(18,20,28)] to-transparent" />
            <div className="pointer-events-none absolute inset-x-0 bottom-0 z-20 h-9 bg-gradient-to-t from-[rgb(18,20,28)] to-transparent" />

            <div className="grid h-full grid-cols-[1fr_14px_1fr_1fr]">
              {/* hours — scrolls */}
              <div className="overflow-hidden">
                <motion.div animate={{ y: yFor(HOURS, h) }} transition={spring}>
                  {HOURS.map((v) => (
                    <button
                      key={v}
                      type="button"
                      onClick={() => pick(setH)(v)}
                      className={`block h-9 w-full pr-[7px] text-right leading-9 transition-colors ${
                        v === h ? "text-amber" : "text-white/30 hover:text-white/60"
                      }`}
                    >
                      {v}
                    </button>
                  ))}
                </motion.div>
              </div>

              {/* separator — only at the selected row */}
              <div className="relative">
                <span className="absolute top-[72px] flex h-9 w-full items-center justify-center leading-9 text-t3">
                  :
                </span>
              </div>

              {/* minutes — scrolls */}
              <div className="overflow-hidden">
                <motion.div animate={{ y: yFor(MINS, m) }} transition={spring}>
                  {MINS.map((v) => (
                    <button
                      key={v}
                      type="button"
                      onClick={() => pick(setM)(v)}
                      className={`block h-9 w-full pl-[7px] text-left leading-9 transition-colors ${
                        v === m ? "text-amber" : "text-white/30 hover:text-white/60"
                      }`}
                    >
                      {String(v).padStart(2, "0")}
                    </button>
                  ))}
                </motion.div>
              </div>

              {/* AM/PM — static flanks, as in the app */}
              <div>
                {AP.map((label, i) => (
                  <span
                    key={i}
                    className={`flex h-9 items-center justify-center leading-9 ${
                      i === 2 ? "text-amber" : "text-white/30"
                    }`}
                  >
                    {label}
                  </span>
                ))}
              </div>
            </div>
          </div>

          {/* set button — presses itself at the end of the demo */}
          <motion.button
            type="button"
            animate={{ scale: press ? 0.93 : 1, filter: press ? "brightness(1.15)" : "brightness(1)" }}
            transition={{ duration: 0.12, ease: EASE_WIN }}
            onClick={() => setTouched(true)}
            className="mx-[3px] mt-2.5 block w-[calc(100%-6px)] rounded-[10px] border border-amber/60 bg-amber p-[9px] font-mono text-[16px] font-semibold text-[#1a1205]"
          >
            Set {fmt}
          </motion.button>

          {/* note */}
          <div className="mx-[3px] mt-1.5 border-t border-hair px-1.5 pb-1 pt-[9px] font-sans text-[11.5px] leading-[1.45] text-t3">
            Your Mac wakes at this time each day to{" "}
            <b className="font-semibold text-amber">start any due sessions</b> — and refresh
            status.
          </div>
        </motion.div>
      )}
    </div>
  );
}
