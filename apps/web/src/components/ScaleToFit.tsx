"use client";

import { useEffect, useLayoutEffect, useRef, useState } from "react";

/* Renders children at their fixed desktop width and shrinks the whole block
   proportionally to the container — on a phone you see the real app window,
   just smaller. transform doesn't affect layout, so the wrapper mirrors the
   scaled size to keep document flow correct. */

const useIsoLayoutEffect = typeof window === "undefined" ? useEffect : useLayoutEffect;

export default function ScaleToFit({
  width,
  children,
}: {
  width: number;
  children: React.ReactNode;
}) {
  const outerRef = useRef<HTMLDivElement>(null);
  const innerRef = useRef<HTMLDivElement>(null);
  const [scale, setScale] = useState(1);
  const [height, setHeight] = useState<number>();

  useIsoLayoutEffect(() => {
    const outer = outerRef.current;
    const inner = innerRef.current;
    if (!outer || !inner) return;
    const measure = () => {
      const s = Math.min(1, outer.clientWidth / width);
      setScale(s);
      setHeight(inner.offsetHeight * s);
    };
    measure();
    const ro = new ResizeObserver(measure);
    ro.observe(outer);
    ro.observe(inner);
    return () => ro.disconnect();
  }, [width]);

  return (
    <div ref={outerRef} className="w-full">
      <div className="mx-auto" style={{ width: width * scale, height }}>
        <div
          ref={innerRef}
          style={{ width, transform: `scale(${scale})`, transformOrigin: "top left" }}
        >
          {children}
        </div>
      </div>
    </div>
  );
}
