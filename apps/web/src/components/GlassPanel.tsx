import { forwardRef, type HTMLAttributes } from "react";

type GlassVariant = "floating" | "solid";

interface GlassPanelProps extends HTMLAttributes<HTMLDivElement> {
  /** floating = translucent + heavy blur (panels); solid = near-opaque (modals). */
  variant?: GlassVariant;
}

/**
 * The single source of the app's glass look. The 4-part elevation stack
 * (hair-2 border + inset highlight + deep shadow + ::before top sheen) and the
 * two-tier opacity live in globals.css `.glass` — this component just picks the
 * tier and forwards everything else, so every panel stays identical.
 */
const GlassPanel = forwardRef<HTMLDivElement, GlassPanelProps>(function GlassPanel(
  { variant = "floating", className = "", children, ...props },
  ref,
) {
  return (
    <div ref={ref} className={`glass glass--${variant} ${className}`} {...props}>
      {children}
    </div>
  );
});

export default GlassPanel;
