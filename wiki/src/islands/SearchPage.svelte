<script lang="ts">
  // Search page (/pl/szukaj/?q=&t=): Pagefind loaded on demand from /pagefind/pagefind.js; tabs by the `type`
  // filter with counts, rows with the match highlighted, "best match" item tooltip (desktop), empty states.
  // Without an index (npm run dev) it says how to get one.
  import { onMount } from "svelte";
  import ItemIcon from "../components/ItemIcon.svelte";
  import ItemTooltip from "../components/ItemTooltip.svelte";
  import { highlight } from "../lib/search";
  import type { TooltipData } from "../lib/item-model";

  interface Labels {
    placeholder: string;
    button: string;
    all: string;
    results: string; // "{count} dla „{q}”"
    noneTitle: string;
    noneText: string;
    emptyTitle: string;
    emptyText: string;
    pending: string;
    devOnly: string;
    loading: string;
    best: string;
    bind: string;
    tabs: Record<string, string>;
    badges: Record<string, string>;
    plural: { one: string; few: string; many: string };
    examples: string[];
  }

  interface Props {
    lang: "pl" | "en";
    labels: Labels;
  }

  let { lang, labels }: Props = $props();

  const TYPES = ["item", "monster", "region", "quest", "skill", "guide"];
  const COLORS: Record<string, string> = {
    item: "var(--vw-gold-bright)",
    monster: "var(--vw-zone-red-text)",
    region: "var(--vw-zone-green)",
    quest: "var(--vw-accent-text)",
    skill: "var(--vw-exp)",
    guide: "var(--vw-accent-text)",
  };

  interface Row {
    url: string;
    title: string;
    type: string;
    meta: string;
    excerpt: string;
    pending: boolean;
    glyph?: string;
    color?: string;
    rarity?: string;
    tooltip?: TooltipData;
  }

  // eslint-disable-next-line @typescript-eslint/no-explicit-any
  let pagefind: any = null;
  let query = $state("");
  let tab = $state<string | null>(null);
  let rows = $state<Row[]>([]);
  let counts = $state<Record<string, number>>({});
  let total = $state(0);
  let status = $state<"idle" | "loading" | "ready" | "missing">("idle");
  let timer: ReturnType<typeof setTimeout> | undefined;

  function plural(n: number): string {
    if (lang === "en") return n === 1 ? labels.plural.one : labels.plural.many;
    if (n === 1) return labels.plural.one;
    const last = n % 10;
    const lastTwo = n % 100;
    return last >= 2 && last <= 4 && !(lastTwo >= 12 && lastTwo <= 14) ? labels.plural.few : labels.plural.many;
  }

  function syncUrl() {
    const url = new URL(location.href);
    if (query) url.searchParams.set("q", query);
    else url.searchParams.delete("q");
    if (tab) url.searchParams.set("t", tab);
    else url.searchParams.delete("t");
    history.replaceState(null, "", url);
  }

  async function run() {
    syncUrl();
    if (!pagefind || query.trim() === "") {
      rows = [];
      counts = {};
      total = 0;
      return;
    }
    const all = await pagefind.search(query);
    // totalFilters: counts of every type for the phrase (filters is empty without an active filter).
    const typeCounts: Record<string, number> = all?.totalFilters?.type ?? all?.filters?.type ?? {};
    counts = typeCounts;
    total = all?.unfilteredResultCount ?? all?.results?.length ?? 0;
    const search = tab ? await pagefind.search(query, { filters: { type: tab } }) : all;
    const data = await Promise.all((search?.results ?? []).slice(0, 30).map((r: { data: () => Promise<unknown> }) => r.data()));
    // eslint-disable-next-line @typescript-eslint/no-explicit-any
    rows = data.map((d: any): Row => {
      const meta = d.meta ?? {};
      let tooltip: TooltipData | undefined;
      if (meta.tooltip) {
        try {
          tooltip = JSON.parse(meta.tooltip) as TooltipData;
        } catch {
          tooltip = undefined;
        }
      }
      return {
        url: d.url,
        title: meta.title ?? "",
        type: (d.filters?.type?.[0] as string) ?? meta.type ?? "guide",
        meta: meta.line ?? "",
        excerpt: d.excerpt ?? "",
        pending: meta.pending === "1",
        glyph: meta.glyph,
        color: meta.color,
        rarity: meta.rarity,
        tooltip,
      };
    });
  }

  function schedule() {
    clearTimeout(timer);
    timer = setTimeout(run, 150);
  }

  function pick(next: string | null) {
    tab = next;
    run();
  }

  onMount(async () => {
    const params = new URLSearchParams(location.search);
    query = params.get("q") ?? "";
    tab = params.get("t");
    status = "loading";
    try {
      const path = "/pagefind/pagefind.js";
      pagefind = await import(/* @vite-ignore */ path);
      await pagefind.options?.({ excerptLength: 18 });
      // Loads the filter index: without it the searches return no type counts.
      await pagefind.filters?.();
      status = "ready";
    } catch {
      status = "missing";
    }
    run();
  });

  const best = $derived(rows.find((r) => r.tooltip));
  const visibleTabs = $derived(TYPES.filter((type) => (counts[type] ?? 0) > 0));
</script>

<form class="field" role="search" onsubmit={(e) => { e.preventDefault(); run(); }}>
  <input
    type="search"
    name="q"
    bind:value={query}
    oninput={schedule}
    placeholder={labels.placeholder}
    aria-label={labels.placeholder}
    autocomplete="off"
  />
  <button class="vw-btn vw-btn--primary go" type="submit">{labels.button}</button>
</form>

{#if status === "missing"}
  <p class="note">{labels.devOnly}</p>
{/if}

{#if query.trim() !== "" && status === "ready"}
  <div class="tabs" role="tablist">
    <button role="tab" type="button" aria-selected={tab === null} onclick={() => pick(null)}>
      {labels.all} <span class="count">{total}</span>
    </button>
    {#each visibleTabs as type (type)}
      <button role="tab" type="button" aria-selected={tab === type} onclick={() => pick(type)}>
        {labels.tabs[type]} <span class="count">{counts[type]}</span>
      </button>
    {/each}
  </div>
{/if}

<div class="layout">
  <div class="results">
    {#if query.trim() === ""}
      <div class="vw-empty">
        <span class="vw-empty__mark" aria-hidden="true"></span>
        <p class="title">{labels.emptyTitle}</p>
        <p>{labels.emptyText}</p>
        <div class="examples">
          {#each labels.examples as example (example)}
            <button type="button" class="vw-chip" onclick={() => { query = example; run(); }}>{example}</button>
          {/each}
        </div>
      </div>
    {:else if status === "ready" && rows.length === 0}
      <div class="vw-empty">
        <span class="vw-empty__mark" aria-hidden="true"></span>
        <p class="title">{labels.noneTitle.replace("{q}", query)}</p>
        <p>{labels.noneText}</p>
      </div>
    {:else if status === "loading"}
      <p class="summary">{labels.loading}</p>
    {:else}
      <p class="summary" aria-live="polite">
        {labels.results.replace("{count}", `${tab ? (counts[tab] ?? 0) : total} ${plural(tab ? (counts[tab] ?? 0) : total)}`).replace("{q}", query)}
      </p>
      <ol class="list">
        {#each rows as row (row.url)}
          <li class="row">
            {#if row.glyph}
              <ItemIcon glyph={row.glyph} color={row.color ?? "#C9CED6"} rarity={row.rarity ?? null} size={48} />
            {:else}
              <span class="mark vw-ph" style={`--c: ${COLORS[row.type] ?? "var(--vw-border)"}`} aria-hidden="true"></span>
            {/if}
            <div class="body">
              <div class="top">
                <span class="badge" style={`--c: ${COLORS[row.type] ?? "var(--vw-text-muted)"}`}>{labels.badges[row.type] ?? row.type}</span>
                <span class="meta">{row.meta}</span>
              </div>
              {#if row.pending}
                <span class="name" style={row.rarity ? `color: var(--vw-r-${row.rarity}-text)` : undefined}>
                  {#each highlight(row.title, query) as part, p (p)}{#if part.match}<mark>{part.text}</mark>{:else}{part.text}{/if}{/each}
                </span>
                <span class="pending">{labels.pending}</span>
              {:else}
                <a class="name" href={row.url} style={row.rarity ? `color: var(--vw-r-${row.rarity}-text)` : undefined}>
                  {#each highlight(row.title, query) as part, p (p)}{#if part.match}<mark>{part.text}</mark>{:else}{part.text}{/if}{/each}
                </a>
              {/if}
              <!-- Pagefind excerpts are escaped text with <mark> tags. -->
              <!-- eslint-disable-next-line svelte/no-at-html-tags -->
              <p class="excerpt">{@html row.excerpt}</p>
            </div>
          </li>
        {/each}
      </ol>
    {/if}
  </div>
  {#if best?.tooltip}
    <aside class="best">
      <p class="vw-label">{labels.best}</p>
      <ItemTooltip data={best.tooltip} href={best.pending ? null : best.url} labels={{ bind: labels.bind }} />
    </aside>
  {/if}
</div>

<style>
  .field { display: flex; max-width: 860px; height: 66px; border: 1px solid var(--vw-gold-dark); background: var(--vw-bg); box-shadow: var(--vw-well); }
  .field input { flex: 1; min-width: 0; padding: 0 22px; background: none; border: 0; outline: none; color: var(--vw-text); font: 500 22px/1 var(--vw-font-ui); }
  .field:focus-within { box-shadow: var(--vw-well), var(--vw-focus); }
  .go { height: 100%; min-width: 120px; font-size: 16px; letter-spacing: .14em; }
  .note { color: var(--vw-text-muted); }
  .tabs { display: flex; gap: 8px; margin: 28px 0 0; border-bottom: 1px solid var(--vw-border); overflow-x: auto; }
  .tabs button { display: inline-flex; align-items: center; gap: 8px; min-height: var(--vw-touch); padding: 0 16px; background: none; border: 0; border-bottom: 2px solid transparent; color: var(--vw-text-muted); font: 700 17px/1 var(--vw-font-ui); cursor: pointer; white-space: nowrap; }
  .tabs button[aria-selected="true"] { color: var(--vw-text); font-weight: 800; border-bottom-color: var(--vw-gold-bright); }
  .count { padding: 2px 5px; font-size: 12px; background: var(--vw-panel-raised); color: var(--vw-text-muted); }
  .tabs button[aria-selected="true"] .count { background: var(--vw-gold-bright); color: var(--vw-text-on-gold); }
  .layout { display: grid; grid-template-columns: 1fr 380px; gap: 48px; margin-top: 24px; }
  .summary { margin: 0 0 8px; font-size: 15px; color: var(--vw-text-muted); }
  .list { list-style: none; margin: 0; padding: 0; }
  .row { display: flex; gap: 16px; padding: 20px 0; border-bottom: 1px solid var(--vw-border-subtle); }
  .mark { width: 48px; height: 48px; flex-shrink: 0; border: 1px solid var(--c); }
  .body { display: flex; flex-direction: column; gap: 4px; min-width: 0; }
  .top { display: flex; align-items: center; gap: 10px; }
  .badge { padding: 2px 6px; border: 1px solid var(--c); color: var(--c); font: 800 12px/1.2 var(--vw-font-ui); letter-spacing: .14em; text-transform: uppercase; }
  .meta { font-size: 15px; color: var(--vw-text-muted); }
  .name { font: 800 22px/1.2 var(--vw-font-ui); color: var(--vw-text); }
  .pending { font-size: 13px; color: var(--vw-text-muted); }
  .excerpt { margin: 0; font-size: 16px; color: var(--vw-text-soft); }
  mark, .excerpt :global(mark) { background: rgba(232, 194, 90, .22); color: inherit; box-shadow: inset 0 -2px 0 var(--vw-gold-bright); }
  .vw-empty .title { margin: 0; font: 400 var(--vw-fs-h2)/var(--vw-lh-h2) var(--vw-font-display); color: var(--vw-gold-bright); }
  .vw-empty p { margin: 0; }
  .examples { display: flex; flex-wrap: wrap; gap: 8px; justify-content: center; }
  .best .vw-label { margin: 0 0 12px; }
  @media (max-width: 1023px) {
    .layout { grid-template-columns: 1fr; }
    .best { display: none; }
  }
  @media (max-width: 767px) {
    .field { height: 52px; }
    .field input { font-size: 18px; padding: 0 16px; }
    .go { display: none; }
    .tabs { border-bottom: 0; margin-top: 16px; }
    .tabs button { min-height: 40px; border: 1px solid var(--vw-border); background: var(--vw-panel); font-size: 15px; }
    .tabs button[aria-selected="true"] { background: var(--vw-gold-bright); color: var(--vw-text-on-gold); border-color: var(--vw-gold-bright); }
    .row { padding: 14px 0; gap: 12px; }
    .row :global(.vw-item-icon), .mark { width: 40px !important; height: 40px !important; }
    .top { gap: 0; }
    .badge { border: 0; padding: 0; font-size: 11px; }
    .top .meta { display: none; }
    .name { font-size: 18px; }
    .excerpt { display: none; }
  }
</style>
