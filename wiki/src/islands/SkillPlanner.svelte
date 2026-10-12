<script lang="ts">
  // Skill planner placeholder (S56): the old planner left with the skill points (ranks now grow with the character
  // level, ROZWOJ 3.5); S82 builds the new one with class paths. No JS: rendered without a client directive.
  interface Props {
    text: string;
  }

  let { text }: Props = $props();
</script>

<p class="soon">{text}</p>

<style>
  .soon { margin: 0; padding: 18px 20px; font-size: 17px; line-height: 1.5; color: var(--vw-text-soft); background: var(--vw-panel); border: 1px solid var(--vw-border); }
</style>
