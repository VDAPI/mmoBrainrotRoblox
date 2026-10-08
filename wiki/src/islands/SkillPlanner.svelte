<script lang="ts">
  // Skill planner of a class page (S41, mock-up Mag-*): level stepper, points, build code, the 4×6 tree with the
  // requirement edges and the details panel. Rules from src/lib/skills.ts (parity with Skills.canLearn is tested);
  // data only from props (one class, one language). URL: ?b=<code>&s=<skillId> (replaceState after 200 ms), #s-<id>
  // selects too. Without ?b: the maximum level, an empty tree, the first skill selected (also the SSR state).
  import { onMount } from "svelte";
  import SkillNode from "../components/SkillNode.svelte";
  import {
    canAdd,
    canRemove,
    decodeBuild,
    dependents,
    encodeBuild,
    fill,
    maxReachableRank,
    nodeState,
    pointsAt,
    rankLevel,
    requiredCharLevel,
    spent,
    validate,
    type AddResult,
    type Build,
    type PlannerData,
    type PlannerSkill,
  } from "../lib/skills";

  let { data }: { data: PlannerData } = $props();

  // Props never change on a page: plain constants keep the code simple.
  // svelte-ignore state_referenced_locally
  const { skills, rules, labels: L, classId, lang, scroll, classColor } = data;
  const byId = new Map(skills.map((s) => [s.id, s]));
  const rows = Math.max(...skills.map((s) => s.row));
  const cols = Math.max(4, ...skills.map((s) => s.col));
  const rowMin = Array.from({ length: rows }, (_, i) => Math.min(...skills.filter((s) => s.row === i + 1).map((s) => s.unlock)));
  const ROW_H = 84;
  const locale = lang === "pl" ? "pl-PL" : "en-US";
  const num = (n: number): string => n.toLocaleString(locale, { maximumFractionDigits: 1 });
  const T = (key: string, args: Record<string, string | number> = {}): string => fill(L[key] ?? key, args);

  let level = $state(rules.maxLevel);
  let build = $state<Build>({});
  let selected = $state(skills[0].id);
  let codeText = $state("");
  let codeError = $state<string | null>(null);
  let editing = $state(false);
  let copied = $state(false);
  let dirty = false;
  let pitch = $state(120);
  let gridWidth = $state(640);
  const focusNode = (id: string, options?: { preventScroll?: boolean }): void =>
    document.querySelector<HTMLButtonElement>(`#sp-node-${CSS.escape(id)} button`)?.focus(options);

  const total = $derived(pointsAt(rules, level));
  const freePts = $derived(total - spent(build));
  const check = $derived(validate(skills, rules, build, level));
  const needLevel = $derived(requiredCharLevel(skills, rules, build));
  const code = $derived(encodeBuild(classId, level, skills, build));
  const sums = $derived({
    active: skills.filter((s) => !s.passive).reduce((n, s) => n + (build[s.id] ?? 0), 0),
    passive: skills.filter((s) => s.passive).reduce((n, s) => n + (build[s.id] ?? 0), 0),
  });
  const sel = $derived(byId.get(selected) ?? skills[0]);
  const selRank = $derived(build[sel.id] ?? 0);
  const selAdd = $derived(canAdd(rules, build, level, sel));
  const selCanRemove = $derived(canRemove(skills, build, sel.id));

  $effect(() => {
    if (!editing) {
      codeText = code;
    }
  });

  // Edges: one per requirement, centre to centre in a 100-units-per-column view box; an edge passing under another
  // node of the same column bends around it (half a node + 8 px).
  interface Edge { key: string; d: string; met: boolean; x: number; y: number; level: number }
  const centerY = (row: number): number => (row - 1) * pitch + ROW_H / 2;
  const edges = $derived.by((): Edge[] => {
    const unit = gridWidth / (cols * 100);
    const bend = (pitch < 120 ? 36 : 40) / Math.max(unit, 0.01);
    const out: Edge[] = [];
    for (const to of skills) {
      for (const req of to.requires) {
        const from = byId.get(req.skill);
        if (!from) continue;
        const x1 = (from.col - 0.5) * 100, y1 = centerY(from.row), x2 = (to.col - 0.5) * 100, y2 = centerY(to.row);
        const lo = Math.min(from.row, to.row), hi = Math.max(from.row, to.row);
        const blocked = from.col === to.col && skills.some((s) => s.col === from.col && s.row > lo && s.row < hi);
        let d = `M${x1} ${y1}L${x2} ${y2}`;
        let x = (x1 + x2) / 2;
        if (blocked) {
          const dir = from.col >= cols ? -1 : 1;
          const k = (dir * bend) / 0.75;
          const dy = y2 - y1;
          d = `M${x1} ${y1}C${x1 + k} ${y1 + dy * 0.25} ${x2 + k} ${y2 - dy * 0.25} ${x2} ${y2}`;
          x += dir * bend;
        }
        out.push({ key: `${from.id}-${to.id}`, d, met: (build[from.id] ?? 0) >= req.level, x, y: (y1 + y2) / 2, level: req.level });
      }
    }
    return out;
  });
  const svgHeight = $derived(rows * pitch - (pitch - ROW_H));

  function stateWord(s: PlannerSkill): string {
    const ns = nodeState(build, level, s);
    if (ns.invalid) return L["state.invalid"];
    if (ns.state === "max") return L["state.max"];
    if (ns.state === "locked") return L["state.locked"];
    return canAdd(rules, build, level, s).ok ? L["state.available"] : L["state.unavailable"];
  }

  function why(r: AddResult): string {
    if (r.reason === "level") return T("why.level", { n: r.detail as number });
    if (r.reason === "requires") {
      const req = r.detail as { skill: string; level: number };
      return T("why.requires", { name: byId.get(req.skill)?.name ?? req.skill, n: req.level });
    }
    return r.reason ? T(`why.${r.reason}`) : "";
  }

  function removeWhy(s: PlannerSkill): string {
    if ((build[s.id] ?? 0) === 0) return T("why.empty");
    const dep = dependents(skills, build, s.id)[0];
    return dep ? T("why.needed", { name: dep.name }) : "";
  }

  function add(s: PlannerSkill): void {
    selected = s.id;
    if (canAdd(rules, build, level, s).ok) {
      build = { ...build, [s.id]: (build[s.id] ?? 0) + 1 };
    }
    touch();
  }

  function remove(s: PlannerSkill): void {
    selected = s.id;
    if (canRemove(skills, build, s.id)) {
      const next = { ...build, [s.id]: (build[s.id] ?? 0) - 1 };
      if (next[s.id] <= 0) delete next[s.id];
      build = next;
    }
    touch();
  }

  function select(id: string): void {
    selected = id;
    touch();
  }

  function setLevel(value: number): void {
    level = Math.min(rules.maxLevel, Math.max(1, Math.round(Number.isFinite(value) ? value : level)));
    touch();
  }

  // URL state ------------------------------------------------------------------------------------------------------
  let timer: ReturnType<typeof setTimeout> | undefined;
  function touch(): void {
    dirty = true;
    clearTimeout(timer);
    timer = setTimeout(writeUrl, 200);
  }
  function writeUrl(): void {
    if (!dirty || typeof history === "undefined") return;
    const query = `?b=${encodeURIComponent(code)}&s=${encodeURIComponent(selected)}`;
    history.replaceState(history.state, "", `${location.pathname}${query}`);
  }
  function shareUrl(): string {
    return `${location.origin}${location.pathname}?b=${encodeURIComponent(code)}`;
  }

  function loadCode(text: string): boolean {
    const r = decodeBuild(text, classId, skills, rules);
    if (!r.ok) {
      codeError = T(`err.${r.error}`, { max: rules.maxLevel });
      return false;
    }
    codeError = null;
    level = r.level;
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
    const link = shareUrl();
    try {
      await navigator.clipboard.writeText(link);
    } catch {
      window.prompt(L.copy, link);
    }
    copied = true;
    setTimeout(() => (copied = false), 1500);
  }

  function reset(): void {
    build = {};
    codeError = null;
    editing = false;
    touch();
  }

  // Pointer and keyboard on nodes ------------------------------------------------------------------------------------
  let pointer = "mouse";
  let hold: ReturnType<typeof setTimeout> | undefined;
  let held = false;
  let start = { x: 0, y: 0 };

  function onDown(e: PointerEvent, s: PlannerSkill): void {
    pointer = e.pointerType;
    held = false;
    if (e.pointerType === "touch") {
      start = { x: e.clientX, y: e.clientY };
      clearTimeout(hold);
      hold = setTimeout(() => {
        held = true;
        remove(s);
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
  function onClick(e: MouseEvent, s: PlannerSkill): void {
    if (held) {
      held = false;
      return;
    }
    if (pointer === "touch") {
      select(s.id);
    } else if (e.shiftKey) {
      remove(s);
    } else {
      add(s);
    }
    pointer = "mouse";
  }
  function onContext(e: Event, s: PlannerSkill): void {
    e.preventDefault();
    if (pointer !== "touch") remove(s);
  }

  function neighbour(s: PlannerSkill, dc: number, dr: number): PlannerSkill | undefined {
    let best: PlannerSkill | undefined;
    let score = Infinity;
    for (const o of skills) {
      const c = o.col - s.col, r = o.row - s.row;
      if (dc !== 0 ? Math.sign(c) !== dc : Math.sign(r) !== dr) continue;
      const v = dc !== 0 ? Math.abs(c) + 10 * Math.abs(r) : 10 * Math.abs(r) + Math.abs(c);
      if (v < score) { score = v; best = o; }
    }
    return best;
  }

  function onKey(e: KeyboardEvent, s: PlannerSkill): void {
    pointer = "keyboard";
    const moves: Record<string, [number, number]> = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
    if (moves[e.key]) {
      e.preventDefault();
      const next = neighbour(s, ...moves[e.key]);
      if (next) {
        select(next.id);
        focusNode(next.id);
      }
    } else if (e.key === "+" || e.key === "=" || e.key === "Enter") {
      e.preventDefault();
      add(s);
    } else if (e.key === "-" || e.key === "Delete" || e.key === "Backspace") {
      e.preventDefault();
      remove(s);
    }
  }

  onMount(() => {
    const params = new URLSearchParams(location.search);
    const b = params.get("b");
    if (b) loadCode(b);
    const fromHash = /^#s-(.+)$/.exec(location.hash)?.[1];
    const want = params.get("s") ?? (fromHash ? decodeURIComponent(fromHash) : null);
    if (want && byId.has(want)) selected = want;
    const mq = window.matchMedia("(max-width: 767px)");
    const fit = (): void => { pitch = mq.matches ? 114 : 120; };
    fit();
    mq.addEventListener("change", fit);
    // "Plan" links of the skill list select the node without reloading the page.
    const onPlan = (e: MouseEvent): void => {
      const link = (e.target as HTMLElement | null)?.closest<HTMLAnchorElement>("a[data-plan]");
      const id = link?.dataset.plan;
      if (!id || !byId.has(id)) return;
      e.preventDefault();
      select(id);
      document.getElementById("planner")?.scrollIntoView({ behavior: matchMedia("(prefers-reduced-motion: reduce)").matches ? "auto" : "smooth" });
      focusNode(id, { preventScroll: true });
    };
    document.addEventListener("click", onPlan);
    return () => {
      mq.removeEventListener("change", fit);
      document.removeEventListener("click", onPlan);
    };
  });

  const metaOf = (s: PlannerSkill, rank: number): string => {
    if (s.passive) return L.passive;
    const r = s.ranks[Math.max(1, rank) - 1];
    const parts = [L.active];
    if (r.cost > 0 && s.resource) parts.push(T(`cost.${s.resource}`, { n: num(r.cost) }));
    if (r.cooldown > 0) parts.push(T("cooldown", { n: num(r.cooldown) }));
    if (s.range) parts.push(T("range", { n: num(s.range) }));
    return parts.join(" · ");
  };
</script>

{#snippet codeBox(where: string)}
  <div class={`sp-code sp-code--${where}`}>
    <label class="vw-sr" for={`sp-code-${where}`}>{L.code}</label>
    <div class="sp-code__field" class:has-error={codeError !== null}>
      <input
        id={`sp-code-${where}`}
        type="text"
        spellcheck="false"
        autocomplete="off"
        value={codeText}
        aria-invalid={codeError !== null}
        aria-describedby={codeError ? `sp-code-err-${where}` : undefined}
        oninput={(e) => { editing = true; codeText = (e.currentTarget as HTMLInputElement).value; }}
        onkeydown={onCodeKey}
        onblur={() => { if (codeError === null) editing = false; }}
      />
      <button type="button" class="sp-btn sp-btn--small" onclick={copy}>{copied ? L.copied : L.copy}</button>
    </div>
    <button type="button" class="sp-btn" onclick={reset}>{L.reset}</button>
    {#if codeError}<p class="sp-code__error" id={`sp-code-err-${where}`} role="alert">{codeError}</p>{/if}
  </div>
{/snippet}

<div class="sp" style={`--sp-class: ${classColor}`}>
  <div class="sp-bar">
    <div class="sp-level">
      <span class="sp-label sp-desktop" id="sp-level-label">{L.lvl}</span>
      <div class="sp-stepper">
        <button type="button" aria-label={L.lvlDec} disabled={level <= 1} onclick={(e) => setLevel(level - (e.shiftKey ? 10 : 1))}>−</button>
        <span class="sp-mobile sp-lvlshort" aria-hidden="true">{L.lvlShort}</span>
        <input
          type="number"
          min="1"
          max={rules.maxLevel}
          value={level}
          aria-labelledby="sp-level-label"
          onchange={(e) => setLevel(Number((e.currentTarget as HTMLInputElement).value))}
        />
        <button type="button" aria-label={L.lvlInc} disabled={level >= rules.maxLevel} onclick={(e) => setLevel(level + (e.shiftKey ? 10 : 1))}>+</button>
      </div>
    </div>
    <div class="sp-points">
      <span class="sp-label sp-desktop">{L.points}</span>
      <span class="sp-points__value" aria-live="polite">
        <span class="vw-sr">{T("live", { free: Math.max(0, freePts), total })}</span>
        <span aria-hidden="true"><b class:is-zero={freePts <= 0}>{Math.max(0, freePts)}</b><span class="sp-desktop"> / {total}</span><span class="sp-mobile">&nbsp;{L.ptsFree}</span></span>
      </span>
    </div>
    <div class="sp-sum">
      <span><i class="sp-diamond" aria-hidden="true"></i>{L.sumActive} <b>{sums.active}</b></span>
      <span><i class="sp-diamond sp-diamond--soft" aria-hidden="true"></i>{L.sumPassive} <b>{sums.passive}</b></span>
      <span class="sp-need">{needLevel === null ? L.requiredNone : T("required", { n: needLevel })}</span>
    </div>
    {@render codeBox("bar")}
  </div>

  {#if check.over > 0 || check.tooHigh.length > 0}
    <aside class="vw-callout vw-callout--warn sp-warn">
      <span class="vw-callout__icon" aria-hidden="true"></span>
      <div>
        <span class="vw-callout__title">{L.warn}</span>
        {#if check.over > 0}<p>{T("over", { n: check.over })}</p>{/if}
        {#if check.tooHigh.length > 0}<p>{T("tooHigh", { n: check.tooHigh.length })}</p>{/if}
      </div>
    </aside>
  {/if}

  <div class="sp-main">
    <div class="sp-tree" role="group" aria-label={L.tree} style={`--sp-rows: ${rows}; --sp-cols: ${cols}`}>
      <div class="sp-rowlabels" aria-hidden="true">
        {#each rowMin as min, i (i)}
          <div class="sp-rowlabel" class:is-reached={level >= min}>
            {#if i === 0}<b>{T("rowLevel", { n: min })}</b><span>{L.rowStart}</span>{:else}<b>{T("rowFrom", { n: min })}</b>{/if}
          </div>
        {/each}
      </div>
      <div class="sp-grid" bind:clientWidth={gridWidth}>
        <svg class="sp-edges" viewBox={`0 0 ${cols * 100} ${svgHeight}`} preserveAspectRatio="none" aria-hidden="true" style={`height: ${svgHeight}px`}>
          {#each edges as e (e.key)}
            <path d={e.d} class:is-met={e.met} vector-effect="non-scaling-stroke" />
          {/each}
        </svg>
        {#each edges as e (e.key)}
          <span class="sp-badge" class:is-met={e.met} aria-hidden="true" style={`left: ${(e.x / (cols * 100)) * 100}%; top: ${e.y}px`}>≥{e.level}</span>
        {/each}
        {#each skills as s (s.id)}
          {@const ns = nodeState(build, level, s)}
          {@const rank = build[s.id] ?? 0}
          <div class="sp-cell" style={`grid-column: ${s.col}; grid-row: ${s.row}`} id={`sp-node-${s.id}`}>
            <SkillNode
              glyph={s.glyph}
              color={s.color}
              state={ns.state}
              invalid={ns.invalid}
              {rank}
              max={s.maxLevel}
              active={!s.passive}
              capstone={s.row === rows}
              selected={selected === s.id}
              label={T("aria", { name: s.name, rank, max: s.maxLevel, state: stateWord(s) })}
              lockText={ns.state === "locked" ? T("lockLv", { n: Math.max(s.unlock, ...s.requires.map((r) => rankLevel(byId.get(r.skill) ?? s, r.level))) }) : null}
              tabindex={selected === s.id ? 0 : -1}
              title={s.name}
              onclick={(e: MouseEvent) => onClick(e, s)}
              oncontextmenu={(e: Event) => onContext(e, s)}
              onpointerdown={(e: PointerEvent) => onDown(e, s)}
              onpointermove={onMove}
              onpointerup={onUp}
              onpointercancel={onUp}
              onkeydown={(e: KeyboardEvent) => onKey(e, s)}
            />
          </div>
        {/each}
      </div>
    </div>

    <section class="sp-detail" aria-labelledby="sp-detail-name" style={`--sp-accent: ${sel.color}`}>
      <div class="sp-detail__head">
        <span class="sp-detail__icon" data-state={nodeState(build, level, sel).state} aria-hidden="true"><span style={`color: ${sel.color}`}>{sel.glyph}</span></span>
        <div class="sp-detail__title">
          <h3 id="sp-detail-name">{sel.name}<span class="sp-mobile sp-detail__rk"> {selRank}/{sel.maxLevel}</span></h3>
          <span class="sp-detail__meta">{metaOf(sel, selRank)}</span>
        </div>
      </div>
      {#if sel.elementNote}<p class="sp-detail__element">{sel.elementNote}</p>{/if}
      <div class="sp-detail__rank sp-desktop-flex">
        <span class="sp-label">{L.rank}</span>
        <b class:is-partial={selRank > 0} class:is-max={selRank >= sel.maxLevel}>{selRank} / {sel.maxLevel}</b>
      </div>
      <div class="sp-detail__desc">
        <span class="sp-label">{L.current}</span>
        <p>{selRank > 0 ? sel.ranks[selRank - 1].desc : L.notLearned}</p>
      </div>
      <div class="sp-detail__desc">
        <span class="sp-label">{L.next}</span>
        {#if selRank < sel.maxLevel}
          <p class="is-next">{sel.ranks[selRank].desc}</p>
        {:else}
          <p>{L.maxed}</p>
        {/if}
        {#if maxReachableRank(sel, rules.maxLevel) < sel.maxLevel}
          <p class="sp-detail__note">{T("reachable", { rank: maxReachableRank(sel, rules.maxLevel), level: rules.maxLevel })}</p>
        {/if}
      </div>
      {#if sel.breakpoints.length > 0}
        <div class="sp-detail__bps">
          <span class="sp-label">{L.breakpoints}</span>
          {#each sel.breakpoints as bp (bp.level)}
            <p class:is-on={selRank >= bp.level}><b>{T("bp", { n: bp.level })}:</b> {bp.text}</p>
          {/each}
        </div>
      {/if}
      {#if selRank < sel.maxLevel}
        <div class="sp-detail__reqs">
          <span class="sp-label">{L.req}</span>
          <ul>
            <li class:is-ok={level >= rankLevel(sel, selRank + 1)}>{T("reqLevel", { n: rankLevel(sel, selRank + 1) })}</li>
            {#each sel.requires as req (req.skill)}
              <li class:is-ok={(build[req.skill] ?? 0) >= req.level}>
                <button type="button" class="sp-link" onclick={() => { select(req.skill); focusNode(req.skill); }}>
                  {T("reqSkill", { name: byId.get(req.skill)?.name ?? req.skill, n: req.level })}
                </button>
              </li>
            {/each}
            <li class:is-ok={freePts >= 1}>{L.reqFree}</li>
          </ul>
        </div>
      {/if}
      <div class="sp-detail__actions">
        <button
          type="button"
          class="sp-btn sp-btn--big"
          aria-disabled={!selCanRemove}
          title={selCanRemove ? undefined : removeWhy(sel)}
          aria-label={`${L.remove}${selCanRemove ? "" : ` (${removeWhy(sel)})`}`}
          onclick={() => remove(sel)}
        >− <span class="sp-desktop">{L.remove}</span></button>
        <button
          type="button"
          class="sp-btn sp-btn--big sp-btn--gold"
          aria-disabled={!selAdd.ok}
          title={selAdd.ok ? undefined : why(selAdd)}
          aria-label={`${L.add}${selAdd.ok ? "" : ` (${why(selAdd)})`}`}
          onclick={() => add(sel)}
        >+ <span class="sp-desktop">{L.add}</span></button>
      </div>
      <p class="sp-detail__hint">
        {L.hint}
        {#if scroll.href}<a href={scroll.href}>{scroll.name}</a>{:else}{scroll.name}{/if}.
      </p>
    </section>
  </div>
  {@render codeBox("bottom")}
</div>
