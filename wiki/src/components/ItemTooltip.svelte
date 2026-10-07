<script lang="ts">
  // Item tooltip (.vw-tooltip, always dark): data from src/lib/tooltip.ts (TooltipData). Server-rendered by Astro
  // without JS and reused by the islands (search page, later the floating tooltip).
  import type { TooltipData } from "../lib/tooltip";
  import ItemIcon from "./ItemIcon.svelte";

  interface Props {
    data: TooltipData;
    floating?: boolean;
    href?: string | null;
    labels?: { bind: string };
  }

  let { data, floating = false, href = null, labels = { bind: "" } }: Props = $props();
</script>

<article
  class="vw-tooltip"
  class:vw-tooltip--floating={floating}
  data-theme="dark"
  data-rarity={data.rarity}
  style={`--c: var(--vw-r-${data.rarity}); --g: var(--vw-glow-${data.rarity});`}
>
  <div class="vw-tooltip__head">
    <ItemIcon glyph={data.glyph} color={data.color} rarity={data.rarity} size={56} />
    <div class="head">
      <div class="title">
        {#if href}
          <a class="vw-tooltip__name" href={href}>{data.name}</a>
        {:else}
          <span class="vw-tooltip__name">{data.name}</span>
        {/if}
        {#if data.up > 0}<span class="vw-tooltip__up">+{data.up}</span>{/if}
      </div>
      <div class="vw-tooltip__type">{data.type}</div>
    </div>
  </div>
  {#if data.pips}
    <div class="vw-tooltip__pips" aria-hidden="true">
      {#each Array.from({ length: 9 }, (_, i) => i) as i (i)}<i class:is-on={i < data.up}></i>{/each}
    </div>
  {/if}
  {#if data.rows.length > 0}
    <dl class="vw-tooltip__rows">
      {#each data.rows as row (row.label)}
        <div class:is-unmet={row.unmet}><dt>{row.label}</dt><dd>{row.value}</dd></div>
      {/each}
    </dl>
  {/if}
  {#if data.bonuses.length > 0}
    <ul class="vw-tooltip__bonus">
      {#each data.bonuses as bonus, i (i)}
        <li class:legendary={bonus.legendary} class:random={bonus.random}>{bonus.text}</li>
      {/each}
    </ul>
  {/if}
  {#if data.flavor}<p class="vw-tooltip__flavor">„{data.flavor}”</p>{/if}
  {#if data.bind && labels.bind}<p class="vw-tooltip__bind">{labels.bind}</p>{/if}
</article>

<style>
  .head { flex: 1; min-width: 0; display: flex; flex-direction: column; gap: 4px; }
  .title { display: flex; justify-content: space-between; align-items: flex-start; gap: 8px; }
  a.vw-tooltip__name:hover { color: var(--c); text-decoration: underline; }
  .vw-tooltip__bonus { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 2px; }
  .vw-tooltip__bonus .random { opacity: .8; font-style: italic; }
  .vw-tooltip__bonus .legendary { color: var(--vw-r-legendary-text); }
  .vw-tooltip__flavor, .vw-tooltip__bind { margin: 0; }
</style>
