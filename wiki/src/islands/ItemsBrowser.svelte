<script lang="ts">
  // Item browser (S40, /pl/przedmioty/, mock-up Przedmioty-*): filters (rarity, slot / category, class, level range,
  // name without Polish letters), generated equipment grouped by base with a tier stepper (or every tier flat), sort,
  // paging, a preview tooltip on the right (desktop) or under the row (mobile). The first page is server-rendered from
  // `initial`; the full index comes from /<lang>/items-index.json and item details from /data/items/<id>.json.
  // State in the URL (?q=&r=&slot=&cls=&lv=&sort=&sel=&all=&page=).
  import ItemIcon from "../components/ItemIcon.svelte";
  import ItemTooltip from "../components/ItemTooltip.svelte";
  import { pluralForm } from "../lib/format";
  import { buildTooltip, listRarity, type ItemDetail, type Lang, type TooltipData, type TooltipLabels } from "../lib/item-model";
  import {
    DEFAULT_ITEM_FILTERS,
    groupTiers,
    itemMatches,
    parseItemFilters,
    serializeItemFilters,
    sortRows,
    type ItemFilters,
    type ItemSort,
  } from "../lib/items-filters";

  interface Row {
    id: string; base: string; name: string; type: string; slot: string; category: string; classes: string[];
    allClasses: boolean; level: number; tier: number | null; rarities: string[]; stats: Record<string, string>;
    statNum: Record<string, number>; statLabel: string; glyph: string; color: string; icon: string | null; href: string; key: string;
  }
  type Opt = { id: string; name: string };

  interface Props {
    lang: Lang;
    initial: Row[];
    total: number;
    rarities: { key: string; name: string }[];
    slots: Opt[];
    classes: Opt[];
    labels: Record<string, string>;
    tooltip: TooltipLabels;
    initialTip: TooltipData | null;
    indexUrl: string;
    bossesHref: string;
  }

  let { lang, initial, total, rarities, slots, classes, labels, tooltip, initialTip, indexUrl, bossesHref }: Props = $props();

  const PER_PAGE = 50;
  const order = rarities.map((r) => r.key);
  let rows = $state<Row[]>(initial);
  let loaded = $state(false);
  let f = $state<ItemFilters>({ ...DEFAULT_ITEM_FILTERS, rarities: [] });
  let mobile = $state(false);
  let moreOpen = $state(false);
  let tierPick = $state<Record<string, number>>({});
  let open = $state<string>("");
  let tip = $state<TooltipData | null>(initialTip);
  // eslint-disable-next-line svelte/prefer-svelte-reactivity -- a fetch cache, never rendered
  const details = new Map<string, ItemDetail>();
  const fill = (text: string, args: Record<string, string | number>) => text.replace(/\{(\w+)\}/g, (w, k: string) => (k in args ? String(args[k]) : w));

  $effect(() => {
    const mq = matchMedia("(max-width: 1023px)");
    mobile = mq.matches;
    mq.addEventListener("change", () => (mobile = mq.matches));
    f = parseItemFilters(location.search, { rarities: order, slots: slots.map((s) => s.id), classes: classes.map((c) => c.id) });
    fetch(indexUrl)
      .then((r) => r.json())
      .then((all: Row[]) => {
        rows = all;
        loaded = true;
      })
      .catch(() => (loaded = true));
    addEventListener("popstate", () => (f = parseItemFilters(location.search)));
  });

  $effect(() => {
    const url = `${location.pathname}${serializeItemFilters(f)}`;
    if (url !== location.pathname + location.search) history.replaceState(null, "", url);
  });

  const shownRarity = (row: Row) => listRarity(row.rarities, f.rarities, order);
  const matched = $derived(rows.filter((r) => itemMatches(r, f)));
  const groups = $derived(f.all ? matched.map((r) => ({ base: `item:${r.id}`, tiers: [r], shown: r })) : groupTiers(matched, f.lv));
  const entries = $derived(
    sortRows(
      groups.map((g) => {
        const pick = tierPick[g.base];
        const row = (pick !== undefined ? g.tiers[pick] : undefined) ?? g.shown;
        const rarity = shownRarity(row);
        return { group: g, row, name: row.name, type: row.type, level: row.level, statNum: row.statNum[rarity], rarity };
      }),
      f.sort,
      lang,
    ),
  );
  const pages = $derived(Math.max(1, Math.ceil(entries.length / PER_PAGE)));
  const page = $derived(Math.min(f.page, pages));
  const visible = $derived(mobile ? entries.slice(0, page * PER_PAGE) : entries.slice((page - 1) * PER_PAGE, page * PER_PAGE));
  const count = $derived(loaded ? entries.length : total);
  const countText = $derived(`${count} ${labels[`count.${pluralForm(count, lang)}`]}`);

  function set(patch: Partial<ItemFilters>, keepPage = false) {
    f = { ...f, ...patch, page: keepPage ? (patch.page ?? f.page) : 1 };
    if (!keepPage) tierPick = {};
  }

  async function select(row: Row, rarity: string) {
    f = { ...f, sel: row.id };
    open = mobile && open === row.id ? "" : row.id;
    let d = details.get(row.id);
    if (!d) {
      try {
        d = (await (await fetch(`/data/items/${row.id}.json`)).json()) as ItemDetail;
        details.set(row.id, d);
      } catch {
        return;
      }
    }
    tip = buildTooltip(d, { rarity, lang }, tooltip);
  }

  function step(base: string, tiers: Row[], current: Row, delta: number) {
    const i = tiers.indexOf(current) + delta;
    if (i < 0 || i >= tiers.length) return;
    tierPick = { ...tierPick, [base]: i };
  }

  const toggleRarity = (key: string) => set({ rarities: f.rarities.includes(key) ? f.rarities.filter((r) => r !== key) : [...f.rarities, key].sort((a, b) => order.indexOf(a) - order.indexOf(b)) });
  const sortBy = (key: ItemSort) => set({ sort: key === "level" ? (f.sort === "-level" ? "level" : "-level") : key }, true);
  const ariaSort = (key: string) => (key === "level" ? (f.sort === "-level" ? "descending" : f.sort === "level" ? "ascending" : "none") : f.sort === key ? "descending" : "none");
  const nextSort = () => set({ sort: ({ "-level": "level", level: "name", name: "type", type: "stat", stat: "-level" } as const)[f.sort] }, true);
  const clear = () => (f = { ...DEFAULT_ITEM_FILTERS, rarities: [], sort: f.sort });
  const withR = (row: Row, rarity: string) => (row.rarities.length > 1 ? `${row.href}?r=${rarity}` : row.href);
  const lvFrom = (e: Event) => {
    const v = Number((e.currentTarget as HTMLInputElement).value) || 1;
    set({ lv: [Math.max(1, Math.min(100, v)), f.lv?.[1] ?? 100] });
  };
  const lvTo = (e: Event) => {
    const v = Number((e.currentTarget as HTMLInputElement).value) || 100;
    set({ lv: [f.lv?.[0] ?? 1, Math.max(1, Math.min(100, v))] });
  };
  let timer = 0;
  const onQuery = (e: Event) => {
    const v = (e.currentTarget as HTMLInputElement).value;
    clearTimeout(timer);
    timer = window.setTimeout(() => set({ q: v }), 150);
  };
</script>

<div class="browser">
  <header class="head">
    <div class="titles">
      <h1 class="h1">{labels.title}</h1>
      <p class="count" aria-live="polite">{countText}</p>
    </div>
    <label class="search">
      <span class="vw-sr">{labels.filter}</span>
      <input type="search" placeholder={labels.filter} value={f.q} oninput={onQuery} autocomplete="off" spellcheck="false" />
    </label>
  </header>

  <div class="layout">
    <aside class="filters" aria-label={labels.filters}>
      <div class="group">
        <h2 class="vw-label">{labels.rarity}</h2>
        <div class="rars">
          {#each rarities as r (r.key)}
            <button type="button" class="rar" style={`--rc: var(--vw-r-${r.key}); --rt: var(--vw-r-${r.key}-text)`} aria-pressed={f.rarities.includes(r.key)} onclick={() => toggleRarity(r.key)}>
              <span class="box" aria-hidden="true"></span>{r.name}
            </button>
          {/each}
        </div>
      </div>
      <div class="mobile-bar">
        <button type="button" class="sortbtn" onclick={nextSort}><span class="muted">{labels.sort}</span> <strong>{labels[`sort.${f.sort}`]}</strong></button>
        <button type="button" class="clear" onclick={clear}>{labels.clear}</button>
      </div>
      <!-- S44: a button + CSS instead of <details open={!mobile}>: the same markup on both widths, so hydration on a
           phone no longer collapses the filters and moves the list (CLS) -->
      <button type="button" class="vw-btn morebtn-toggle" aria-expanded={moreOpen} aria-controls="items-more" onclick={() => (moreOpen = !moreOpen)}>{labels.filters}</button>
      <div class="more" id="items-more" class:is-open={moreOpen}>
        <div class="group">
          <h2 class="vw-label">{labels.slot}</h2>
          <div class="chips">
            <button type="button" class="vw-chip" aria-pressed={f.slot === ""} onclick={() => set({ slot: "" })}>{labels.all}</button>
            {#each slots as s (s.id)}<button type="button" class="vw-chip" aria-pressed={f.slot === s.id} onclick={() => set({ slot: s.id })}>{s.name}</button>{/each}
          </div>
        </div>
        <div class="group">
          <h2 class="vw-label">{labels.class}</h2>
          <div class="chips">
            <button type="button" class="vw-chip" aria-pressed={f.cls === ""} onclick={() => set({ cls: "" })}>{labels.anyClass}</button>
            {#each classes as c (c.id)}<button type="button" class="vw-chip" aria-pressed={f.cls === c.id} onclick={() => set({ cls: c.id })}>{c.name}</button>{/each}
          </div>
        </div>
        <div class="group">
          <h2 class="vw-label">{labels.level}</h2>
          <div class="lv">
            <label><span class="vw-sr">{labels.from}</span><input type="number" min="1" max="100" placeholder="1" value={f.lv?.[0] ?? ""} onchange={lvFrom} /></label>
            <span aria-hidden="true">–</span>
            <label><span class="vw-sr">{labels.to}</span><input type="number" min="1" max="100" placeholder="100" value={f.lv?.[1] ?? ""} onchange={lvTo} /></label>
          </div>
        </div>
        <label class="alltiers"><input type="checkbox" checked={f.all} onchange={(e) => set({ all: (e.currentTarget as HTMLInputElement).checked })} /> {labels.allTiers}</label>
        <button type="button" class="clear desk" onclick={clear}>{labels.clear}</button>
      </div>
    </aside>

    <div class="list">
      <p class="bosslink"><a href={bossesHref}>{labels.bossItems}</a></p>
      {#if entries.length === 0 && loaded}
        <div class="vw-empty">
          <span class="vw-empty__mark" aria-hidden="true"></span>
          <p class="etitle">{labels.none}</p>
          <button type="button" class="vw-btn" onclick={clear}>{labels.clear}</button>
        </div>
      {:else}
        <table class="vw-table items">
          <caption class="vw-sr">{labels.title}</caption>
          <thead>
            <tr>
              <th scope="col"><span class="vw-sr">{labels.icon}</span></th>
              <th scope="col" aria-sort={ariaSort("name")}><button type="button" onclick={() => sortBy("name")}>{labels.colName}</button></th>
              <th scope="col" aria-sort={ariaSort("type")}><button type="button" onclick={() => sortBy("type")}>{labels.colType}</button></th>
              <th scope="col" aria-sort={ariaSort("level")}><button type="button" onclick={() => sortBy("level")}>{labels.colLevel}</button></th>
              <th scope="col" class="r" aria-sort={ariaSort("stat")}><button type="button" onclick={() => sortBy("stat")}>{labels.colStat}</button></th>
            </tr>
          </thead>
          <tbody>
            {#each visible as e (e.group.base)}
              {@const r = e.rarity}
              <tr aria-selected={f.sel === e.row.id} onclick={() => select(e.row, r)}>
                <td class="icon"><ItemIcon glyph={e.row.glyph} color={e.row.color} rarity={r} size={38} src={e.row.icon} /></td>
                <td class="name">
                  <a href={withR(e.row, r)} style={`color: var(--vw-r-${r}-text)`} onfocus={() => { if (!mobile) select(e.row, r); }} onclick={(ev) => { if (!mobile && !ev.ctrlKey && !ev.metaKey) { ev.preventDefault(); select(e.row, r); } }}>{e.row.name}</a>
                  <span class="cls">{e.row.allClasses ? labels.anyClass : e.row.classes.map((c) => classes.find((x) => x.id === c)?.name ?? c).join(", ")}</span>
                </td>
                <td class="type">{e.row.type}</td>
                <td class="lvcell">
                  {#if e.group.tiers.length > 1}
                    <span class="stepper">
                      <button type="button" aria-label={labels.prevTier} disabled={e.group.tiers.indexOf(e.row) === 0} onclick={(ev) => { ev.stopPropagation(); step(e.group.base, e.group.tiers, e.row, -1); }}>‹</button>
                      <span>{e.row.level}</span>
                      <button type="button" aria-label={labels.nextTier} disabled={e.group.tiers.indexOf(e.row) === e.group.tiers.length - 1} onclick={(ev) => { ev.stopPropagation(); step(e.group.base, e.group.tiers, e.row, 1); }}>›</button>
                    </span>
                  {:else}{e.row.level}{/if}
                </td>
                <td class="r stat">{e.row.stats[r] ?? "—"}</td>
              </tr>
              {#if mobile && open === e.row.id && tip}
                <tr class="tiprow"><td colspan="5"><ItemTooltip data={tip} href={withR(e.row, r)} labels={{ bind: labels.bind }} /><a class="openlink" href={withR(e.row, r)}>{labels.open}</a></td></tr>
              {/if}
            {/each}
          </tbody>
        </table>
        {#if mobile}
          {#if visible.length < entries.length}
            <button type="button" class="vw-btn morebtn" onclick={() => set({ page: page + 1 }, true)}>{fill(labels.more, { n: Math.min(PER_PAGE, entries.length - visible.length) })}</button>
          {/if}
        {:else if pages > 1}
          <nav class="vw-pager" aria-label={labels.pages}>
            {#each Array.from({ length: pages }, (_, i) => i + 1) as n (n)}
              <button type="button" class={`vw-btn${n === page ? " vw-btn--primary" : ""}`} aria-current={n === page ? "page" : undefined} onclick={() => set({ page: n }, true)}>{n}</button>
            {/each}
          </nav>
        {/if}
      {/if}
    </div>

    <aside class="preview" aria-label={labels.preview}>
      <h2 class="vw-label">{labels.preview}</h2>
      {#if tip}
        <ItemTooltip data={tip} labels={{ bind: labels.bind }} />
        <a class="openlink" href={rows.find((x) => x.id === tip?.id)?.href ? `${rows.find((x) => x.id === tip?.id)!.href}${tip.rarity ? `?r=${tip.rarity}` : ""}` : "#"}>{labels.open}</a>
      {/if}
    </aside>
  </div>
</div>

<style>
  .head { display: flex; align-items: flex-end; justify-content: space-between; gap: 24px; margin-bottom: 28px; }
  .titles { display: flex; align-items: baseline; gap: 22px; }
  .h1 { margin: 0; font: 700 64px/1 var(--vw-font-display); color: var(--vw-gold-bright); }
  .count { margin: 0; font-size: 18px; color: var(--vw-text-muted); }
  .search input { width: 460px; height: 52px; padding: 0 18px; font: 500 17px/1 var(--vw-font-ui); color: var(--vw-text); background: var(--vw-bg); border: 1px solid var(--vw-gold-dark); box-shadow: inset 0 2px 6px rgba(0, 0, 0, .35); }
  .search input:focus { outline: none; box-shadow: var(--vw-focus); }
  .layout { display: grid; grid-template-columns: 250px minmax(0, 1fr) 380px; gap: 28px; align-items: start; }
  .filters { display: flex; flex-direction: column; gap: 24px; }
  .group { display: flex; flex-direction: column; gap: 8px; }
  .group h2 { margin: 0; }
  .rars { display: flex; flex-direction: column; gap: 6px; }
  .rar { display: flex; align-items: center; gap: 12px; min-height: 40px; padding: 0 14px; background: var(--vw-panel); border: 1px solid var(--vw-border); color: var(--rt); font: 700 16px/1 var(--vw-font-ui); cursor: pointer; text-align: left; }
  .rar .box { width: 16px; height: 16px; border: 1.5px solid var(--rc); }
  .rar[aria-pressed="true"] { border-color: var(--rc); background: color-mix(in srgb, var(--rc) 16%, var(--vw-panel)); }
  .rar[aria-pressed="true"] .box { background: var(--rc); }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .chips .vw-chip { min-height: 40px; }
  @media (pointer: coarse) { .chips .vw-chip { min-height: var(--vw-touch); } }
  .lv { display: flex; align-items: center; gap: 8px; }
  .lv input { width: 90px; height: 44px; padding: 0 10px; background: var(--vw-bg); border: 1px solid var(--vw-border); color: var(--vw-text); font: 700 16px/1 var(--vw-font-ui); }
  .alltiers { display: flex; align-items: center; gap: 10px; min-height: 44px; font-weight: 700; cursor: pointer; }
  .alltiers input { width: 18px; height: 18px; accent-color: var(--vw-gold); }
  .clear { align-self: flex-start; min-height: 44px; padding: 0; background: none; border: 0; color: var(--vw-gold); font: 800 15px/1 var(--vw-font-ui); cursor: pointer; }
  .more { display: flex; flex-direction: column; gap: 24px; }
  .morebtn-toggle { display: none; }
  .more > :global(*) + :global(*) { margin-top: 24px; }
  .mobile-bar { display: none; }
  .muted { color: var(--vw-text-muted); }
  .bosslink { margin: 0 0 10px; text-align: right; font-weight: 800; }
  .items th button { all: unset; cursor: pointer; }
  .items th button:focus-visible { box-shadow: var(--vw-focus); }
  .items tbody tr { cursor: pointer; }
  .items td { height: 56px; }
  .icon { width: 52px; padding-right: 0; }
  .name a { display: block; font-weight: 800; font-size: 17px; }
  .cls { display: block; font-size: 13px; color: var(--vw-text-muted); }
  .type { color: var(--vw-text-soft); }
  .lvcell { font-weight: 800; white-space: nowrap; }
  .stepper { display: inline-flex; align-items: center; gap: 4px; }
  .stepper button { width: 30px; height: 30px; background: var(--vw-panel-raised); border: 1px solid var(--vw-border); color: var(--vw-gold-bright); font: 800 16px/1 var(--vw-font-ui); cursor: pointer; }
  .stepper button:disabled { opacity: .35; cursor: default; }
  .stepper span { min-width: 30px; text-align: center; }
  .r { text-align: right; }
  .stat { font-weight: 800; font-variant-numeric: tabular-nums; }
  .vw-pager { margin-top: 20px; justify-content: flex-end; }
  .preview { position: sticky; top: 90px; display: flex; flex-direction: column; gap: 12px; }
  .preview h2 { margin: 0; }
  .openlink { font-weight: 800; }
  .etitle { margin: 0; font: 400 var(--vw-fs-h2)/var(--vw-lh-h2) var(--vw-font-display); color: var(--vw-gold-bright); }
  .tiprow td { padding: 12px 0; }
  .morebtn { width: 100%; min-height: 48px; margin-top: 12px; }
  @media (max-width: 1279px) { .layout { grid-template-columns: 230px minmax(0, 1fr); } .preview { display: none; } }
  @media (max-width: 1023px) {
    .head { flex-direction: column; align-items: stretch; gap: 14px; margin-bottom: 14px; }
    .titles { justify-content: space-between; }
    .h1 { font-size: 44px; }
    .count { font-size: 15px; }
    .search input { width: 100%; height: 50px; }
    .layout { grid-template-columns: minmax(0, 1fr); gap: 14px; }
    .filters { gap: 12px; min-width: 0; }
    .group > h2 { display: none; }
    .rars { flex-direction: row; overflow-x: auto; padding-bottom: 4px; }
    .rar { flex-shrink: 0; }
    .mobile-bar { display: flex; justify-content: space-between; align-items: center; }
    .sortbtn { min-height: 44px; background: none; border: 0; color: var(--vw-text); font: 500 15px/1 var(--vw-font-ui); padding: 0; cursor: pointer; }
    .morebtn-toggle { display: inline-flex; align-self: flex-start; min-height: 44px; cursor: pointer; }
    .more:not(.is-open) { display: none; }
    .more .group > h2 { display: block; }
    .clear.desk { display: none; }
    .bosslink { text-align: left; }
    .items thead { display: none; }
    .items, .items tbody { display: block; background: none; border: 0; }
    .items tr { display: grid; grid-template-columns: 44px minmax(0, 1fr) auto; gap: 2px 12px; align-items: center; padding: 10px 12px; margin-bottom: 6px; background: var(--vw-panel); border: 1px solid var(--vw-border-subtle); min-height: 60px; }
    .items td { display: block; height: auto; padding: 0; border: 0; }
    .items td.icon { grid-row: 1 / 3; }
    .items td.type { grid-column: 2; grid-row: 2; font-size: 13px; color: var(--vw-text-muted); }
    .items td.lvcell { display: none; }
    .items td.stat { grid-column: 3; grid-row: 1 / 3; }
    .items td.name .cls { display: none; }
    .items tr.tiprow { display: block; padding: 0; background: none; border: 0; }
    .items tr.tiprow td { display: block; }
  }
</style>
