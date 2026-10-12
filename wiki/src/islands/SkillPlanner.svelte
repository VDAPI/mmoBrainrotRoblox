<script lang="ts">
  // Skill planner of a class page (S82, ROZWOJ 3.5): level slider and stepper, path points, main path, build code v2,
  // tabs "Base" + one per published path (or "Paths coming soon"), the details panel with breakpoints A/B. Rules and
  // view models from src/lib/skills.ts (parity with Logic/Paths is tested); data only from props (one class, one
  // language). URL: ?b=<code v2>&s=<skill or node id> (replaceState after 200 ms), #s-<id> selects too; an old ?b=
  // opens an empty planner with a warning. Without ?b: the maximum level, an empty build, the first base skill
  // selected (also the SSR state).
  import { onMount, tick } from "svelte";
  import SkillNode from "../components/SkillNode.svelte";
  import {
    addRank,
    baseView,
    canBuy,
    canRefund,
    canSetMain,
    choiceAt,
    decodeBuild,
    emptyBuild,
    encodeBuild,
    fill,
    free,
    pathView,
    pointsAt,
    pruneChoices,
    rankAt,
    reasonCode,
    setChoice,
    setMain,
    validate,
    variantKey,
    type CodeCtx,
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
  const { skills, paths, rules, labels: L, classId, lang, scroll, classColor } = data;
  const skillById = new Map(skills.map((s) => [s.id, s]));
  const nodeById = new Map(paths.flatMap((p) => p.rows.flatMap((r) => r.nodes.map((n) => [n.id, { node: n, path: p, row: r.row }] as const))));
  const base = skills.filter((s) => !s.path);
  /** Skill node of each path skill (its A/B choices travel with the node in the code). */
  const nodeOfSkill = new Map([...nodeById].filter(([, h]) => h.node.skill).map(([id, h]) => [h.node.skill!, id] as const));
  const ctx: CodeCtx = { classId, maxLevel: rules.maxLevel, skills, paths };
  const locale = lang === "pl" ? "pl-PL" : "en-US";
  const num = (n: number): string => n.toLocaleString(locale, { maximumFractionDigits: 1 });
  const T = (key: string, args: Record<string, string | number> = {}): string => fill(L[key] ?? key, args);
  const lastRow = paths[0]?.rows.length ?? 11;
  const markOf = (scale: number): string => (Math.abs(scale - 1 / 3) < 0.01 ? "⅓" : Math.abs(scale - 0.5) < 0.01 ? "½" : `${Math.round(scale * 100)}%`);

  let build = $state<PlanBuild>(emptyBuild(rules.maxLevel));
  let tab = $state("base");
  let selected = $state(base[0]?.id ?? "");
  let codeText = $state("");
  let codeError = $state<string | null>(null);
  let oldLink = $state(false);
  let editing = $state(false);
  let copied = $state(false);
  let dirty = false;

  const code = $derived(encodeBuild(ctx, build));
  const total = $derived(pointsAt(rules, build.level));
  const freePts = $derived(free(paths, rules, build));
  const check = $derived(validate(paths, rules, build));
  const baseRows = $derived(baseView(base, build));
  const views = $derived(new Map(paths.map((p) => [p.id, pathView(p, paths, rules, build)])));
  const mainPath = $derived(paths.find((p) => p.id === build.main) ?? null);
  const selNode = $derived(nodeById.get(selected) ?? null);
  const selSkill = $derived(skillById.get(selNode?.node.skill ?? selected) ?? null);

  $effect(() => {
    if (!editing) codeText = code;
  });

  /** Rank of a skill now: the base from the level; a path skill with its node bought and its row working. */
  function skillRank(s: PlannerSkill): number {
    if (!s.path) return rankAt(s, build.level);
    for (const [id, hit] of nodeById) {
      if (hit.node.skill !== s.id) continue;
      if ((build.nodes[id] ?? 0) <= 0) return 0;
      if (hit.row > rules.dipRows && build.main !== hit.path.id) return 0;
      const row = hit.path.rows[hit.row - 1];
      return build.level >= row.level ? rankAt(s, build.level) : 0;
    }
    return 0;
  }

  function numbersAt(s: PlannerSkill, rank: number) {
    const r = s.ranks[rank - 1];
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

  const modifiers = (skillId: string): { node: PlannerNode; path: PlannerPath }[] =>
    [...nodeById.values()].filter((h) => h.node.modify?.skill === skillId).map((h) => ({ node: h.node, path: h.path }));

  // Edits ------------------------------------------------------------------------------------------------------------
  function touch(): void {
    // Any edit outside the code field makes the field follow the build again (drops a rejected code).
    editing = false;
    codeError = null;
    dirty = true;
    clearTimeout(timer);
    timer = setTimeout(writeUrl, 200);
  }

  function select(id: string): void {
    selected = id;
    const hit = nodeById.get(id);
    if (hit) tab = hit.path.id;
    touch();
  }

  function add(id: string): void {
    select(id);
    if (canBuy(paths, rules, build, id).ok) build = addRank(build, id, 1);
  }

  function remove(id: string): void {
    select(id);
    if (canRefund(paths, rules, build, id).ok) build = pruneChoices(paths, addRank(build, id, -1));
  }

  function setLevel(value: number): void {
    const level = Math.min(rules.maxLevel, Math.max(1, Math.round(Number.isFinite(value) ? value : build.level)));
    build = { ...build, level };
    touch();
  }

  /** A path skill's A/B can be chosen only with its node bought (the code carries it in the node digit). */
  const canChoose = (skillId: string): boolean => {
    const node = nodeOfSkill.get(skillId);
    return node === undefined || (build.nodes[node] ?? 0) > 0;
  };

  function choose(skillId: string, rank: number, option: Option): void {
    if (!canChoose(skillId)) return;
    build = setChoice(build, skillId, rank, option);
    touch();
  }

  function makeMain(pathId: string | null): void {
    build = pruneChoices(paths, setMain(paths, rules, build, pathId));
    touch();
  }

  // URL and code -----------------------------------------------------------------------------------------------------
  let timer: ReturnType<typeof setTimeout> | undefined;
  function writeUrl(): void {
    if (!dirty || typeof history === "undefined") return;
    const query = `?b=${encodeURIComponent(code)}&s=${encodeURIComponent(selected)}`;
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
    build = r.build;
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
  const tabIds = ["base", ...(paths.length > 0 ? paths.map((p) => p.id) : ["soon"])];
  function onTabKey(e: KeyboardEvent): void {
    const i = tabIds.indexOf(tab);
    const next = { ArrowRight: i + 1, ArrowDown: i + 1, ArrowLeft: i - 1, ArrowUp: i - 1, Home: 0, End: tabIds.length - 1 }[e.key];
    if (next === undefined) return;
    e.preventDefault();
    tab = tabIds[(next + tabIds.length) % tabIds.length];
    document.getElementById(`sp-tab-${tab}`)?.focus();
  }

  // Nodes: pointer and keyboard (as in S41) ----------------------------------------------------------------------------
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
        remove(id);
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
    else if (e.shiftKey) remove(id);
    else add(id);
    pointer = "mouse";
  }
  function onContext(e: Event, id: string): void {
    e.preventDefault();
    if (pointer !== "touch") remove(id);
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
      add(id);
    } else if (e.key === "-" || e.key === "Delete" || e.key === "Backspace") {
      e.preventDefault();
      remove(id);
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

  onMount(() => {
    const params = new URLSearchParams(location.search);
    const b = params.get("b");
    if (b) loadCode(b);
    const fromHash = /^#s-(.+)$/.exec(location.hash)?.[1];
    const want = params.get("s") ?? (fromHash ? decodeURIComponent(fromHash) : null);
    if (want && (skillById.has(want) || nodeById.has(want))) {
      selected = nodeOfSkill.get(want) ?? want;
      const hit = nodeById.get(selected);
      if (hit) tab = hit.path.id;
    }
    // "Plan" links of the skill list select the skill without reloading the page.
    const onPlan = (e: MouseEvent): void => {
      const id = (e.target as HTMLElement | null)?.closest<HTMLAnchorElement>("a[data-plan]")?.dataset.plan;
      if (!id || !skillById.has(id)) return;
      e.preventDefault();
      const s = skillById.get(id)!;
      select(nodeOfSkill.get(id) ?? id);
      tab = s.path ?? "base";
      document.getElementById("planner")?.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
    };
    document.addEventListener("click", onPlan);
    return () => document.removeEventListener("click", onPlan);
  });

  const optionsOf = (b: string | null): Option[] => (b === null ? ["a"] : ["a", "b"]);
  const stateWord = (state: string): string => L[`state.${state}`] ?? state;
  const whyBuy = (reason?: string): string => (reason ? L[`why.${reasonCode(reason)}`] : "");
  const whyRefund = (reason?: string): string => (reason ? L[`whyRefund.${reasonCode(reason)}`] : "");
  const weaponLine = (p: PlannerPath): string => {
    const main = p.weapon.main.join(" / ");
    const off = p.weapon.offhand.join(" / ");
    return main || off ? [main, off].filter(Boolean).join(" + ") : L.weaponAny;
  };
  const mainHint = $derived(T("mainHint", { from: rules.dipRows + 1, to: lastRow }).split("{scroll}"));
</script>

{#snippet skillDetail(s: PlannerSkill)}
  {@const rank = skillRank(s)}
  <div class="sp-detail__head">
    <span class="sp-detail__icon" aria-hidden="true">{#if s.pic}<img src={`${s.pic}-64.webp`} srcset={`${s.pic}-64.webp 1x, ${s.pic}-128.webp 2x`} alt="" width="62" height="62" />{:else}<span style={`color: ${s.color}`}>{s.glyph}</span>{/if}</span>
    <div class="sp-detail__title">
      <h3 id="sp-detail-name">{s.name}</h3>
      <span class="sp-detail__meta">{metaOf(s, rank)}</span>
      {#if s.pathName}<span class="sp-detail__meta">{T("pathSkill", { path: s.pathName })}</span>{/if}
    </div>
  </div>
  {#if s.elementNote}<p class="sp-detail__element">{s.elementNote}</p>{/if}
  <div class="sp-detail__rank">
    <span class="sp-label">{L.rank}</span>
    <b class:is-partial={rank > 0} class:is-max={rank >= s.maxLevel}>{rank} / {s.maxLevel}</b>
  </div>
  <div class="sp-detail__desc">
    <span class="sp-label">{L.current}</span>
    <p>{rank > 0 ? numbersAt(s, rank).desc : L.notLearned}</p>
  </div>
  <div class="sp-detail__desc">
    <span class="sp-label">{L.next}</span>
    {#if rank < s.maxLevel}
      <p class="is-next">{numbersAt(s, rank + 1).desc}</p>
      <p class="sp-detail__note">{T("nextAt", { n: s.rankLevels[rank] })}</p>
    {:else}
      <p>{L.maxed}</p>
    {/if}
  </div>
  {#if s.breakpoints.length > 0}
    {@const open = canChoose(s.id)}
    {#each s.breakpoints as bp (bp.rank)}
      {@const choice = choiceAt(build, s.id, bp.rank)}
      <div class="sp-bp" class:is-on={build.level >= bp.level}>
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
      </div>
    {/each}
    <p class="sp-detail__hint">{open ? L.bpHint : L.bpNode}</p>
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
      <p class="sp-detail__hint">{L.modifiedNote}</p>
    </div>
  {/if}
{/snippet}

{#snippet nodeDetail(hit: { node: PlannerNode; path: PlannerPath; row: number })}
  {@const n = hit.node}
  {@const view = views.get(hit.path.id)?.rows[hit.row - 1].nodes.find((x) => x.id === n.id)}
  {@const rank = build.nodes[n.id] ?? 0}
  {#if n.skill && skillById.has(n.skill)}
    {@render skillDetail(skillById.get(n.skill)!)}
  {:else}
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
    {#each [rank, rank + 1] as r, i (i)}
      {@const text = r >= 1 && r <= n.maxRank ? n.ranks[r - 1] : null}
      <div class="sp-detail__desc">
        <span class="sp-label">{i === 0 ? L.current : L.next}</span>
        {#if text && view?.dip && text.dipDesc}
          <p class:is-next={i === 1}>{text.dipDesc}</p>
          <p class="sp-detail__note">{T("dip", { mark: markOf(n.dipScale ?? 1) })} {T("dipMain", { text: text.desc })}</p>
        {:else if text}
          <p class:is-next={i === 1}>{text.desc}</p>
        {:else}
          <p>{i === 0 ? L.notLearned : L.maxed}</p>
        {/if}
      </div>
    {/each}
    {#if n.modify && skillById.has(n.modify.skill)}
      <p class="sp-detail__element">
        <button type="button" class="sp-link" onclick={() => select(n.modify!.skill)}>{skillById.get(n.modify.skill)!.name}</button>
      </p>
    {/if}
  {/if}
  {#if n.weapon}<p class="sp-detail__element">{T("nodeWeapon", { w: n.weapon })}</p>{/if}
  {#if view}
    <div class="sp-detail__actions">
      <button type="button" class="sp-btn sp-btn--big" aria-disabled={!view.refund.ok} title={view.refund.ok ? undefined : whyRefund(view.refund.reason)} aria-label={`${L.remove}${view.refund.ok ? "" : ` (${whyRefund(view.refund.reason)})`}`} onclick={() => remove(n.id)}>− <span class="sp-desktop">{L.remove}</span></button>
      <button type="button" class="sp-btn sp-btn--big sp-btn--gold" aria-disabled={!view.buy.ok} title={view.buy.ok ? undefined : whyBuy(view.buy.reason)} aria-label={`${L.add}${view.buy.ok ? "" : ` (${whyBuy(view.buy.reason)})`}`} onclick={() => add(n.id)}>+ <span class="sp-desktop">{L.add}</span></button>
    </div>
    {#if !view.buy.ok && view.buy.reason}<p class="sp-detail__why">{whyBuy(view.buy.reason)}</p>{/if}
  {/if}
  <p class="sp-detail__hint">{L.hint} {#if scroll.href}<a href={scroll.href}>{scroll.name}</a>{:else}{scroll.name}{/if}.</p>
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
    <div class="sp-points">
      <span class="sp-label">{L.points}</span>
      <span class="sp-points__value" aria-live="polite">
        <span class="vw-sr">{T("pointsLive", { free: freePts, total })}</span>
        <span aria-hidden="true"><b class:is-zero={freePts === 0} class:is-over={freePts < 0}>{freePts}</b> / {total}</span>
      </span>
    </div>
    <div class="sp-main-path">
      <span class="sp-label">{L.main}</span>
      <b>{mainPath ? mainPath.name : L.mainNone}</b>
    </div>
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

  {#if oldLink || check.over > 0 || check.unreached.length > 0 || !check.mainOk}
    <aside class="vw-callout vw-callout--warn sp-warn">
      <span class="vw-callout__icon" aria-hidden="true"></span>
      <div>
        <span class="vw-callout__title">{L.warn}</span>
        {#if oldLink}<p>{L.old}</p>{/if}
        {#if check.over > 0}<p>{T("over", { n: check.over })}</p>{/if}
        {#if check.unreached.length > 0}<p>{T("unreached", { n: check.unreached.length })}</p>{/if}
        {#if !check.mainOk}<p>{T("mainLow", { n: rules.mainPathLevel })}</p>{/if}
      </div>
    </aside>
  {/if}

  <div class="sp-tabs" role="tablist" aria-label={L.tabs} tabindex="-1" onkeydown={onTabKey}>
    <button type="button" role="tab" id="sp-tab-base" aria-selected={tab === "base"} aria-controls="sp-panel" tabindex={tab === "base" ? 0 : -1} onclick={() => (tab = "base")}>{L.base}</button>
    {#each paths as p (p.id)}
      {@const v = views.get(p.id)}
      <button type="button" role="tab" id={`sp-tab-${p.id}`} data-path={p.id} aria-selected={tab === p.id} aria-controls="sp-panel" tabindex={tab === p.id ? 0 : -1} onclick={() => (tab = p.id)}>
        {p.name} <small>{p.roleName} · {T("pathPoints", { n: v?.points ?? 0 })}</small>
        {#if build.main === p.id}<span class="sp-badge">{L.isMain}</span>{/if}
      </button>
    {/each}
    {#if paths.length === 0}
      <button type="button" role="tab" id="sp-tab-soon" aria-selected={tab === "soon"} aria-controls="sp-panel" tabindex={tab === "soon" ? 0 : -1} onclick={() => (tab = "soon")}>{L.paths}</button>
    {/if}
  </div>

  <div class="sp-main">
    <div class="sp-panel" id="sp-panel" role="tabpanel" aria-labelledby={`sp-tab-${tab}`}>
      {#if tab === "base"}
        <ul class="sp-list">
          {#each baseRows as row (row.id)}
            {@const s = skillById.get(row.id)!}
            <li data-skill={s.id}>
              <button type="button" class="sp-item" aria-pressed={selected === s.id} onclick={() => select(s.id)}>
                <span class="sp-item__icon" style={`color: ${s.color}`} aria-hidden="true">{#if s.pic}<img src={`${s.pic}-64.webp`} srcset={`${s.pic}-64.webp 1x, ${s.pic}-128.webp 2x`} alt="" width="40" height="40" loading="lazy" />{:else}{s.glyph}{/if}</span>
                <span class="sp-item__text">
                  <b>{s.name}</b>
                  <small>{L.rank} <span class="sp-rank">{row.rank}/{row.max}</span> · {row.next === null ? L.rankMax : T("nextAt", { n: row.next })}</small>
                </span>
                <span class="sp-item__bps" aria-hidden="true">
                  {#each row.bp as bp (bp.rank)}
                    <span class="sp-bpmark" class:is-open={bp.open}>{bp.rank}{bp.choice.toUpperCase()}</span>
                  {/each}
                </span>
              </button>
            </li>
          {/each}
        </ul>
      {:else if tab === "soon"}
        <div class="sp-soon">
          <h3>{L.soon}</h3>
          <p>{T("soonText", { every: rules.pathPointsEvery, first: rules.firstRowLevel, dip: rules.dipRows, main: rules.mainPathLevel, cap: rules.capstoneLevel })}</p>
        </div>
      {:else}
        {@const p = paths.find((x) => x.id === tab)!}
        {@const v = views.get(p.id)!}
        <header class="sp-path">
          <h3>{p.name} <small>{p.roleName}</small></h3>
          <p>{p.desc}</p>
          <p class="sp-path__weapon"><span class="sp-label">{L.weapon}</span> {weaponLine(p)}. {T("weaponRows", { from: rules.dipRows + 1, to: lastRow })}</p>
          <div class="sp-path__main">
            {#if v.isMain}
              <span class="sp-badge">{L.main}</span>
              <button type="button" class="sp-btn sp-btn--small" onclick={() => makeMain(null)}>{L.unsetMain}</button>
            {:else if canSetMain(rules, build)}
              <button type="button" class="sp-btn sp-btn--gold" onclick={() => makeMain(p.id)}>{L.setMain}</button>
            {:else}
              <span class="sp-detail__note">{T("mainFrom", { n: rules.mainPathLevel })}</span>
            {/if}
            <span class="sp-detail__hint">{mainHint[0]}{#if scroll.href}<a href={scroll.href}>{scroll.name}</a>{:else}{scroll.name}{/if}{mainHint[1] ?? ""}</span>
          </div>
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
      {#if selNode}
        {@render nodeDetail(selNode)}
      {:else if selSkill}
        {@render skillDetail(selSkill)}
      {/if}
    </section>
  </div>
</div>
