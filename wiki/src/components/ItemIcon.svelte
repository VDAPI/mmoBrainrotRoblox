<script lang="ts">
  // Item icon (contract S36, S40: pictures): frame in the rarity colour; `src` is the base URL of a generated icon
  // (src/lib/icons.ts iconFor: "/img/items/<file>", files -64.webp / -128.webp) — sizes up to 64 px take the 64 file
  // with the 128 one for 2x screens, bigger ones the 128 file. Without `src` the item's glyph in its colour.
  import { iconSources } from "../lib/item-model";

  interface Props {
    glyph: string;
    color: string;
    rarity?: string | null;
    size?: number;
    src?: string | null;
    alt?: string;
  }

  let { glyph, color, rarity = null, size = 40, src = null, alt = "" }: Props = $props();
  const pic = $derived(iconSources(src, size));
</script>

<span
  class="vw-item-icon vw-tooltip__icon"
  class:has-pic={pic !== null}
  style={`--c: ${rarity ? `var(--vw-r-${rarity})` : "var(--vw-border)"}; width: ${size}px; height: ${size}px; font-size: ${Math.round(size * 0.55)}px; color: ${color};${pic ? ` padding: ${Math.max(1, Math.round(size * 0.08))}px;` : ""}`}
>
  {#if pic}
    <img src={pic.src} srcset={pic.srcset} {alt} width={size} height={size} loading="lazy" decoding="async" />
  {:else}
    <span aria-hidden="true">{glyph}</span>
  {/if}
</span>

<style>
  .vw-item-icon { display: inline-flex; align-items: center; justify-content: center; flex-shrink: 0; line-height: 1; font-weight: 800; overflow: hidden; }
  img { display: block; width: 100%; height: 100%; min-width: 0; object-fit: contain; }
</style>
