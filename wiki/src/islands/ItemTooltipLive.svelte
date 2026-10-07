<script lang="ts">
  // Item page, left column (S40): the beam of light in the rarity colour with the 128 px icon, the item tooltip for
  // the chosen rarity / upgrade / element and the technical frame. State shared with ItemUpgradeView (itemState).
  import ItemIcon from "../components/ItemIcon.svelte";
  import ItemTooltip from "../components/ItemTooltip.svelte";
  import { formatNumber } from "../lib/format";
  import { buildTooltip, type ItemDetail, type Lang, type TooltipLabels } from "../lib/item-model";
  import { itemState, startItemState, type ItemState } from "../lib/itemState";

  interface Props {
    detail: ItemDetail;
    lang: Lang;
    initial: ItemState;
    tooltip: TooltipLabels;
    labels: Record<"bind" | "id" | "binding" | "bindYes" | "bindNo" | "bonuses" | "bonusesFixed" | "random" | "value" | "shop" | "ilvl" | "data" | "noSell", string>;
    shopPrice: number | null;
    dataLine: string;
  }

  let { detail, lang, initial, tooltip, labels, shopPrice, dataLine }: Props = $props();

  let state = $state<ItemState>(initial);
  $effect(() => {
    startItemState(initial, { rarities: detail.rarities.map((r) => r.key), elements: (detail.elements ?? []).map((e) => e.id) });
    return itemState.subscribe((s) => {
      state = s;
      document.querySelector<HTMLElement>("[data-item-page]")?.style.setProperty("--c", `var(--vw-r-${s.rarity})`);
      document.querySelector<HTMLElement>("[data-item-page]")?.style.setProperty("--ct", `var(--vw-r-${s.rarity}-text)`);
    });
  });

  const data = $derived(buildTooltip(detail, { rarity: state.rarity, upgrade: state.up, lang, element: state.element ?? undefined }, tooltip));
  const rarity = $derived(detail.rarities.find((r) => r.key === data.rarity));
  const bonusCount = $derived(
    detail.fixed
      ? `${detail.fixed.length} ${labels.bonusesFixed}`
      : rarity && detail.equipment
        ? `${rarity.bonusMin === rarity.bonusMax ? rarity.bonusMin : `${rarity.bonusMin}–${rarity.bonusMax}`}${rarity.legendaryLines ? ` + ${rarity.legendaryLines}` : ""} ${labels.random}`
        : null,
  );
  const value = $derived(detail.value[data.rarity]?.[data.up]);
</script>

<div class="live" style={`--c: var(--vw-r-${data.rarity}); --g: var(--vw-glow-${data.rarity});`}>
  <div class="stage" aria-hidden="true">
    <div class="vw-beam beam"><span class="glow"></span><span class="core"></span></div>
    <div class="pic"><ItemIcon glyph={data.glyph} color={data.color} rarity={data.rarity} size={128} src={data.icon} /></div>
  </div>
  <ItemTooltip {data} labels={{ bind: labels.bind }} />
  <dl class="tech">
    <div><dt>{labels.id}</dt><dd class="mono">{detail.id}</dd></div>
    <div><dt>{labels.binding}</dt><dd>{detail.bind ? labels.bindYes : labels.bindNo}</dd></div>
    {#if bonusCount}<div><dt>{labels.bonuses}</dt><dd>{bonusCount}</dd></div>{/if}
    {#if value !== undefined && !detail.noSell}<div><dt>{labels.value}</dt><dd>{formatNumber(value, lang)}</dd></div>{/if}
    {#if detail.noSell}<div><dt>{labels.value}</dt><dd>{labels.noSell}</dd></div>{/if}
    {#if shopPrice !== null}<div><dt>{labels.shop}</dt><dd>{formatNumber(shopPrice, lang)}</dd></div>{/if}
    {#if detail.tier !== undefined}<div><dt>{labels.ilvl}</dt><dd>{detail.tier}</dd></div>{/if}
    <div><dt>{labels.data}</dt><dd class="mono small">{dataLine}</dd></div>
  </dl>
</div>

<style>
  .live { display: flex; flex-direction: column; gap: 18px; }
  .stage { position: relative; height: 270px; overflow: hidden; background: radial-gradient(ellipse 50% 40% at 50% 85%, var(--g, transparent), transparent 70%), #14161B; border: 1px solid var(--vw-border); }
  .beam { position: absolute; left: 50%; top: 18px; bottom: 90px; width: 110px; transform: translateX(-50%); }
  .beam .glow { position: absolute; inset: 0; background: linear-gradient(transparent, color-mix(in srgb, var(--c) 70%, transparent) 70%, var(--c)); filter: blur(22px); opacity: .85; }
  .beam .core { position: absolute; left: 50%; top: 10%; bottom: 0; width: 8px; transform: translateX(-50%); background: linear-gradient(transparent, #fff 50%, #fff); filter: blur(2px); }
  .pic { position: absolute; left: 50%; bottom: 36px; transform: translateX(-50%); box-shadow: 0 0 34px color-mix(in srgb, var(--c) 55%, transparent); }
  .live :global(.vw-tooltip) { max-width: none; }
  .tech { margin: 0; background: var(--vw-panel); border: 1px solid var(--vw-border); }
  .tech > div { display: flex; justify-content: space-between; gap: 16px; padding: 10px 16px; border-bottom: 1px solid var(--vw-border-subtle); font-size: 15px; }
  .tech > div:last-child { border-bottom: 0; }
  .tech dt { color: var(--vw-text-muted); }
  .tech dd { margin: 0; font-weight: 800; text-align: right; }
  .mono { font-family: var(--vw-font-mono); font-weight: 500 !important; }
  .small { font-size: 13px; }
  @media (max-width: 767px) { .stage { height: 190px; } .beam { bottom: 70px; } .pic { bottom: 24px; } }
</style>
