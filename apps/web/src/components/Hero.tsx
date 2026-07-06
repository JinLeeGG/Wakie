"use client";

import { useEffect, useState, useRef } from "react";
import { motion, type Variants } from "framer-motion";

/* Signature easings, mirrored from theme.dart / the mockups. */
const EASE_WIN = [0.2, 0.85, 0.2, 1] as const;
const EASE_LIFT = [0.2, 0.8, 0.2, 1] as const;

/* Canonical outbound links. */
export const REPO_URL = "https://github.com/JinLeeGG/Wakie";
export const RELEASES_URL = `${REPO_URL}/releases/latest`;

/* Centered content: staggered fade-up. */
const stagger: Variants = {
  hidden: {},
  show: { transition: { staggerChildren: 0.1, delayChildren: 0.25 } },
};
const fadeUp: Variants = {
  hidden: { opacity: 0, y: 18 },
  show: { opacity: 1, y: 0, transition: { duration: 0.7, ease: EASE_WIN } },
};

export default function Hero() {
  return (
    <>
      <Nav />

      {/* ambient background (aurora/vignette/grain) is page-level: <Background /> */}
      <section className="relative flex min-h-screen w-full items-center justify-center overflow-hidden px-6">
        {/* ── centered copy ─────────────────────────────────────────── */}
        <motion.div
          variants={stagger}
          initial="hidden"
          animate="show"
          className="relative z-10 flex max-w-6xl flex-col items-center text-center"
        >
          {/* brand lockup — "Wakie" amber, "AI" white (standing rule).
              Antigravity ratio: lockup ≈ 0.3× the headline; icon scales via em. */}
          <motion.div
            variants={fadeUp}
            className="mb-12 flex items-center gap-[0.3em] text-[clamp(1.25rem,2.8vw,2.4rem)]"
          >
            <OrbitMark className="h-[1.2em] w-[1.2em]" />
            <span className="font-sans font-semibold tracking-tight">
              <span className="text-amber">W</span>
              <span className="text-t1">a</span>
              <span className="text-amber">k</span>
              <span className="text-t1">i</span>
              <span className="text-amber">e</span>
            </span>
          </motion.div>

          <motion.h1
            variants={fadeUp}
            className="font-sans text-[clamp(2.25rem,6.2vw,5.5rem)] font-bold leading-[1.06] tracking-[-0.03em] text-t1"
          >
            <span className="whitespace-nowrap">All your AI subscriptions.</span>
            <br />
            <span className="text-t1">
              Always <span className="text-amber">awake</span>.
            </span>
          </motion.h1>

          <motion.div
            variants={fadeUp}
            className="mt-20 flex flex-col items-center gap-3.5 sm:flex-row"
          >
            <PrimaryCta href="#download">
              <DownloadIcon className="h-[18px] w-[18px]" />
              Download for Mac
            </PrimaryCta>

          </motion.div>

        </motion.div>
      </section>
    </>
  );
}

/* ── CTA buttons — coordinated halo glow + shimmer sweep + scale ────────────── */

export function PrimaryCta({
  href,
  children,
  target,
  rel,
}: {
  href: string;
  children: React.ReactNode;
  target?: string;
  rel?: string;
}) {
  return (
    <motion.a
      href={href}
      target={target}
      rel={rel}
      initial="rest"
      whileHover="hover"
      whileTap="tap"
      variants={{ rest: { scale: 1 }, hover: { scale: 1.04 }, tap: { scale: 0.96 } }}
      transition={{ duration: 0.25, ease: EASE_LIFT }}
      className="group relative inline-flex h-[52px] items-center gap-2 rounded-full bg-amber px-8 font-sans text-[16px] font-semibold text-[#0a0c12] shadow-[0_4px_14px_-6px_rgba(246,178,60,0.4)]"
    >
      <motion.span
        aria-hidden
        className="pointer-events-none absolute -inset-1 -z-10 rounded-full bg-amber blur-lg"
        variants={{
          rest: { opacity: 0.06, scale: 0.9 },
          hover: { opacity: 0.4, scale: 1.08 },
        }}
        transition={{ duration: 0.3, ease: EASE_LIFT }}
      />
      <span
        aria-hidden
        className="pointer-events-none absolute inset-0 overflow-hidden rounded-full"
      >
        <motion.span
          className="absolute inset-y-0 left-0 w-1/3 -skew-x-12 bg-white/55 blur-md"
          variants={{ rest: { x: "-180%" }, hover: { x: "460%" } }}
          transition={{ duration: 0.75, ease: EASE_WIN }}
        />
      </span>
      {children}
    </motion.a>
  );
}

/* ── Navigation ────────────────────────────────────────────────────────────── */

function Nav() {
  // sticky glass: transparent at the top, frosted once the page scrolls
  const [scrolled, setScrolled] = useState(false);
  const [hidden, setHidden] = useState(false);
  const lastScrollY = useRef(0);

  useEffect(() => {
    const onScroll = () => {
      const currentScrollY = window.scrollY;
      
      // Update scrolled state for glass background
      setScrolled(currentScrollY > 24);

      // Determine visibility based on scroll direction
      if (currentScrollY > lastScrollY.current && currentScrollY > 80) {
        // Scrolling down and past the very top
        setHidden(true);
      } else {
        // Scrolling up
        setHidden(false);
      }
      
      lastScrollY.current = currentScrollY;
    };
    onScroll();
    window.addEventListener("scroll", onScroll, { passive: true });
    return () => window.removeEventListener("scroll", onScroll);
  }, []);

  return (
    <motion.nav
      initial={{ opacity: 0, y: -14 }}
      animate={{ opacity: 1, y: 0 }}
      transition={{ duration: 0.6, ease: EASE_WIN }}
      className={`fixed inset-x-0 top-0 z-30 transition-all duration-300 ${
        scrolled
          ? "border-b border-hair bg-[rgba(10,12,18,0.6)] backdrop-blur-xl"
          : "border-b border-transparent bg-transparent"
      } ${hidden ? "-translate-y-full" : "translate-y-0"}`}
    >
      <div className="mx-auto flex max-w-6xl items-center justify-between px-6 py-5">
        <a href="#" className="flex items-center gap-2.5">
          <OrbitMark className="h-6 w-6" />
          <span className="font-sans text-[17px] font-semibold tracking-tight">
            <span className="text-amber">W</span>
            <span className="text-t1">a</span>
            <span className="text-amber">k</span>
            <span className="text-t1">i</span>
            <span className="text-amber">e</span>
          </span>
        </a>



        <div className="flex items-center gap-2">
          <a
            href={REPO_URL}
            target="_blank"
            rel="noopener noreferrer"
            aria-label="Wakie on GitHub"
            className="grid h-9 w-9 place-items-center rounded-full border border-hair-2 bg-white/[0.04] text-t2 backdrop-blur-sm transition-colors hover:border-amber/50 hover:text-t1"
          >
            <GitHubIcon className="h-[18px] w-[18px]" />
          </a>
          <a
            href="#download"
            className="flex h-9 items-center rounded-full border border-hair-2 bg-white/[0.04] px-5 font-sans text-[14px] font-semibold text-t1 backdrop-blur-sm transition-colors hover:border-amber/50 hover:bg-amber/10"
          >
            Download
          </a>
        </div>
      </div>
    </motion.nav>
  );
}

/* ── Inline marks (no external assets) ─────────────────────────────────────── */

export function OrbitMark({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <ellipse
        cx="12"
        cy="12"
        rx="10.5"
        ry="5"
        stroke="rgba(255,255,255,0.55)"
        strokeWidth="1.3"
        transform="rotate(-24 12 12)"
      />
      <circle cx="12" cy="12" r="4.4" fill="#ffc465" />
      <circle
        cx="12"
        cy="12"
        r="4.4"
        fill="#ffc465"
        opacity="0.5"
        style={{ filter: "blur(3px)" }}
      />
    </svg>
  );
}

export function DownloadIcon({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="none" className={className} aria-hidden>
      <path
        d="M12 3v12m0 0l-4.5-4.5M12 15l4.5-4.5M4 20h16"
        stroke="currentColor"
        strokeWidth="1.9"
        strokeLinecap="round"
        strokeLinejoin="round"
      />
    </svg>
  );
}

export function GitHubIcon({ className = "" }: { className?: string }) {
  return (
    <svg viewBox="0 0 24 24" fill="currentColor" className={className} aria-hidden>
      <path d="M12 .5C5.37.5 0 5.87 0 12.5c0 5.3 3.44 9.8 8.21 11.39.6.11.82-.26.82-.58 0-.29-.01-1.04-.02-2.05-3.34.73-4.04-1.61-4.04-1.61-.55-1.39-1.34-1.76-1.34-1.76-1.09-.75.08-.73.08-.73 1.2.08 1.84 1.24 1.84 1.24 1.07 1.84 2.81 1.31 3.5 1 .11-.78.42-1.31.76-1.61-2.67-.3-5.47-1.34-5.47-5.96 0-1.32.47-2.39 1.24-3.23-.12-.31-.54-1.53.12-3.18 0 0 1.01-.32 3.3 1.23a11.5 11.5 0 016 0c2.29-1.55 3.3-1.23 3.3-1.23.66 1.65.24 2.87.12 3.18.77.84 1.24 1.91 1.24 3.23 0 4.63-2.81 5.65-5.49 5.95.43.37.82 1.1.82 2.22 0 1.61-.01 2.9-.01 3.29 0 .32.22.7.83.58A12.01 12.01 0 0024 12.5C24 5.87 18.63.5 12 .5z" />
    </svg>
  );
}
