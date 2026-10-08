<script lang="ts">
  // Skill tree node (.vw-node, contract S36; S41: Svelte so the SkillPlanner island and static pages share it).
  // `label` is the full accessible name ("Fireball, 2 of 10, available"); extra attributes and event handlers
  // (onclick, oncontextmenu, onkeydown, tabindex, data-*) pass through to the button.
  import type { HTMLButtonAttributes } from "svelte/elements";

  interface Props extends Omit<HTMLButtonAttributes, "class"> {
    glyph?: string;
    state: "locked" | "available" | "partial" | "max";
    rank: number;
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
  }

  let {
    glyph = "✦",
    state,
    rank,
    max,
    active = false,
    capstone = false,
    selected = false,
    invalid = false,
    label,
    color = null,
    size = null,
    lockText = null,
    ...rest
  }: Props = $props();

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
  {:else}
    <span class="glyph" aria-hidden="true">{glyph}</span>
  {/if}
  <span class="vw-node__rank" aria-hidden="true">{rank}/{max}</span>
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
  .lock { position: relative; width: 14px; height: 11px; margin-top: 8px; background: var(--vw-text-muted); }
  .lock::before { content: ""; position: absolute; left: 2px; top: -8px; width: 6px; height: 7px; border: 2px solid var(--vw-text-muted); border-bottom: 0; }
  .lock-text { font: 700 11px/1 var(--vw-font-ui); color: var(--vw-text-muted); white-space: nowrap; }
  @media (prefers-reduced-motion: reduce) {
    .vw-node { transition: none; }
  }
</style>
