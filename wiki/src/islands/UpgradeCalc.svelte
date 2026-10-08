<script lang="ts">
  // Upgrade calculator (S40, /pl/ulepszanie/, mock-up Ulepszanie-*): item search (combobox over /<lang>/items-index.json,
  // details from /data/items/<id>.json), rarity, current and target level, the protection scroll from +N; results from
  // the Markov chain in src/lib/upgrade.ts over the exported steps and costs (chance on the first try, expected gold,
  // materials, scrolls and attempts, the risk ladder, per-step table) and the tooltip after the upgrade.
  // State in the URL (?item=&r=&el=&from=&to=&prot=).
  import ItemIcon from "../components/ItemIcon.svelte";
  import ItemTooltip from "../components/ItemTooltip.svelte";
  import { formatChance, formatNumber } from "../lib/format";
  import { buildTooltip, pickRarity, statValue, type ItemDetail, type Lang, type TooltipLabels } from "../lib/item-model";
  import { normalize } from "../lib/search";
  import { expected, firstTryChance } from "../lib/upgrade";

  interface IndexRow { id: string; name: string; type: string; category: string; level: number; rarities: string[]; glyph: string; color: string; icon: string | null; key: string }
  interface Props {
    lang: Lang;
    detail: ItemDetail;
    initial: { rarity: string; element: string | null; from: number; to: number; prot: number | null };
    labels: Record<string, string>;
    tooltip: TooltipLabels;
    indexUrl: string;
    scroll: { name: string; desc: string; glyph: string; color: string; icon: string | null };
  }

  let { lang, detail: initialDetail, initial, labels, tooltip, indexUrl, scroll }: Props = $props();

  let detail = $state<ItemDetail>(initialDetail);
  let rarity = $state(initial.rarity);
  let element = $state<string | null>(initial.element);
  let from = $state(initial.from);
  let to = $state(initial.to);
  let protOn = $state(initial.prot !== null);
  let protFrom = $state(initial.prot ?? initial.from + 1);
  let query = $state("");
  let index = $state<IndexRow[]>([]);
  let listOpen = $state(false);
  let active = $state(0);
  // eslint-disable-next-line svelte/prefer-svelte-reactivity -- a fetch cache, never rendered
  const cache = new Map<string, ItemDetail>([[initialDetail.id, initialDetail]]);
  const fill = (text: string, args: Record<string, string | number>) => text.replace(/\{(\w+)\}/g, (w, k: string) => (k in args ? String(args[k]) : w));

  $effect(() => {
    const p = new URLSearchParams(location.search);
    const id = p.get("item");
    const num = (k: string, lo: number, hi: number) => {
      const v = Number(p.get(k));
      return p.has(k) && Number.isInteger(v) && v >= lo && v <= hi ? v : null;
    };
    const f = num("from", 0, 8);
    const tt = num("to", 1, 9);
    const pr = num("prot", 1, 9);
    if (f !== null) from = f;
    if (tt !== null && tt > from) to = tt;
    if (pr !== null) { protOn = true; protFrom = pr; }
    if (id && id !== detail.id) void load(id, p.get("r"), p.get("el"));
    else {
      if (p.get("r")) rarity = pickRarity(detail, p.get("r"));
      if (p.get("el") && detail.elements?.some((e) => e.id === p.get("el"))) element = p.get("el");
    }
    fetch(indexUrl).then((r) => r.json()).then((rows: IndexRow[]) => (index = rows.filter((r) => r.category === "equipment"))).catch(() => {});
  });

  $effect(() => {
    // eslint-disable-next-line svelte/prefer-svelte-reactivity -- built once per change to write the address
    const url = new URL(location.href);
    url.search = "";
    url.searchParams.set("item", detail.id);
    url.searchParams.set("r", rarity);
    if (element) url.searchParams.set("el", element);
    url.searchParams.set("from", String(from));
    url.searchParams.set("to", String(to));
    if (protOn) url.searchParams.set("prot", String(protFrom));
    if (url.href !== location.href) history.replaceState(null, "", url);
  });

  async function load(id: string, r?: string | null, el?: string | null) {
    let d = cache.get(id);
    if (!d) {
      try {
        d = (await (await fetch(`/data/items/${id}.json`)).json()) as ItemDetail;
        cache.set(id, d);
      } catch {
        return;
      }
    }
    detail = d;
    rarity = pickRarity(d, r ?? rarity);
    element = d.elements ? (d.elements.find((e) => e.id === el)?.id ?? d.elements[0].id) : null;
  }

  const results = $derived(
    query.trim()
      ? index.filter((r) => normalize(query).split(" ").every((w) => r.key.includes(w))).sort((a, b) => b.level - a.level).slice(0, 8)
      : [],
  );
  function choose(row: IndexRow) {
    query = "";
    listOpen = false;
    void load(row.id);
  }
  function onKey(e: KeyboardEvent) {
    if (!results.length) return;
    if (e.key === "ArrowDown") { e.preventDefault(); active = (active + 1) % results.length; listOpen = true; }
    else if (e.key === "ArrowUp") { e.preventDefault(); active = (active - 1 + results.length) % results.length; }
    else if (e.key === "Enter") { e.preventDefault(); choose(results[active]); }
    else if (e.key === "Escape") listOpen = false;
  }

  const steps = $derived(detail.upgrade?.steps ?? []);
  const costs = $derived(detail.upgrade?.costs[rarity] ?? []);
  const protStart = $derived(protOn ? Math.max(from + 1, Math.min(protFrom, to)) : null);
  const result = $derived(steps.length && costs.length ? expected(steps, costs, from, to, protStart) : null);
  const first = $derived(firstTryChance(steps, from, to));
  const tone = $derived(first > 0.5 ? "good" : first > 0.1 ? "mid" : "bad");
  const before = $derived(buildTooltip(detail, { rarity, upgrade: from, lang, element: element ?? undefined }, tooltip));
  const after = $derived(buildTooltip(detail, { rarity, upgrade: to, lang, element: element ?? undefined }, tooltip));
  const compare = $derived((detail.stats[rarity] ?? []).filter((r) => r.key !== "speed" && r.values.length > 1 && r.values.some((v) => v > 0)).slice(0, 2));
  const mats = $derived(Object.entries(result?.materials ?? {}).filter(([, n]) => n > 0.0001));
  const n1 = (v: number) => formatNumber(Math.round(v * 10) / 10, lang);
  const n0 = (v: number) => formatNumber(Math.round(v), lang);
  function setFrom(v: number) { from = Math.max(0, Math.min(8, v)); if (to <= from) to = from + 1; if (protFrom <= from) protFrom = from + 1; }
  function setTo(v: number) { to = Math.max(1, Math.min(9, v)); if (from >= to) from = to - 1; if (protFrom > to) protFrom = to; }
  function gridKeys(e: KeyboardEvent, value: number, lo: number, hi: number, apply: (v: number) => void) {
    const d = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[e.key];
    if (d === undefined) return;
    e.preventDefault();
    const v = Math.max(lo, Math.min(hi, value + d));
    apply(v);
    (e.currentTarget as HTMLElement).closest("[role=radiogroup]")?.querySelectorAll<HTMLElement>("[role=radio]")[v - lo]?.focus();
  }
</script>

<div class="calc">
  <div class="left">
    <section>
      <h2 class="vw-label">{labels.item}</h2>
      <div class="combo">
        <input
          type="text"
          role="combobox"
          aria-expanded={listOpen && results.length > 0}
          aria-controls="calc-results"
          aria-autocomplete="list"
          aria-activedescendant={listOpen && results[active] ? `calc-opt-${results[active].id}` : undefined}
          placeholder={labels.search}
          bind:value={query}
          oninput={() => { listOpen = true; active = 0; }}
          onkeydown={onKey}
        />
        {#if listOpen && results.length > 0}
          <ul class="results" id="calc-results" role="listbox">
            {#each results as r, i (r.id)}
              <li id={`calc-opt-${r.id}`} role="option" aria-selected={i === active}>
                <button type="button" onclick={() => choose(r)}>
                  <ItemIcon glyph={r.glyph} color={r.color} rarity={r.rarities[r.rarities.length - 1]} size={28} src={r.icon} />
                  <span>{r.name}</span><span class="muted">{fill(labels.lv, { level: r.level })}</span>
                </button>
              </li>
            {/each}
          </ul>
        {/if}
      </div>
      <div class="chosen" style={`--c: var(--vw-r-${rarity})`}>
        <ItemIcon glyph={after.glyph} color={after.color} rarity={rarity} size={28} src={after.icon} />
        <span style={`color: var(--vw-r-${rarity}-text)`}>{after.name}</span>
      </div>
      <div class="chips" role="radiogroup" aria-label={labels.rarity}>
        {#each detail.rarities as r (r.key)}
          <button type="button" role="radio" class="vw-chip rchip" style={`--rc: var(--vw-r-${r.key}); --rt: var(--vw-r-${r.key}-text)`} aria-checked={r.key === rarity} onclick={() => (rarity = r.key)}>{r.name[lang]}</button>
        {/each}
      </div>
      {#if detail.elements}
        <div class="chips" role="radiogroup" aria-label={labels.element}>
          {#each detail.elements as el (el.id)}
            <button type="button" role="radio" class="vw-chip" aria-checked={el.id === element} onclick={() => (element = el.id)}>{el.name[lang]}</button>
          {/each}
        </div>
      {/if}
    </section>

    <section>
      <h2 class="vw-label" id="calc-from">{labels.current}</h2>
      <div class="levels from" role="radiogroup" aria-labelledby="calc-from">
        {#each Array.from({ length: 9 }, (_, i) => i) as v (v)}
          <button type="button" role="radio" aria-checked={v === from} tabindex={v === from ? 0 : -1} onclick={() => setFrom(v)} onkeydown={(e) => gridKeys(e, from, 0, 8, setFrom)}>+{v}</button>
        {/each}
      </div>
      <div class="stepper"><button type="button" aria-label={labels.less} onclick={() => setFrom(from - 1)}>−</button><span>+{from}</span><button type="button" aria-label={labels.moreLv} onclick={() => setFrom(from + 1)}>+</button></div>
    </section>
    <section>
      <h2 class="vw-label" id="calc-to">{labels.target}</h2>
      <div class="levels to" role="radiogroup" aria-labelledby="calc-to">
        {#each Array.from({ length: 9 }, (_, i) => i + 1) as v (v)}
          <button type="button" role="radio" aria-checked={v === to} tabindex={v === to ? 0 : -1} onclick={() => setTo(v)} onkeydown={(e) => gridKeys(e, to, 1, 9, setTo)}>+{v}</button>
        {/each}
      </div>
      <div class="stepper"><button type="button" aria-label={labels.less} onclick={() => setTo(to - 1)}>−</button><span>+{to}</span><button type="button" aria-label={labels.moreLv} onclick={() => setTo(to + 1)}>+</button></div>
    </section>

    <section class="prot">
      <label class="protrow">
        <input type="checkbox" bind:checked={protOn} />
        <ItemIcon glyph={scroll.glyph} color={scroll.color} size={36} src={scroll.icon} />
        <span><strong>{scroll.name}</strong><span class="muted small">{scroll.desc}</span><span class="muted small">{labels.protUse}</span></span>
      </label>
      {#if protOn}
        <label class="protfrom">{labels.protFrom}
          <select bind:value={protFrom}>
            {#each Array.from({ length: to - from }, (_, i) => from + 1 + i) as v (v)}<option value={v}>+{v}</option>{/each}
          </select>
        </label>
      {/if}
    </section>
  </div>

  <div class="mid" aria-live="polite">
    <div class="result">
      <div class="big">
        <span class="vw-label">{labels.firstTry}</span>
        <span class={`pct ${tone}`}>{formatChance(first, lang)}</span>
        <span class="muted small">{fill(labels.path, { from, to })}</span>
      </div>
      {#if result}
        <dl class="totals">
          <div><dt>{labels.gold}</dt><dd class="gold">{n0(result.gold)}</dd></div>
          {#each mats as [id, n] (id)}
            {@const m = detail.materials[id]}
            <div><dt><ItemIcon glyph={m?.glyph ?? "◆"} color={m?.color ?? "#999"} rarity={m?.rarity} size={22} src={m?.icon} />{m?.name[lang] ?? id}</dt><dd>{n1(n)}</dd></div>
          {/each}
          <div><dt>{labels.scrolls}</dt><dd>{n1(result.scrolls)}</dd></div>
          <div><dt>{labels.attempts}</dt><dd>{n1(result.attempts)}</dd></div>
        </dl>
      {/if}
    </div>

    <h2 class="vw-label">{labels.ladder}</h2>
    <ol class="ladder">
      {#each steps as s (s.to)}
        {@const inPath = s.to > from && s.to <= to}
        {@const safe = s.failTo === undefined || (protStart !== null && s.to >= protStart)}
        <li class:in={inPath} class:safe class:drop={!safe}>
          <span class="lvl">+{s.to}</span><span class="ch">{formatChance(s.chance, lang)}</span>
        </li>
      {/each}
    </ol>
    <p class="legend"><span class="sw safe"></span>{labels.legendSafe} <span class="sw drop"></span>{labels.legendDrop}</p>

    {#if result}
      <div class="scroll" tabindex="0" role="region" aria-label={labels.ladder}>
      <table class="vw-table steps">
        <caption class="vw-sr">{labels.ladder}</caption>
        <thead><tr><th scope="col">{labels.step}</th><th scope="col">{labels.chance}</th><th scope="col">{labels.avgTries}</th><th scope="col">{labels.gold}</th><th scope="col" class="hide-m">{labels.materials}</th><th scope="col" class="hide-m">{labels.onFail}</th></tr></thead>
        <tbody>
          {#each result.perStep as s (s.to)}
            <tr>
              <td class="strong">+{s.from} → +{s.to}</td>
              <td>{formatChance(s.chance, lang)}</td>
              <td>{n1(s.attempts)}</td>
              <td class="gold">{n0(s.gold)}</td>
              <td class="hide-m mats">
                {#each Object.entries(s.materials).filter(([, n]) => n > 0.0001) as [id, n] (id)}
                  {@const m = detail.materials[id]}
                  <span class="mat" title={m?.name[lang]}><ItemIcon glyph={m?.glyph ?? "◆"} color={m?.color ?? "#999"} rarity={m?.rarity} size={20} src={m?.icon} alt={m?.name[lang]} />{n1(n)}</span>
                {/each}
              </td>
              <td class="hide-m">{s.chance >= 1 || s.failTo === s.from ? labels.noDrop : fill(labels.dropTo, { n: s.failTo })}</td>
            </tr>
          {/each}
        </tbody>
      </table>
      </div>
      <p class="note">{labels.footnote}</p>
    {/if}
  </div>

  <div class="right">
    <h2 class="vw-label">{labels.after}</h2>
    <ItemTooltip data={after} labels={{ bind: labels.bind }} />
    {#if compare.length > 0}
      <dl class="cmp">
        {#each compare as c (c.key)}
          <div><dt>{c.key === "dmg" ? tooltip.dmg : c.key === "mdmg" ? tooltip.mdmg : (c.label?.[lang] ?? c.key)}</dt><dd>{statValue(c, from, lang)} → <strong>{statValue(c, to, lang)}</strong></dd></div>
        {/each}
      </dl>
    {/if}
    <span class="vw-sr">{before.name}</span>
  </div>
</div>

<style>
  .calc { display: grid; grid-template-columns: 330px minmax(0, 1fr) 380px; gap: 28px; align-items: start; }
  section { display: flex; flex-direction: column; gap: 10px; margin-bottom: 24px; }
  h2.vw-label { margin: 0; }
  .muted { color: var(--vw-text-muted); }
  .small { display: block; font-size: 13px; }
  .combo { position: relative; }
  .combo input { width: 100%; height: 48px; padding: 0 14px; background: var(--vw-bg); border: 1px solid var(--vw-gold-dark); color: var(--vw-text); font: 500 16px/1 var(--vw-font-ui); }
  .combo input:focus { outline: none; box-shadow: var(--vw-focus); }
  .results { position: absolute; z-index: 20; left: 0; right: 0; top: 52px; margin: 0; padding: 4px; list-style: none; background: var(--vw-panel-raised); border: 1px solid var(--vw-border); box-shadow: var(--vw-elev-2, 0 10px 30px rgba(0,0,0,.5)); }
  .results button { all: unset; box-sizing: border-box; display: flex; align-items: center; gap: 10px; width: 100%; min-height: 44px; padding: 0 10px; cursor: pointer; }
  .results li[aria-selected="true"] button, .results button:hover { background: rgba(232, 194, 90, .10); }
  .results .muted { margin-left: auto; font-size: 13px; }
  .chosen { display: flex; align-items: center; gap: 10px; min-height: 48px; padding: 0 12px; border: 1px solid var(--c); background: color-mix(in srgb, var(--c) 10%, var(--vw-panel)); font-weight: 800; }
  .chips { display: flex; flex-wrap: wrap; gap: 6px; }
  .rchip { min-height: 40px; color: var(--rt); }
  @media (pointer: coarse) { .rchip { min-height: var(--vw-touch); } }
  .rchip[aria-checked="true"] { background: color-mix(in srgb, var(--rc) 20%, var(--vw-panel)); border-color: var(--rc); font-weight: 800; color: var(--rt); }
  /* S44: the tinted chip of a light colour is too pale for coloured text: dark text in the light theme */
  :global([data-theme="light"]) .rchip[aria-checked="true"] { color: var(--vw-text); }
  .chips [aria-checked="true"]:not(.rchip) { background: var(--vw-gold-bright); color: var(--vw-text-on-gold); }
  .levels { display: grid; grid-template-columns: repeat(5, minmax(0, 1fr)); gap: 6px; }
  .levels button { height: 48px; background: var(--vw-panel); border: 1px solid var(--vw-border); color: var(--vw-text-soft); font: 800 15px/1 var(--vw-font-ui); cursor: pointer; }
  .from button[aria-checked="true"] { background: #EFE7D2; color: #14161B; border-color: #EFE7D2; }
  .to button[aria-checked="true"] { background: linear-gradient(180deg, var(--vw-gold-bright), var(--vw-gold)); color: var(--vw-text-on-gold); border-color: var(--vw-gold-bright); }
  .stepper { display: none; align-items: center; gap: 10px; }
  .stepper button { width: 48px; height: 48px; background: var(--vw-panel); border: 1px solid var(--vw-border); color: var(--vw-gold-bright); font: 800 22px/1 var(--vw-font-ui); cursor: pointer; }
  .stepper span { min-width: 48px; text-align: center; font: 800 22px/1 var(--vw-font-ui); }
  .prot { padding: 16px; background: var(--vw-panel); border: 1px solid var(--vw-border); }
  .protrow { display: flex; align-items: flex-start; gap: 12px; cursor: pointer; }
  .protrow input { width: 20px; height: 20px; margin-top: 8px; accent-color: var(--vw-gold); }
  .protfrom { display: flex; align-items: center; gap: 10px; font-weight: 700; }
  .protfrom select { height: 40px; background: var(--vw-bg); color: var(--vw-text); border: 1px solid var(--vw-border); font: 700 15px/1 var(--vw-font-ui); padding: 0 8px; }
  .result { display: flex; flex-wrap: wrap; gap: 24px 32px; align-items: center; padding: 24px; margin-bottom: 24px; background: var(--vw-metal-gradient, var(--vw-panel)); border: 1px solid var(--vw-gold-dark); }
  .big { display: flex; flex-direction: column; gap: 6px; }
  .pct { font: 800 72px/1 var(--vw-font-ui); }
  .good { color: var(--vw-success); } .mid { color: var(--vw-warning); } .bad { color: var(--vw-danger-text); }
  .totals { display: flex; flex-wrap: wrap; gap: 14px 28px; margin: 0; }
  .totals dt { display: flex; align-items: center; gap: 6px; font-size: 13px; color: var(--vw-text-muted); }
  .totals dd { margin: 4px 0 0; font: 800 26px/1 var(--vw-font-ui); }
  .gold { color: var(--vw-gold-bright); font-weight: 800; }
  .ladder { list-style: none; margin: 10px 0 8px; padding: 0; display: grid; grid-template-columns: repeat(9, minmax(0, 1fr)); gap: 4px; }
  .ladder li { display: flex; flex-direction: column; align-items: center; gap: 6px; padding: 10px 0 0; background: var(--vw-panel); border: 1px solid var(--vw-border-subtle); color: var(--vw-text-muted); --b: var(--vw-warning); }
  .ladder li.safe { --b: var(--vw-success); }
  /* S44: steps outside the path are dimmed by colour, not opacity (text keeps AA contrast) */
  .ladder li.in { border-color: var(--b); color: var(--vw-text); }
  .ladder li:not(.in)::after { opacity: .35; }
  .ladder li::after { content: ""; align-self: stretch; height: 4px; background: var(--b); }
  .lvl { font-weight: 800; }
  .ch { font-size: 14px; }
  .ladder li.in .ch { color: var(--vw-text-soft); }
  .legend { display: flex; align-items: center; gap: 8px; margin: 0 0 20px; font-size: 13px; color: var(--vw-text-muted); }
  .sw { width: 14px; height: 4px; display: inline-block; }
  .sw.safe { background: var(--vw-success); } .sw.drop { background: var(--vw-warning); margin-left: 12px; }
  .scroll { position: relative; max-width: 100%; overflow-x: auto; }
  .steps td { height: 48px; white-space: nowrap; }
  .mats { white-space: normal !important; }
  .mat { display: inline-flex; align-items: center; gap: 4px; margin-right: 8px; font-weight: 700; white-space: nowrap; }
  .mid { min-width: 0; }
  .strong { font-weight: 800; white-space: nowrap; }
  .note { margin: 10px 0 0; font-size: 13px; color: var(--vw-text-muted); }
  .right { position: sticky; top: 90px; display: flex; flex-direction: column; gap: 12px; }
  .cmp { margin: 0; padding: 12px 16px; background: var(--vw-panel); border: 1px solid var(--vw-border); }
  .cmp div { display: flex; justify-content: space-between; gap: 12px; }
  .cmp dt { color: var(--vw-text-muted); }
  .cmp dd { margin: 0; }
  .cmp strong { color: var(--vw-success); }
  @media (max-width: 1279px) { .calc { grid-template-columns: 300px minmax(0, 1fr); } .right { grid-column: 1 / -1; position: static; } }
  @media (max-width: 1023px) {
    .calc { grid-template-columns: minmax(0, 1fr); }
    .levels { display: none; }
    .stepper { display: flex; }
    .pct { font-size: 56px; }
    .ladder { grid-template-columns: repeat(9, minmax(0, 1fr)); }
    .ladder .ch { font-size: 11px; }
    .steps { display: table; width: 100%; } .steps thead { display: table-header-group; } .steps tbody { display: table-row-group; } .steps tr { display: table-row; } .steps td, .steps th { display: table-cell; padding: 0 8px; height: 44px; }
    .steps td.hide-m, .steps th.hide-m { display: none; }
  }
</style>
