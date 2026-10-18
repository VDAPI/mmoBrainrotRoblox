<script lang="ts">
  // Skill planner v3 of a class page (S148, DESIGN-18 §14): level slider and stepper, one tab per weapon pool (the
  // ladder tree with columns of roles, skill points of the pool, the pool's bar of 8) and a "Directions" tab (talent
  // trees, one capstone per set, the leading direction), the details panel (short text, ranks, numbers at ranks 1 / 5 /
  // 10, breakpoints A/B, nodes that change the skill), build code v3. Rules and view models from src/lib/skills.ts
  // (parity with Logic/SkillPoints and Logic/Paths is tested); data only from props (one class, one language).
  // URL: ?b=<code v3>&s=<skill or node id>&p=<pool id or "directions"> (replaceState after 200 ms), #s-<id> selects
  // too; a v2 code (or older) opens an empty planner with a warning. Without ?b: the maximum level, an empty build, the
  // default pool and its first skill (also the SSR state).
  import { onMount, tick } from "svelte";
  import SkillNode from "../components/SkillNode.svelte";
  import {
    COLUMNS,
    addNodeRank,
    addSkillRank,
    barOf,
    bought,
    bpRank,
    canBuyNode,
    canBuySkill,
    canRefundNode,
    canonical,
    choiceAt,
    columnOf,
    decodeBuild,
    emptyBuild,
    encodeBuild,
    fill,
    freeIn,
    leadingOf,
    nextRankLevel,
    pathFree,
    pathPointsAt,
    pathView,
    planCtx,
    poolTree,
    rankAt,
    rankOf,
    reasonCode,
    setChoice,
    skillPointsAt,
    tileView,
    toggleBar,
    validate,
    variantKey,
    type Option,
    type PlanBuild,
    type PlannerData,
    type PlannerNode,
    type PlannerPath,
    type PlannerSkill,
  } from "../lib/skills";

  let { data }: { data: PlannerData } = $props();

  // Props never change on a page: plain constants keep the code simple.
  // svelte-ignore state_referenced_locally
  const { skills, pools, paths, rules, labels: L, lang, scroll, classColor, defaultPool } = data;
  // svelte-ignore state_referenced_locally
  const ctx = planCtx(data);
  const skillById = new Map(skills.map((s) => [s.id, s]));
  const nodeById = new Map(paths.flatMap((p) => p.rows.flatMap((r) => r.nodes.map((n) => [n.id, { node: n, path: p, row: r.row }] as const))));
  const nodeOfSkill = new Map([...nodeById].filter(([, h]) => h.node.skill).map(([id, h]) => [h.node.skill!, id] as const));
  const trees = new Map(pools.map((p) => [p.id, poolTree(ctx, p.id)]));
  const DIR = "directions";
  const locale = lang === "pl" ? "pl-PL" : "en-US";
  const num = (n: number): string => n.toLocaleString(locale, { maximumFractionDigits: 1 });
  const T = (key: string, args: Record<string, string | number> = {}): string => fill(L[key] ?? key, args);
  const markOf = (scale: number): string => (Math.abs(scale - 1 / 3) < 0.01 ? "⅓" : Math.abs(scale - 0.5) < 0.01 ? "½" : `${Math.round(scale * 100)}%`);
  const firstOf = (poolId: string): string => pools.find((p) => p.id === poolId)?.skills[0] ?? "";

  let build = $state<PlanBuild>(emptyBuild(rules.maxLevel));
  let tab = $state(defaultPool);
  let pathTab = $state(paths[0]?.id ?? "");
  let selected = $state(firstOf(defaultPool));
  let codeText = $state("");
  let codeError = $state<string | null>(null);
  let oldLink = $state(false);
  let editing = $state(false);
  let copied = $state(false);
  let dirty = false;

  const pool = $derived(tab === DIR ? null : (pools.find((p) => p.id === tab) ?? null));
  /** The pool the details work in: the open pool tab, else the last one shown. */
  let lastPool = $state(defaultPool);
  const code = $derived(encodeBuild(ctx, build));
  const check = $derived(validate(ctx, build));
  const unreached = $derived(new Set(check.unreached));
  const views = $derived(new Map(paths.map((p) => [p.id, pathView(ctx, p, build, unreached)])));
  const leading = $derived(leadingOf(ctx, build.nodes));
  const selNode = $derived(nodeById.get(selected) ?? null);
  const selSkill = $derived(skillById.get(selNode?.node.skill ?? selected) ?? null);
  const bar = $derived(barOf(ctx, build, lastPool));

  $effect(() => {
    if (!editing) codeText = code;
  });

  function numbersAt(s: PlannerSkill, rank: number) {
    const r = s.ranks[Math.max(1, rank) - 1];
    const key = variantKey(build, s, rank);
    return key === "aa" ? r : (r.variants?.[key] ?? r);
  }

  function metaOf(s: PlannerSkill, rank: number): string {
    if (s.passive) return L.passive;
    const r = numbersAt(s, Math.max(1, rank));
    const parts = [L.active];
    if (r.cost > 0 && s.resource) parts.push(T(`cost.${s.resource}`, { n: num(r.cost) }));
    if (r.cooldown > 0) parts.push(T("cooldown", { n: num(r.cooldown) }));
    if (s.range) parts.push(T("range", { n: num(s.range) }));
    return parts.join(" · ");
  }

  const roleName = (s: PlannerSkill): string => {
    const column = columnOf(s.role);
    return s.path ? T("pathSkill", { path: s.pathName ?? "" }) : column ? L[`col.${column}`] : "";
  };

  const modifiers = (skillId: string): { node: PlannerNode; path: PlannerPath }[] =>
    [...nodeById.values()].filter((h) => h.node.modify?.skill === skillId).map((h) => ({ node: h.node, path: h.path }));

  // Edits ------------------------------------------------------------------------------------------------------------
  let timer: ReturnType<typeof setTimeout> | undefined;
  function touch(): void {
    // Any edit outside the code field makes the field follow the build again (drops a rejected code).
    editing = false;
    codeError = null;
    dirty = true;
    clearTimeout(timer);
    timer = setTimeout(writeUrl, 200);
  }

  function openTab(id: string): void {
    tab = id;
    if (id !== DIR) lastPool = id;
    touch();
  }

  function select(id: string): void {
    selected = id;
    const hit = nodeById.get(id);
    if (hit) {
      tab = DIR;
      pathTab = hit.path.id;
    }
    touch();
  }

  /** A tile tapped: select it; on a phone the details sit below the tree, so they scroll into view. */
  async function reveal(id: string): Promise<void> {
    select(id);
    if (!matchMedia("(max-width: 767px)").matches) return;
    await tick();
    document.querySelector(".sp-detail")?.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
  }

  function addSkill(id: string): void {
    if (canBuySkill(ctx, build, lastPool, id).ok) build = addSkillRank(build, lastPool, id, 1);
    touch();
  }

  function removeSkill(id: string): void {
    if (bought(build, lastPool, id) > 0) build = addSkillRank(build, lastPool, id, -1);
    touch();
  }

  function flipBar(id: string): void {
    const next = toggleBar(ctx, build, lastPool, id);
    if (next) build = next;
    touch();
  }

  function addNode(id: string): void {
    select(id);
    if (canBuyNode(ctx, build, id).ok) build = addNodeRank(ctx, build, id, 1);
  }

  function removeNode(id: string): void {
    select(id);
    if (canRefundNode(ctx, build, id).ok) build = addNodeRank(ctx, build, id, -1);
  }

  function setLevel(value: number): void {
    const level = Math.min(rules.maxLevel, Math.max(1, Math.round(Number.isFinite(value) ? value : build.level)));
    build = { ...build, level };
    touch();
  }

  function choose(skillId: string, rank: number, option: Option): void {
    if (bpRank(ctx, build, skillId) < rank) return;
    build = setChoice(build, skillId, rank, option);
    touch();
  }

  // URL and code -----------------------------------------------------------------------------------------------------
  function writeUrl(): void {
    if (!dirty || typeof history === "undefined") return;
    const query = `?b=${encodeURIComponent(code)}&s=${encodeURIComponent(selected)}&p=${encodeURIComponent(tab)}`;
    history.replaceState(history.state, "", `${location.pathname}${query}`);
  }

  function loadCode(text: string): boolean {
    const r = decodeBuild(text, ctx);
    if (!r.ok) {
      if (r.error === "old") {
        oldLink = true;
        build = emptyBuild(rules.maxLevel);
        codeError = null;
        return true;
      }
      codeError = T(`err.${r.error}`, { max: rules.maxLevel });
      return false;
    }
    codeError = null;
    oldLink = false;
    build = canonical(ctx, r.build);
    return true;
  }

  function onCodeKey(e: KeyboardEvent): void {
    if (e.key === "Enter") {
      e.preventDefault();
      if (loadCode(codeText)) {
        editing = false;
        touch();
      }
    } else if (e.key === "Escape") {
      editing = false;
      codeError = null;
      codeText = code;
    }
  }

  async function copy(): Promise<void> {
    const link = `${location.origin}${location.pathname}?b=${encodeURIComponent(code)}`;
    try {
      await navigator.clipboard.writeText(link);
    } catch {
      window.prompt(L.copy, link);
    }
    copied = true;
    setTimeout(() => (copied = false), 1500);
  }

  function reset(): void {
    build = emptyBuild(build.level);
    codeError = null;
    oldLink = false;
    editing = false;
    touch();
  }

  // Tabs -------------------------------------------------------------------------------------------------------------
  const tabIds = [...pools.map((p) => p.id), ...(paths.length > 0 ? [DIR] : [])];
  function onTabKey(e: KeyboardEvent): void {
    const i = tabIds.indexOf(tab);
    const next = { ArrowRight: i + 1, ArrowDown: i + 1, ArrowLeft: i - 1, ArrowUp: i - 1, Home: 0, End: tabIds.length - 1 }[e.key];
    if (next === undefined) return;
    e.preventDefault();
    openTab(tabIds[(next + tabIds.length) % tabIds.length]);
    document.getElementById(`sp-tab-${tab}`)?.focus();
  }

  function onTileKey(e: KeyboardEvent, id: string): void {
    if (e.key === "+" || e.key === "=") {
      e.preventDefault();
      select(id);
      addSkill(id);
    } else if (e.key === "-" || e.key === "Delete" || e.key === "Backspace") {
      e.preventDefault();
      select(id);
      removeSkill(id);
    }
  }

  // Direction nodes: pointer and keyboard (as in S41 / S82) --------------------------------------------------------------
  let pointer = "mouse";
  let hold: ReturnType<typeof setTimeout> | undefined;
  let held = false;
  let start = { x: 0, y: 0 };
  const focusNode = (id: string): void => document.querySelector<HTMLButtonElement>(`[data-node="${CSS.escape(id)}"] button`)?.focus();

  function onDown(e: PointerEvent, id: string): void {
    pointer = e.pointerType;
    held = false;
    if (e.pointerType === "touch") {
      start = { x: e.clientX, y: e.clientY };
      clearTimeout(hold);
      hold = setTimeout(() => {
        held = true;
        removeNode(id);
        navigator.vibrate?.(20);
      }, 500);
    }
  }
  function onMove(e: PointerEvent): void {
    if (hold && Math.hypot(e.clientX - start.x, e.clientY - start.y) > 10) clearTimeout(hold);
  }
  function onUp(): void {
    clearTimeout(hold);
  }
  function onClick(e: MouseEvent, id: string): void {
    if (held) {
      held = false;
      return;
    }
    if (pointer === "touch") select(id);
    else if (e.shiftKey) removeNode(id);
    else addNode(id);
    pointer = "mouse";
  }
  function onContext(e: Event, id: string): void {
    e.preventDefault();
    if (pointer !== "touch") removeNode(id);
  }
  function onNodeKey(e: KeyboardEvent, path: PlannerPath, row: number, index: number): void {
    pointer = "keyboard";
    const id = path.rows[row - 1].nodes[index].id;
    const moves: Record<string, [number, number]> = { ArrowLeft: [0, -1], ArrowRight: [0, 1], ArrowUp: [-1, 0], ArrowDown: [1, 0] };
    if (moves[e.key]) {
      e.preventDefault();
      const [dr, di] = moves[e.key];
      const r = path.rows[row - 1 + dr];
      if (!r) return;
      const next = r.nodes[Math.min(Math.max(index + di, 0), r.nodes.length - 1)] ?? r.nodes[0];
      if (next && next.id !== id) {
        select(next.id);
        focusNode(next.id);
      }
    } else if (e.key === "+" || e.key === "=" || e.key === "Enter") {
      e.preventDefault();
      addNode(id);
    } else if (e.key === "-" || e.key === "Delete" || e.key === "Backspace") {
      e.preventDefault();
      removeNode(id);
    }
  }

  function onRadioKey(e: KeyboardEvent, skillId: string, rank: number, hasB: boolean): void {
    const pick = (o: Option): void => {
      e.preventDefault();
      choose(skillId, rank, o);
      document.querySelector<HTMLElement>(`[data-bp="${rank}"] [data-option="${o}"]`)?.focus();
    };
    if (e.key === " " || e.key === "Enter") pick((e.currentTarget as HTMLElement).dataset.option as Option);
    else if (hasB && ["ArrowLeft", "ArrowRight", "ArrowUp", "ArrowDown"].includes(e.key)) pick(choiceAt(build, skillId, rank) === "a" ? "b" : "a");
  }

  /** The pool tab a skill belongs to (its own school, else the pool shown last). */
  const poolFor = (s: PlannerSkill): string => (s.pool && s.pool !== "common" && pools.some((p) => p.id === s.pool) ? s.pool : lastPool);

  onMount(() => {
    const params = new URLSearchParams(location.search);
    const b = params.get("b");
    if (b) loadCode(b);
    const p = params.get("p");
    if (p && tabIds.includes(p)) {
      tab = p;
      if (p !== DIR) lastPool = p;
    }
    const fromHash = /^#s-(.+)$/.exec(location.hash)?.[1];
    const want = params.get("s") ?? (fromHash ? decodeURIComponent(fromHash) : null);
    if (want && (skillById.has(want) || nodeById.has(want))) {
      selected = want;
      const hit = nodeById.get(want);
      if (hit) {
        tab = DIR;
        pathTab = hit.path.id;
      } else if (!p) {
        tab = lastPool = poolFor(skillById.get(want)!);
      }
    }
    // "Plan" links of the skill list select the skill without reloading the page.
    const onPlan = (e: MouseEvent): void => {
      const id = (e.target as HTMLElement | null)?.closest<HTMLAnchorElement>("a[data-plan]")?.dataset.plan;
      if (!id || !skillById.has(id)) return;
      e.preventDefault();
      tab = lastPool = poolFor(skillById.get(id)!);
      selected = id;
      touch();
      document.getElementById("planner")?.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
    };
    document.addEventListener("click", onPlan);
    return () => document.removeEventListener("click", onPlan);
  });

  const optionsOf = (b: string | null): Option[] => (b === null ? ["a"] : ["a", "b"]);
  const stateWord = (state: string): string => L[`state.${state}`] ?? state;
  const whySkill = (reason?: string): string => (reason ? (L[`whySkill.${reasonCode(reason)}`] ?? "") : "");
  const whyNode = (reason?: string): string => (reason ? (L[`whyNode.${reasonCode(reason)}`] ?? "") : "");
  const whyRefund = (reason?: string): string => (reason ? (L[`whyRefund.${reasonCode(reason)}`] ?? "") : "");
  const poolName = (id: string): string => pools.find((p) => p.id === id)?.name ?? id;
</script>

{#snippet tile(id: string)}
  {@const s = skillById.get(id)}
  {#if s && pool}
    {@const v = tileView(ctx, build, pool.id, s)}
    <div class="sp-tile" data-skill={s.id} data-col={columnOf(s.role) ?? "D"}>
      <SkillNode
        glyph={s.glyph}
        pic={s.pic}
        color={s.color}
        state={v.state}
        invalid={v.invalid}
        rank={v.rank}
        max={v.max}
        active={!s.passive}
        capstone={s.role === "U"}
        selected={selected === s.id}
        size={56}
        mark={v.onBar !== null ? String(v.onBar) : null}
        label={T("aria", { name: s.name, rank: v.rank, max: v.max, state: stateWord(v.state) })}
        lockText={v.lockLevel !== null ? T("lockedAt", { n: v.lockLevel }) : null}
        title={`${s.name}: ${s.short}`}
        onclick={() => reveal(s.id)}
        onkeydown={(e: KeyboardEvent) => onTileKey(e, s.id)}
      />
      <span class="sp-tile__name">{s.name}</span>
      <span class="sp-tile__short">{s.short}</span>
      {#if v.bp.length > 0}
        <span class="sp-tile__bps" aria-hidden="true">
          {#each v.bp as bp (bp.rank)}<span class="sp-bpmark" class:is-open={bp.reached}>{bp.rank}{bp.choice.toUpperCase()}</span>{/each}
        </span>
      {/if}
    </div>
  {/if}
{/snippet}

{#snippet skillDetail(s: PlannerSkill)}
  {@const poolId = lastPool}
  {@const rank = rankOf(ctx, build, poolId, s.id)}
  {@const cap = rankAt(s, build.level)}
  {@const has = bought(build, poolId, s.id)}
  {@const buy = canBuySkill(ctx, build, poolId, s.id)}
  {@const onBar = barOf(ctx, build, poolId).includes(s.id)}
  {@const next = nextRankLevel(s, has)}
  {@const best = bpRank(ctx, build, s.id)}
  <div class="sp-detail__head">
    <span class="sp-detail__icon" aria-hidden="true">{#if s.pic}<img src={`${s.pic}-64.webp`} srcset={`${s.pic}-64.webp 1x, ${s.pic}-128.webp 2x`} alt="" width="62" height="62" />{:else}<span style={`color: ${s.color}`}>{s.glyph}</span>{/if}</span>
    <div class="sp-detail__title">
      <h3 id="sp-detail-name">{s.name}</h3>
      <span class="sp-detail__meta">{[roleName(s), metaOf(s, rank)].filter(Boolean).join(" · ")}</span>
      <span class="sp-detail__meta">{poolName(poolId)}</span>
    </div>
  </div>
  <div class="sp-detail__desc">
    <span class="sp-label">{L.whatItDoes}</span>
    <p>{s.short}</p>
  </div>
  {#if s.elementNote}<p class="sp-detail__element">{s.elementNote}</p>{/if}
  <div class="sp-detail__rank">
    <span class="sp-label">{L.rank}</span>
    <span class="sp-detail__note">{has < s.maxLevel ? (next !== null && next > build.level ? T("nextAt", { n: next }) : T("rankLimit", { n: cap })) : L.rankMax}</span>
    <b class:is-partial={rank > 0} class:is-max={rank >= s.maxLevel} class:is-over={has > rank}>{has} / {s.maxLevel}</b>
  </div>
  <div class="sp-detail__actions">
    <button type="button" class="sp-btn sp-btn--big" aria-disabled={has <= 0} aria-label={L.remove} onclick={() => removeSkill(s.id)}>− <span class="sp-desktop">{L.remove}</span></button>
    <button type="button" class="sp-btn sp-btn--big sp-btn--gold" aria-disabled={!buy.ok} title={buy.ok ? undefined : whySkill(buy.reason)} aria-label={`${L.add}${buy.ok ? "" : ` (${whySkill(buy.reason)})`}`} onclick={() => addSkill(s.id)}>+ <span class="sp-desktop">{L.add}</span></button>
  </div>
  {#if !buy.ok && buy.reason}<p class="sp-detail__why">{whySkill(buy.reason)}</p>{/if}
  {#if !s.passive}
    <button type="button" class="sp-btn" aria-disabled={!onBar && (rank <= 0 || bar.length >= rules.barSlots)} onclick={() => flipBar(s.id)}>{onBar ? L.fromBar : rank > 0 && bar.length >= rules.barSlots ? L.barFull : L.toBar}</button>
  {/if}
  <div class="sp-detail__desc">
    <span class="sp-label">{L.current}</span>
    <p>{rank > 0 ? numbersAt(s, rank).desc : L.notLearned}</p>
  </div>
  {#if rank < s.maxLevel}
    <div class="sp-detail__desc">
      <span class="sp-label">{L.next}</span>
      <p class="is-next">{numbersAt(s, rank + 1).desc}</p>
    </div>
  {/if}
  <details class="sp-detail__ranks">
    <summary class="sp-label">{L.atRanks}</summary>
    {#each [...new Set([1, 5, 10, s.maxLevel].filter((r) => r <= s.maxLevel))] as r (r)}
      <p><b>{T("rankN", { n: r })}</b> <small>({T("lockedAt", { n: s.rankLevels[r - 1] })})</small>: {numbersAt(s, r).desc}</p>
    {/each}
  </details>
  {#if s.breakpoints.length > 0}
    {#each s.breakpoints as bp (bp.rank)}
      {@const choice = choiceAt(build, s.id, bp.rank)}
      {@const open = best >= bp.rank}
      <div class="sp-bp" class:is-on={open}>
        <span class="sp-label" id={`sp-bp-${bp.rank}`}>{T("bp", { n: bp.rank })} · {T("bpFrom", { n: bp.level })}</span>
        <div class="sp-bp__opts" role="radiogroup" aria-labelledby={`sp-bp-${bp.rank}`} aria-disabled={!open} data-bp={bp.rank}>
          {#each optionsOf(bp.b) as o (o)}
            <div
              class="sp-bp__opt"
              role="radio"
              tabindex={open && choice === o ? 0 : -1}
              aria-checked={choice === o}
              data-option={o}
              onclick={() => choose(s.id, bp.rank, o)}
              onkeydown={(e) => onRadioKey(e, s.id, bp.rank, bp.b !== null)}
            >
              <b aria-hidden="true">{o.toUpperCase()}</b><span>{o === "a" ? bp.a : bp.b}</span>
            </div>
          {/each}
        </div>
        {#if !open}<p class="sp-detail__hint">{T("bpLocked", { n: bp.rank })}</p>{/if}
      </div>
    {/each}
    <p class="sp-detail__hint">{L.bpHint}</p>
  {:else if !s.passive}
    <p class="sp-detail__hint">{L.bpNone}</p>
  {/if}
  {@const mods = modifiers(s.id)}
  {#if mods.length > 0}
    <div class="sp-detail__mods">
      <span class="sp-label">{L.modifiedBy}</span>
      <ul>
        {#each mods as m (m.node.id)}
          <li><button type="button" class="sp-link" onclick={async () => { select(m.node.id); await tick(); focusNode(m.node.id); }}>{m.node.name}</button> · {m.path.name}</li>
        {/each}
      </ul>
    </div>
  {/if}
  {#if s.path && nodeOfSkill.has(s.id)}
    <p class="sp-detail__hint"><button type="button" class="sp-link" onclick={() => select(nodeOfSkill.get(s.id)!)}>{T("pathSkill", { path: s.pathName ?? "" })}</button></p>
  {/if}
  <p class="sp-detail__hint">{L.modifiedNote}</p>
{/snippet}

{#snippet nodeDetail(hit: { node: PlannerNode; path: PlannerPath; row: number })}
  {@const n = hit.node}
  {@const pv = views.get(hit.path.id)}
  {@const view = pv?.rows[hit.row - 1].nodes.find((x) => x.id === n.id)}
  {@const rank = build.nodes[n.id] ?? 0}
  <div class="sp-detail__head">
    <span class="sp-detail__icon" aria-hidden="true"><span style={`color: ${classColor}`}>{n.glyph}</span></span>
    <div class="sp-detail__title">
      <h3 id="sp-detail-name">{n.name}</h3>
      <span class="sp-detail__meta">{L[`kind.${n.kind}`] ?? n.kind} · {hit.path.name}</span>
    </div>
  </div>
  <div class="sp-detail__rank">
    <span class="sp-label">{L.rank}</span>
    <b class:is-partial={rank > 0} class:is-max={rank >= n.maxRank}>{rank} / {n.maxRank}</b>
  </div>
  {#if view}
    <div class="sp-detail__actions">
      <button type="button" class="sp-btn sp-btn--big" aria-disabled={!view.refund.ok} title={view.refund.ok ? undefined : whyRefund(view.refund.reason)} aria-label={`${L.remove}${view.refund.ok ? "" : ` (${whyRefund(view.refund.reason)})`}`} onclick={() => removeNode(n.id)}>− <span class="sp-desktop">{L.remove}</span></button>
      <button type="button" class="sp-btn sp-btn--big sp-btn--gold" aria-disabled={!view.buy.ok} title={view.buy.ok ? undefined : whyNode(view.buy.reason)} aria-label={`${L.add}${view.buy.ok ? "" : ` (${whyNode(view.buy.reason)})`}`} onclick={() => addNode(n.id)}>+ <span class="sp-desktop">{L.add}</span></button>
    </div>
    {#if !view.buy.ok && view.buy.reason}<p class="sp-detail__why">{whyNode(view.buy.reason)}</p>{/if}
  {/if}
  {#if n.skill && skillById.has(n.skill)}
    {@const s = skillById.get(n.skill)!}
    <div class="sp-detail__desc">
      <span class="sp-label">{L["kind.skill"]}</span>
      <p><button type="button" class="sp-link" onclick={() => { tab = lastPool; select(s.id); }}>{s.name}</button>: {s.short}</p>
    </div>
  {:else}
    {#each [rank, rank + 1] as r, i (i)}
      {@const text = r >= 1 && r <= n.maxRank ? n.ranks[r - 1] : null}
      <div class="sp-detail__desc">
        <span class="sp-label">{i === 0 ? L.current : L.next}</span>
        {#if text && view?.dip && text.dipDesc}
          <p class:is-next={i === 1}>{text.dipDesc}</p>
          <p class="sp-detail__note">{T("dip", { mark: markOf(n.dipScale ?? 1), n: rules.teamFullPoints })} {T("dipFull", { n: rules.teamFullPoints, text: text.desc })}</p>
        {:else if text}
          <p class:is-next={i === 1}>{text.desc}</p>
        {:else}
          <p>{i === 0 ? L.notLearned : L.maxed}</p>
        {/if}
      </div>
    {/each}
    {#if n.modify && skillById.has(n.modify.skill)}
      <p class="sp-detail__element">
        <button type="button" class="sp-link" onclick={() => { tab = lastPool; select(n.modify!.skill); }}>{skillById.get(n.modify.skill)!.name}</button>
      </p>
    {/if}
  {/if}
  {#if n.weapon}<p class="sp-detail__element">{T("nodeWeapon", { w: n.weapon })}</p>{/if}
  <p class="sp-detail__hint">{T("refundHint", { n: rules.freeRespecLevel })} {#if scroll.href}<a href={scroll.href}>{scroll.name}</a>{:else}{scroll.name}{/if}.</p>
{/snippet}

<div class="sp" style={`--sp-class: ${classColor}`}>
  <div class="sp-bar">
    <div class="sp-level">
      <label class="sp-label" for="sp-slider">{L.lvl}</label>
      <input id="sp-slider" class="sp-slider" type="range" min="1" max={rules.maxLevel} value={build.level} aria-label={L.slider} oninput={(e) => setLevel(Number((e.currentTarget as HTMLInputElement).value))} />
      <div class="sp-stepper">
        <button type="button" aria-label={L.lvlDec} disabled={build.level <= 1} onclick={(e) => setLevel(build.level - (e.shiftKey ? 10 : 1))}>−</button>
        <input type="number" min="1" max={rules.maxLevel} value={build.level} aria-label={L.lvl} onchange={(e) => setLevel(Number((e.currentTarget as HTMLInputElement).value))} />
        <button type="button" aria-label={L.lvlInc} disabled={build.level >= rules.maxLevel} onclick={(e) => setLevel(build.level + (e.shiftKey ? 10 : 1))}>+</button>
      </div>
    </div>
    {#if tab !== DIR}
      {@const free = freeIn(ctx, build, lastPool)}
      {@const total = skillPointsAt(rules, build.level)}
      <div class="sp-points">
        <span class="sp-label">{L.skillPoints}</span>
        <span class="sp-points__value" aria-live="polite">
          <span class="vw-sr">{T("skillPointsLive", { free, total })}</span>
          <span aria-hidden="true"><b class:is-zero={free === 0} class:is-over={free < 0}>{free}</b> / {total}</span>
        </span>
      </div>
    {/if}
    {#if paths.length > 0}
      {@const pfree = pathFree(ctx, build)}
      {@const ptotal = pathPointsAt(rules, build.level)}
      <div class="sp-points">
        <span class="sp-label">{L.talentPoints}</span>
        <span class="sp-points__value" aria-live="polite">
          <span class="vw-sr">{T("talentPointsLive", { free: pfree, total: ptotal })}</span>
          <span aria-hidden="true"><b class:is-zero={pfree === 0} class:is-over={pfree < 0}>{pfree}</b> / {ptotal}</span>
        </span>
      </div>
      <div class="sp-leading">
        <span class="sp-label">{L.leading}</span>
        <b>{leading ? (paths.find((p) => p.id === leading)?.name ?? leading) : T("leadingNone", { n: rules.mainMinPoints })}</b>
      </div>
    {/if}
    <div class="sp-code">
      <label class="vw-sr" for="sp-code">{L.code}</label>
      <div class="sp-code__field" class:has-error={codeError !== null}>
        <input
          id="sp-code"
          type="text"
          spellcheck="false"
          autocomplete="off"
          value={codeText}
          aria-invalid={codeError !== null}
          aria-describedby={codeError ? "sp-code-err" : undefined}
          oninput={(e) => { editing = true; codeText = (e.currentTarget as HTMLInputElement).value; }}
          onkeydown={onCodeKey}
          onblur={() => { if (codeError === null) editing = false; }}
        />
        <button type="button" class="sp-btn sp-btn--small" onclick={copy}>{copied ? L.copied : L.copy}</button>
      </div>
      <button type="button" class="sp-btn" onclick={reset}>{L.reset}</button>
      {#if codeError}<p class="sp-code__error" id="sp-code-err" role="alert">{codeError}</p>{/if}
    </div>
  </div>

  {#if oldLink || !check.ok}
    <aside class="vw-callout vw-callout--warn sp-warn">
      <span class="vw-callout__icon" aria-hidden="true"></span>
      <div>
        <span class="vw-callout__title">{L.warn}</span>
        {#if oldLink}<p>{L.old}</p>{/if}
        {#each Object.entries(check.poolsOver) as [id, n] (id)}<p>{T("poolOver", { pool: poolName(id), n })}</p>{/each}
        {#if check.ranksOver.length > 0}<p>{T("ranksOver", { n: check.ranksOver.length })}</p>{/if}
        {#if check.nodesOver > 0}<p>{T("nodesOver", { n: check.nodesOver })}</p>{/if}
        {#if check.unreached.length > 0}<p>{T("unreached", { n: check.unreached.length })}</p>{/if}
      </div>
    </aside>
  {/if}

  <div class="sp-tabs" role="tablist" aria-label={L.tabs} tabindex="-1" onkeydown={onTabKey}>
    {#each pools as p (p.id)}
      <button type="button" role="tab" id={`sp-tab-${p.id}`} data-pool={p.id} aria-selected={tab === p.id} aria-controls="sp-panel" tabindex={tab === p.id ? 0 : -1} onclick={() => openTab(p.id)}>
        <span aria-hidden="true">{p.glyph}</span> {p.name} <small>{T("poolFree", { n: freeIn(ctx, build, p.id) })}</small>
      </button>
    {/each}
    {#if paths.length > 0}
      <button type="button" role="tab" id={`sp-tab-${DIR}`} aria-selected={tab === DIR} aria-controls="sp-panel" tabindex={tab === DIR ? 0 : -1} onclick={() => openTab(DIR)}>
        <span aria-hidden="true">✦</span> {L.directions} <small>{T("poolFree", { n: pathFree(ctx, build) })}</small>
      </button>
    {/if}
  </div>

  <div class="sp-main">
    <div class="sp-panel" id="sp-panel" role="tabpanel" aria-labelledby={`sp-tab-${tab}`}>
      {#if pool}
        {@const tree = trees.get(pool.id)!}
        <header class="sp-path">
          <p>{pool.identity}</p>
          <p class="sp-detail__note">{T("weapons", { w: [pool.weapons.join(", "), pool.element].filter(Boolean).join(" · ") })}</p>
        </header>
        <div class="sp-tree" role="group" aria-label={pool.name}>
          <div class="sp-tree__head" aria-hidden="true">
            <span></span>
            {#each COLUMNS as c (c)}<span>{L[`col.${c}`]}</span>{/each}
          </div>
          {#each tree.rows as row (row.level)}
            <div class="sp-tree__row" class:is-future={row.level > build.level}>
              <span class="sp-tree__level">{T("level", { n: row.level })}</span>
              {#each COLUMNS as c (c)}
                <div class="sp-tree__cell">{#if row.cells[c]}{@render tile(row.cells[c]!)}{/if}</div>
              {/each}
            </div>
          {/each}
          {#each [{ key: "fromDirections", ids: tree.directions }, { key: "others", ids: tree.others }] as extra (extra.key)}
            {#if extra.ids.length > 0}
              <div class="sp-tree__extra">
                <span class="sp-label">{L[extra.key]}</span>
                <div class="sp-tree__list">{#each extra.ids as id (id)}{@render tile(id)}{/each}</div>
              </div>
            {/if}
          {/each}
        </div>
        <div class="sp-barline">
          <span class="sp-label">{T("bar", { n: bar.length, max: rules.barSlots })}</span>
          <ol class="sp-slots">
            {#each Array.from({ length: rules.barSlots }, (_, i) => bar[i] ?? null) as id, i (i)}
              {@const s = id ? skillById.get(id) : null}
              <li>
                {#if s}
                  <button type="button" class="sp-slot" title={T("barRemove", { name: s.name })} aria-label={T("barRemove", { name: s.name })} onclick={() => flipBar(s.id)}>
                    <small>{i + 1}</small><span style={`color: ${s.color}`} aria-hidden="true">{s.glyph}</span><b>{s.name}</b>
                  </button>
                {:else}
                  <span class="sp-slot is-empty"><small>{i + 1}</small><b>{L.barEmpty}</b></span>
                {/if}
              </li>
            {/each}
          </ol>
          <p class="sp-detail__hint">{L.barHint}</p>
        </div>
      {:else if tab === DIR}
        <div class="sp-dirs" role="group" aria-label={L.directions}>
          {#each paths as p (p.id)}
            {@const v = views.get(p.id)}
            <button type="button" class="sp-btn" aria-pressed={pathTab === p.id} onclick={() => (pathTab = p.id)}>
              {p.name} <small>{p.roleName} · {T("pathPoints", { n: v?.points ?? 0 })}</small>
              {#if v?.leading}<span class="sp-badge">{L.isLeading}</span>{/if}
              {#if v?.capstone}<span class="sp-badge">{L.hasCapstone}</span>{/if}
            </button>
          {/each}
        </div>
        <ul class="sp-rules">
          <li>{L.capstoneRule}</li>
          <li>{T("leadingRule", { n: rules.mainMinPoints })}</li>
          <li>{T("dipRule", { rows: rules.dipRows, n: rules.teamFullPoints })}</li>
        </ul>
        {@const p = paths.find((x) => x.id === pathTab) ?? paths[0]}
        {@const v = views.get(p.id)!}
        <header class="sp-path">
          <h3>{p.name} <small>{p.roleName}</small></h3>
          <p>{p.desc}</p>
        </header>
        <ol class="sp-rows">
          {#each p.rows as row (row.row)}
            {@const rv = v.rows[row.row - 1]}
            <li class="sp-row" class:is-closed={!rv.open}>
              <div class="sp-row__head">
                <b>{T("row", { n: row.row, level: row.level })}</b>
                <span>{T("rowNeed", { have: rv.have, need: row.required })}</span>
                {#if rv.reason}<span class="sp-row__why">{T(`rowClosed.${rv.reason}`, { n: rv.reason === "level" ? row.level : row.required })}</span>{/if}
              </div>
              <div class="sp-row__nodes">
                {#each row.nodes as n, i (n.id)}
                  {@const nv = rv.nodes[i]}
                  {#if row.choice && i > 0}<span class="sp-or">{L.or}</span>{/if}
                  <div class="sp-node" data-node={n.id}>
                    <SkillNode
                      glyph={n.glyph}
                      pic={n.skill ? (skillById.get(n.skill)?.pic ?? null) : null}
                      color={n.skill ? (skillById.get(n.skill)?.color ?? classColor) : classColor}
                      state={nv.state}
                      invalid={nv.invalid}
                      rank={nv.rank}
                      max={nv.max}
                      active={n.kind === "skill"}
                      capstone={row.kind === "capstone" || row.kind === "upgrade"}
                      selected={selected === n.id}
                      mark={nv.dip ? markOf(n.dipScale ?? 1) : null}
                      label={T("aria", { name: n.name, rank: nv.rank, max: nv.max, state: stateWord(nv.state) })}
                      lockText={nv.state === "locked" && rv.reason === "level" ? T("rowClosed.level", { n: row.level }) : null}
                      tabindex={selected === n.id || (!nodeById.has(selected) && row.row === 1 && i === 0) ? 0 : -1}
                      title={n.name}
                      onclick={(e: MouseEvent) => onClick(e, n.id)}
                      oncontextmenu={(e: Event) => onContext(e, n.id)}
                      onpointerdown={(e: PointerEvent) => onDown(e, n.id)}
                      onpointermove={onMove}
                      onpointerup={onUp}
                      onpointercancel={onUp}
                      onkeydown={(e: KeyboardEvent) => onNodeKey(e, p, row.row, i)}
                    />
                    <span class="sp-node__name">{n.name}</span>
                  </div>
                {/each}
              </div>
            </li>
          {/each}
        </ol>
      {/if}
    </div>

    <section class="sp-detail" aria-labelledby="sp-detail-name" style={`--sp-accent: ${selSkill?.color ?? classColor}`}>
      {#if selNode && tab === DIR}
        {@render nodeDetail(selNode)}
      {:else if selSkill}
        {@render skillDetail(selSkill)}
      {:else if selNode}
        {@render nodeDetail(selNode)}
      {/if}
    </section>
  </div>
</div>
