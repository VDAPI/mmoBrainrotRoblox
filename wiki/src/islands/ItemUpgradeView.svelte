<script lang="ts">
  // Item page, right column (S40): rarity and element switches, stats by upgrade level (+0..+9 radio buttons, table
  // with chance, failure result and attempt cost) and the bonus pool of the chosen rarity (ranges and chances from
  // the export) or the fixed bonuses. State shared with ItemTooltipLive (itemState, URL ?r=&up=&el=).
  import ItemIcon from "../components/ItemIcon.svelte";
  import { formatChance, formatNumber } from "../lib/format";
  import { bonusText, statValue, type ItemDetail, type Lang, type StatRow } from "../lib/item-model";
  import { itemState, startItemState, type ItemState } from "../lib/itemState";

  type L = Record<
    | "rarity" | "element" | "stats" | "level" | "chance" | "onFail" | "cost" | "base" | "noRisk" | "dropTo" | "protected"
    | "scroll" | "calc" | "pool" | "poolText" | "poolLegendary" | "poolLegendaryText" | "bonus" | "fixed" | "levels"
    | "dmg" | "mdmg" | "caption",
    string
  >;

  interface Props {
    detail: ItemDetail;
    lang: Lang;
    initial: ItemState;
    labels: L;
    calcHref: string | null;
    scrollHref: string | null;
  }

  let { detail, lang, initial, labels, calcHref, scrollHref }: Props = $props();
  let state = $state<ItemState>(initial);
  $effect(() => {
    startItemState(initial, { rarities: detail.rarities.map((r) => r.key), elements: (detail.elements ?? []).map((e) => e.id) });
    return itemState.subscribe((s) => (state = s));
  });

  const fill = (text: string, args: Record<string, string | number>) => text.replace(/\{(\w+)\}/g, (w, k: string) => (k in args ? String(args[k]) : w));
  const set = (patch: Partial<ItemState>) => itemState.update((s) => ({ ...s, ...patch }));

  // Up to two stat columns that change with the upgrade level (weapon damage; armor and health; ...).
  const columns = $derived(
    (detail.stats[state.rarity] ?? []).filter((r: StatRow) => r.key !== "speed" && r.values.length > 1 && r.values.some((v) => v > 0)).slice(0, 2),
  );
  const colLabel = (r: StatRow) => (r.key === "dmg" ? labels.dmg : r.key === "mdmg" ? labels.mdmg : (r.label?.[lang] ?? r.key));
  const costs = $derived(detail.upgrade?.costs[state.rarity] ?? []);
  const rarity = $derived(detail.rarities.find((r) => r.key === state.rarity));
  const range = (b: { range: Record<string, [number, number]> }) => b.range[state.rarity];

  function keyNav(event: KeyboardEvent, count: number, current: number, pick: (i: number) => void) {
    const delta = { ArrowRight: 1, ArrowDown: 1, ArrowLeft: -1, ArrowUp: -1 }[event.key];
    if (delta === undefined) return;
    event.preventDefault();
    const next = (current + delta + count) % count;
    pick(next);
    const group = (event.currentTarget as HTMLElement).closest("[role=radiogroup]");
    group?.querySelectorAll<HTMLElement>("[role=radio]")[next]?.focus();
  }
  const rarityIndex = $derived(detail.rarities.findIndex((r) => r.key === state.rarity));
  const elementIndex = $derived((detail.elements ?? []).findIndex((e) => e.id === state.element));
</script>

<div class="view">
  {#if detail.rarities.length > 1}
    <div class="switch" role="radiogroup" aria-label={labels.rarity}>
      <span class="vw-label">{labels.rarity}</span>
      {#each detail.rarities as r (r.key)}
        <button
          type="button"
          role="radio"
          class="vw-chip rchip"
          style={`--rc: var(--vw-r-${r.key}); --rt: var(--vw-r-${r.key}-text)`}
          aria-checked={r.key === state.rarity}
          tabindex={r.key === state.rarity ? 0 : -1}
          onclick={() => set({ rarity: r.key })}
          onkeydown={(e) => keyNav(e, detail.rarities.length, rarityIndex, (n) => set({ rarity: detail.rarities[n].key }))}
        >{r.name[lang]}</button>
      {/each}
    </div>
  {/if}
  {#if detail.elements}
    <div class="switch" role="radiogroup" aria-label={labels.element}>
      <span class="vw-label">{labels.element}</span>
      {#each detail.elements as el, i (el.id)}
        <button
          type="button"
          role="radio"
          class="vw-chip echip"
          style={`--rc: var(--vw-el-${el.id}); --rt: var(--vw-el-${el.id})`}
          aria-checked={el.id === state.element}
          tabindex={el.id === state.element || (state.element === null && i === 0) ? 0 : -1}
          onclick={() => set({ element: el.id })}
          onkeydown={(e) => keyNav(e, detail.elements!.length, Math.max(0, elementIndex), (n) => set({ element: detail.elements![n].id }))}
        >{el.name[lang]}</button>
      {/each}
    </div>
  {/if}

  {#if detail.upgrade && detail.equipment}
    <section>
      <h2 class="vw-section-title vw-h2">{labels.stats}</h2>
      <div class="ups" role="radiogroup" aria-label={labels.levels}>
        {#each Array.from({ length: 10 }, (_, i) => i) as up (up)}
          <button
            type="button"
            role="radio"
            class="up"
            aria-checked={up === state.up}
            tabindex={up === state.up ? 0 : -1}
            onclick={() => set({ up })}
            onkeydown={(e) => keyNav(e, 10, state.up, (n) => set({ up: n }))}
          >+{up}</button>
        {/each}
      </div>
      <table class="vw-table uptable">
        <caption class="vw-sr">{labels.caption}</caption>
        <thead>
          <tr>
            <th scope="col">{labels.level}</th>
            {#each columns as c (c.key)}<th scope="col">{colLabel(c)}</th>{/each}
            <th scope="col">{labels.chance}</th>
            <th scope="col" class="fail">{labels.onFail}</th>
            <th scope="col" class="cost">{labels.cost}</th>
          </tr>
        </thead>
        <tbody>
          {#each Array.from({ length: 10 }, (_, i) => i) as up (up)}
            {@const step = up > 0 ? detail.upgrade.steps[up - 1] : null}
            {@const cost = up > 0 ? costs[up - 1] : null}
            <tr aria-selected={up === state.up} onclick={() => set({ up })}>
              <td class="lv">+{up}</td>
              {#each columns as c (c.key)}<td class="num">{statValue(c, up, lang)}</td>{/each}
              <td class={step ? (step.chance >= 0.8 ? "good" : step.chance >= 0.5 ? "mid" : "bad") : "muted"}>{step ? formatChance(step.chance, lang) : "—"}</td>
              <td class={`fail ${step ? (step.failTo === undefined ? "good" : "mid") : "muted"}`}>
                {#if !step}{labels.base}{:else if step.failTo === undefined}{labels.noRisk}{:else}{fill(labels.dropTo, { n: step.failTo })}{/if}
              </td>
              <td class="cost">
                {#if cost}
                  <span class="gold">{formatNumber(cost.gold, lang)}</span>
                  {#each cost.materials as m (m.id)}
                    {@const ref = detail.materials[m.id]}
                    <span class="mat" title={ref?.name[lang]}><ItemIcon glyph={ref?.glyph ?? "◆"} color={ref?.color ?? "#999"} rarity={ref?.rarity} size={22} src={ref?.icon} alt={ref?.name[lang]} />×{m.n}</span>
                  {/each}
                {:else}—{/if}
              </td>
            </tr>
          {/each}
        </tbody>
      </table>
      <p class="note">
        {#if scrollHref}<a href={scrollHref}>{labels.scroll}</a>{:else}{labels.scroll}{/if} — {labels.protected}
      </p>
      {#if calcHref}<p><a class="calc" href={`${calcHref}?item=${detail.id}&r=${state.rarity}${state.element ? `&el=${state.element}` : ""}&from=0&to=${state.up || 9}`}>{labels.calc}</a></p>{/if}
    </section>
  {/if}

  {#if detail.fixed}
    <section>
      <h2 class="vw-section-title vw-h2">{labels.fixed}</h2>
      <ul class="fixed">
        {#each detail.fixed as b, i (i)}<li class:legendary={b.legendary}>{b.text[lang]}</li>{/each}
      </ul>
    </section>
  {:else if detail.pool && rarity}
    <section>
      <h2 class="vw-section-title vw-h2">{labels.pool}</h2>
      {#if rarity.bonusMax > 0}
        <p class="lead">{fill(labels.poolText, { n: rarity.bonusMin === rarity.bonusMax ? rarity.bonusMin : `${rarity.bonusMin}–${rarity.bonusMax}` })}{rarity.legendaryLines > 0 ? ` ${fill(labels.poolLegendaryText, { n: rarity.legendaryLines })}` : ""}</p>
      {:else}
        <p class="lead muted">{fill(labels.poolText, { n: 0 })}</p>
      {/if}
      <table class="vw-table pool">
        <caption class="vw-sr">{labels.pool}</caption>
        <thead><tr><th scope="col">{labels.bonus}</th><th scope="col" class="r">{labels.chance}</th></tr></thead>
        <tbody>
          {#each detail.pool.filter((b) => range(b) && (rarity.bonusMax === 0 || b.chance[state.rarity] > 0)) as b (b.id)}
            <tr><td class="bonus">{bonusText(b.name[lang], range(b), lang, b.decimals)}</td><td class="r">{b.chance[state.rarity] ? formatChance(b.chance[state.rarity], lang) : "—"}</td></tr>
          {/each}
        </tbody>
      </table>
      {#if detail.legendaryPool && rarity.legendaryLines > 0}
        <details class="legpool">
          <summary class="vw-label">{labels.poolLegendary}</summary>
          <table class="vw-table pool">
            <caption class="vw-sr">{labels.poolLegendary}</caption>
            <tbody>
              {#each detail.legendaryPool.filter((b) => range(b) && b.chance[state.rarity] > 0) as b (b.id)}
                <tr><td class="bonus leg">{bonusText(b.name[lang], range(b), lang, b.decimals)}</td><td class="r">{b.chance[state.rarity] ? formatChance(b.chance[state.rarity], lang) : "—"}</td></tr>
              {/each}
            </tbody>
          </table>
        </details>
      {/if}
    </section>
  {/if}
</div>

<style>
  .view { display: flex; flex-direction: column; gap: 28px; }
  section { display: flex; flex-direction: column; gap: 14px; }
  section h2 { margin: 0; }
  .switch { display: flex; flex-wrap: wrap; align-items: center; gap: 8px; }
  .switch .vw-label { margin-right: 6px; }
  .rchip, .echip { min-height: 44px; color: var(--rt); border-color: color-mix(in srgb, var(--rc) 45%, var(--vw-border)); }
  .rchip[aria-checked="true"], .echip[aria-checked="true"] { background: color-mix(in srgb, var(--rc) 20%, var(--vw-panel)); border-color: var(--rc); color: var(--rt); font-weight: 800; }
  .ups { display: grid; grid-template-columns: repeat(10, minmax(0, 1fr)); gap: 6px; }
  .up { height: 48px; background: var(--vw-panel); border: 1px solid var(--vw-border); color: var(--vw-text-soft); font: 800 16px/1 var(--vw-font-ui); cursor: pointer; }
  .up:hover { border-color: var(--vw-gold-dark); color: var(--vw-text); }
  .up[aria-checked="true"] { background: linear-gradient(180deg, var(--vw-gold-bright), var(--vw-gold)); border-color: var(--vw-gold-bright); color: var(--vw-text-on-gold); }
  .uptable td { height: 42px; }
  .lv { font-weight: 800; }
  .num { font-weight: 800; font-variant-numeric: tabular-nums; }
  .good { color: var(--vw-success); } .mid { color: var(--vw-warning); } .bad { color: var(--vw-danger); }
  .muted { color: var(--vw-text-muted); }
  .cost { white-space: nowrap; }
  .gold { color: var(--vw-gold-bright); font-weight: 800; margin-right: 8px; }
  .mat { display: inline-flex; align-items: center; gap: 3px; margin-right: 8px; font-size: 14px; font-weight: 700; }
  .note { margin: 0; font-size: 15px; color: var(--vw-text-muted); }
  .calc { font-weight: 800; }
  .lead { margin: 0; color: var(--vw-text-soft); }
  .bonus { color: var(--vw-info); font-weight: 700; }
  .bonus.leg { color: var(--vw-r-legendary-text); }
  .r { text-align: right; font-weight: 800; }
  .legpool summary { cursor: pointer; min-height: 44px; display: flex; align-items: center; }
  .fixed { list-style: none; margin: 0; padding: 0; display: flex; flex-direction: column; gap: 6px; color: var(--vw-info); font-weight: 700; font-size: 17px; }
  .fixed li::before { content: "◆ "; }
  .fixed li.legendary { color: var(--vw-r-legendary-text); }
  @media (max-width: 767px) {
    .ups { grid-template-columns: repeat(5, minmax(0, 1fr)); }
    .uptable { display: table; width: 100%; }
    .uptable thead { display: table-header-group; }
    .uptable tbody { display: table-row-group; }
    .uptable tr { display: table-row; }
    .uptable td, .uptable th { display: table-cell; padding: 0 8px; height: 40px; }
    .uptable .cost, .uptable td.fail, .uptable th.fail { display: none; }
  }
</style>
