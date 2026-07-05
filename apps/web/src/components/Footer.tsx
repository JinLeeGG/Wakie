"use client";

import { OrbitMark } from "./Hero";

export default function Footer() {
  return (
    <footer className="w-full border-t border-hair px-6 py-8">
      <div className="mx-auto flex max-w-7xl flex-col items-center justify-between gap-4 sm:flex-row">
        {/* wordmark v2 — alternating amber/white */}
        <span className="flex items-center gap-2">
          <OrbitMark className="h-5 w-5" />
          <span className="font-sans text-[15px] font-semibold tracking-tight">
            <span className="text-amber">W</span>
            <span className="text-t1">a</span>
            <span className="text-amber">k</span>
            <span className="text-t1">i</span>
            <span className="text-amber">e</span>
          </span>
        </span>
        <span className="font-mono text-[12px] text-t3">
          © 2026 WakieAI · Made for macOS
        </span>
      </div>
    </footer>
  );
}
