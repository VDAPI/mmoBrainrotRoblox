<script lang="ts">
  // Item icon (contract S36): frame in the rarity colour, the item's glyph in its colour on a dark tile. S40 adds
  // `src` (rendered icon from src/generated/item-icons.json); with it the picture replaces the glyph.
  interface Props {
    glyph: string;
    color: string;
    rarity?: string | null;
    size?: number;
    src?: string | null;
    alt?: string;
  }

  let { glyph, color, rarity = null, size = 40, src = null, alt = "" }: Props = $props();
</script>

<span
  class="vw-item-icon vw-tooltip__icon"
  style={`--c: ${rarity ? `var(--vw-r-${rarity})` : "var(--vw-border)"}; width: ${size}px; height: ${size}px; font-size: ${Math.round(size * 0.55)}px; color: ${color};`}
>
  {#if src}
    <img {src} {alt} width={size} height={size} loading="lazy" decoding="async" />
  {:else}
    <span aria-hidden="true">{glyph}</span>
  {/if}
</span>

<style>
  .vw-item-icon { display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0; line-height: 1; font-weight: 800; }
  img { width: 100%; height: 100%; object-fit: contain; }
</style>
