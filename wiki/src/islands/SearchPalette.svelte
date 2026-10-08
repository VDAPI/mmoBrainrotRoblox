<script lang="ts">
  // Ctrl+K palette (.vw-palette): Ctrl/Cmd+K or a click on the topbar search field opens it; the entries come from
  // /<lang>/palette.json on first open; matching = src/lib/search.ts (MapSearch rules). Keyboard: ↑↓ select,
  // Enter open (no selection: search page), Tab cycles the type filter, Esc closes. Focus stays inside.
  import { onMount, tick } from "svelte";
  import type { PaletteEntry } from "../lib/palette";
  import { highlight, prepare, search } from "../lib/search";

  interface Props {
    lang: "pl" | "en";
    searchHref: string;
    labels: {
      label: string;
      placeholder: string;
      hint: string;
      close: string;
      all: string;
      pending: string;
      types: Record<string, string>;
    };
  }

  let { lang, searchHref, labels }: Props = $props();

  let open = $state(false);
  let query = $state("");
  let selected = $state(-1);
  let typeFilter = $state<string | null>(null);
  let entries = $state<PaletteEntry[] | null>(null);
  let input: HTMLInputElement | undefined = $state();
  let dialog: HTMLDivElement | undefined = $state();
  let lastFocus: Element | null = null;

  type Item = PaletteEntry & { texts: string[]; rank?: number };
  const index = $derived(entries ? prepare(entries.map((e): Item => ({ ...e, texts: [e.n] }))) : []);
  const types = $derived(entries ? [...new Set(entries.map((e) => e.t))] : []);
  const results = $derived(
    search(typeFilter ? index.filter((i) => i.entry.t === typeFilter) : index, query, 10) as Item[],
  );

  const COLORS: Record<string, string> = {
    item: "var(--vw-gold-bright)",
    monster: "var(--vw-zone-red-text)",
    boss: "var(--vw-zone-red-text)",
    map: "var(--vw-zone-green)",
    area: "var(--vw-zone-green)",
    cave: "var(--vw-zone-green)",
    quest: "var(--vw-accent-text)",
    skill: "var(--vw-exp)",
    class: "var(--vw-exp)",
    npc: "var(--vw-text-soft)",
    guide: "var(--vw-gold)",
    mechanic: "var(--vw-gold)",
  };

  async function show() {
    lastFocus = document.activeElement;
    open = true;
    selected = -1;
    if (!entries) {
      try {
        const response = await fetch(`/${lang}/palette.json`);
        entries = (await response.json()) as PaletteEntry[];
      } catch {
        entries = [];
      }
    }
    await tick();
    input?.focus();
  }

  function hide() {
    open = false;
    (lastFocus as HTMLElement | null)?.focus?.();
  }

  function go(entry: Item | undefined) {
    if (entry?.h) {
      location.href = entry.h;
    } else {
      const q = entry ? entry.n : query;
      location.href = `${searchHref}?q=${encodeURIComponent(q)}`;
    }
  }

  function onKey(event: KeyboardEvent) {
    if (event.key === "Escape") {
      event.preventDefault();
      hide();
    } else if (event.key === "ArrowDown") {
      event.preventDefault();
      selected = Math.min(results.length - 1, selected + 1);
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      selected = Math.max(-1, selected - 1);
    } else if (event.key === "Enter") {
      event.preventDefault();
      go(selected >= 0 ? results[selected] : undefined);
    } else if (event.key === "Tab") {
      // Tab cycles the type filter; the focus never leaves the dialog.
      event.preventDefault();
      const list: (string | null)[] = [null, ...types];
      const i = list.indexOf(typeFilter);
      typeFilter = list[(i + (event.shiftKey ? list.length - 1 : 1)) % list.length];
      selected = -1;
    }
  }

  onMount(() => {
    const onGlobal = (event: KeyboardEvent) => {
      if ((event.ctrlKey || event.metaKey) && event.key.toLowerCase() === "k") {
        event.preventDefault();
        if (open) hide();
        else show();
      }
    };
    window.addEventListener("keydown", onGlobal);
    const openers = [...document.querySelectorAll<HTMLAnchorElement>("[data-palette-open]")].filter(
      (a) => a.offsetParent !== null || a.classList.contains("vw-search"),
    );
    const onClick = (event: MouseEvent) => {
      // Desktop field: palette; the mobile magnifier keeps going to the search page.
      if ((event.currentTarget as HTMLElement).classList.contains("vw-search")) {
        event.preventDefault();
        show();
      }
    };
    openers.forEach((a) => a.addEventListener("click", onClick));
    return () => {
      window.removeEventListener("keydown", onGlobal);
      openers.forEach((a) => a.removeEventListener("click", onClick));
    };
  });
</script>

{#if open}
  <div class="overlay" role="presentation" onclick={hide}></div>
  <div class="vw-palette" role="dialog" aria-modal="true" aria-label={labels.label} bind:this={dialog} onkeydown={onKey} tabindex="-1">
    <div class="field">
      <svg width="18" height="18" viewBox="0 0 20 20" aria-hidden="true"><circle cx="8.5" cy="8.5" r="5.5" fill="none" stroke="currentColor" stroke-width="1.6"></circle><path d="M13 13l4.5 4.5" stroke="currentColor" stroke-width="1.6"></path></svg>
      <input
        bind:this={input}
        bind:value={query}
        oninput={() => (selected = -1)}
        placeholder={labels.placeholder}
        aria-label={labels.label}
        aria-controls="palette-list"
        aria-activedescendant={selected >= 0 ? `palette-${selected}` : undefined}
        autocomplete="off"
        spellcheck="false"
      />
      {#if typeFilter}<span class="filter">{labels.types[typeFilter] ?? typeFilter}</span>{/if}
      <button class="vw-kbd esc" type="button" onclick={hide} aria-label={labels.close}>Esc</button>
    </div>
    <ul id="palette-list" role="listbox">
      {#each results as entry, i (entry.t + entry.id)}
        <li
          id={`palette-${i}`}
          class="vw-palette__item"
          role="option"
          aria-selected={i === selected}
          onclick={() => go(entry)}
          onkeydown={() => {}}
          onmouseenter={() => (selected = i)}
        >
          <span class="type" style={`color: ${COLORS[entry.t] ?? "var(--vw-text-muted)"}`}>{labels.types[entry.t] ?? entry.t}</span>
          <span class="name" style={entry.r ? `color: var(--vw-r-${entry.r}-text)` : undefined}>
            {#each highlight(entry.n, query) as part, p (p)}{#if part.match}<mark>{part.text}</mark>{:else}{part.text}{/if}{/each}
          </span>
          <span class="meta">{entry.h ? entry.m : `${entry.m}${entry.m ? " · " : ""}${labels.pending}`}</span>
          {#if i === selected}<span class="enter" aria-hidden="true">↵</span>{/if}
        </li>
      {/each}
    </ul>
    <p class="hint">{labels.hint}{typeFilter ? "" : ` · ${labels.all}`}</p>
  </div>
{/if}

<style>
  .overlay { position: fixed; inset: 0; z-index: 90; background: var(--vw-overlay); }
  .vw-palette { z-index: 91; outline: none; }
  .field { display: flex; align-items: center; gap: 12px; height: 56px; padding: 0 16px; border-bottom: 1px solid var(--vw-border); color: var(--vw-text-muted); }
  input { flex: 1; min-width: 0; height: 100%; background: none; border: 0; outline: none; color: var(--vw-text); font: 500 18px/1 var(--vw-font-ui); }
  .filter { font: 800 12px/1 var(--vw-font-ui); letter-spacing: .12em; text-transform: uppercase; color: var(--vw-gold-bright); }
  .esc { background: none; cursor: pointer; }
  ul { list-style: none; margin: 0; padding: 4px 0; max-height: 60vh; overflow: auto; }
  .vw-palette__item { cursor: pointer; }
  .type { width: 92px; flex-shrink: 0; font: 800 11px/1 var(--vw-font-ui); letter-spacing: .12em; text-transform: uppercase; }
  .name { font-weight: 800; color: var(--vw-text); }
  .meta { margin-left: auto; font-size: 14px; color: var(--vw-text-muted); }
  .enter { color: var(--vw-gold-bright); }
  mark { background: rgba(232, 194, 90, .22); color: inherit; box-shadow: inset 0 -2px 0 var(--vw-gold-bright); }
  .hint { margin: 0; padding: 10px 16px; border-top: 1px solid var(--vw-border); font-size: 13px; color: var(--vw-text-muted); }
</style>
