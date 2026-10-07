<script lang="ts">
  // Rarity badge (.vw-rarity): name from rarities.json, colour from the data token --vw-r-<key>-text (AA contrast).
  interface Props {
    rarity: string;
    label: string;
  }

  let { rarity, label }: Props = $props();
</script>

<span class="vw-rarity" style={`--c: var(--vw-r-${rarity}-text);`}>{label}</span>
