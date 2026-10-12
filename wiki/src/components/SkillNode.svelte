<script lang="ts">
  // Skill node (.vw-node, contract S36; Svelte so static pages share it). Without `rank` the counter shows the max
  // rank only (the "All skills" table). S82: the planner's path nodes, `mark` = a small sign in the corner (the 1/3
  // strength of a team node outside the main path).
  // `label` is the full accessible name ("Fireball, 2 of 10, available"); extra attributes and event handlers
  // (onclick, oncontextmenu, onkeydown, tabindex, data-*) pass through to the button. WIKI-GRAFIKA: `pic` = base URL of
  // the owner's skill picture (src/lib/art.ts artFor, files -64 / -128) drawn instead of the glyph.
  import type { HTMLButtonAttributes } from "svelte/elements";

  interface Props extends Omit<HTMLButtonAttributes, "class"> {
    glyph?: string;
    state: "locked" | "available" | "partial" | "max";
    rank?: number | null;
    max: number;
    active?: boolean;
    capstone?: boolean;
    selected?: boolean;
    /** The learned rank needs a higher character level than the chosen one (red counter). */
    invalid?: boolean;
    label: string;
    /** Glyph colour (element or class); gold by default. */
    color?: string | null;
    /** Size in px (64 by default, 76 for a capstone). */
    size?: number | null;
    /** Text under the lock of a locked node ("lv. 28"). */
    lockText?: string | null;
    /** Small sign in the corner ("⅓"). */
    mark?: string | null;
    /** Base URL of the skill picture (instead of the glyph). */
    pic?: string | null;
  }

  let {
    glyph = "✦",
    state,
    rank = null,
    max,
    active = false,
    capstone = false,
    selected = false,
    invalid = false,
    label,
    color = null,
    size = null,
    lockText = null,
    mark = null,
    pic = null,
    ...rest
  }: Props = $props();
  // Not iconSources() from lib/item-model: that would pull the item model into the planner bundle (budget).
  const img = $derived(pic ? { src: `${pic}-64.webp`, srcset: `${pic}-64.webp 1x, ${pic}-128.webp 2x` } : null);

  const style = $derived(
    [color ? `--node-glyph: ${color}` : "", size ? `width: ${size}px; height: ${size}px` : ""].filter(Boolean).join("; ") || undefined,
  );
</script>

<button
  type="button"
  {...rest}
  class={`vw-node${active ? " vw-node--active" : ""}${capstone ? " vw-node--capstone" : ""}${invalid ? " is-invalid" : ""}`}
  data-state={state}
  aria-pressed={selected ? "true" : "false"}
  aria-label={label}
  {style}
>
  {#if state === "locked"}
    <span class="lock" aria-hidden="true"></span>
    {#if lockText}<span class="lock-text" aria-hidden="true">{lockText}</span>{/if}
  {:else if img}
    <img class="pic" src={img.src} srcset={img.srcset} alt="" width="64" height="64" loading="lazy" decoding="async" />
  {:else}
    <span class="glyph" aria-hidden="true">{glyph}</span>
  {/if}
  <span class="vw-node__rank" aria-hidden="true">{rank == null ? max : `${rank}/${max}`}</span>
  {#if mark}<span class="mark" aria-hidden="true">{mark}</span>{/if}
</button>

<style>
  .vw-node {
    display: inline-flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    gap: 4px;
    flex-shrink: 0;
    padding: 0;
    color: var(--vw-gold-bright);
    background: repeating-linear-gradient(135deg, var(--vw-bg-sunken) 0 5px, var(--vw-panel) 5px 10px);
    -webkit-touch-callout: none;
    user-select: none;
    touch-action: manipulation;
  }
  .vw-node[data-state="partial"] { color: var(--vw-gold); }
  .vw-node[data-state="available"], .vw-node[data-state="locked"] { color: var(--vw-gold-dark); }
  .vw-node[aria-pressed="true"] { box-shadow: var(--vw-focus); }
  .vw-node[data-state="max"][aria-pressed="true"] { box-shadow: var(--vw-focus), 0 0 18px rgba(232, 194, 90, 0.45); }
  .vw-node :global(.vw-node__rank) { background: var(--vw-bg-sunken); }
  .vw-node[data-state="max"] :global(.vw-node__rank) { background: var(--vw-gold-bright); color: var(--vw-text-on-gold); }
  .vw-node.is-invalid :global(.vw-node__rank) { color: var(--vw-danger); border-color: var(--vw-danger); background: var(--vw-bg-sunken); }
  .glyph { font-size: 28px; line-height: 1; color: var(--node-glyph, var(--vw-gold-bright)); }
  .vw-node--capstone .glyph { font-size: 34px; }
  .pic { position: absolute; inset: 3px; width: calc(100% - 6px); height: calc(100% - 6px); object-fit: cover; pointer-events: none; }
  .lock { position: relative; width: 14px; height: 11px; margin-top: 8px; background: var(--vw-text-muted); }
  .lock::before { content: ""; position: absolute; left: 2px; top: -8px; width: 6px; height: 7px; border: 2px solid var(--vw-text-muted); border-bottom: 0; }
  .mark { position: absolute; top: 2px; right: 3px; font: 800 12px/1 var(--vw-font-ui); color: var(--vw-text-soft); }
  .lock-text { font: 700 11px/1 var(--vw-font-ui); color: var(--vw-text-muted); white-space: nowrap; }
  @media (prefers-reduced-motion: reduce) {
    .vw-node { transition: none; }
  }
</style>
