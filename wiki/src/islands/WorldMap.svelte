<script lang="ts">
  // World map island (S37, Mapa-* mock-ups). The page renders the world SVG inside #vw-stage > #vw-pan; this island
  // adds pan / zoom (@panzoom/panzoom), loads a map's SVG on demand (/img/maps/<id>.svg, cached), selection with a
  // card (desktop: left panel, mobile: bottom sheet), layers, legend, search (MapSearch rules, src/lib/search.ts)
  // and the address ?m=&a=&x=&z=&s= (src/lib/deeplink.ts). Data: /<lang>/map-data.json.
  import type { PanzoomObject } from "@panzoom/panzoom";
  import { onMount, tick } from "svelte";
  import { parse, serialize, type MapLink } from "../lib/deeplink";
  import type { MapData } from "../lib/mapdata.types";
  import { prepare, search } from "../lib/search";

  interface Props {
    lang: "pl" | "en";
    labels: Record<string, string>;
  }
  let { lang, labels }: Props = $props();
  const L = (key: string, args?: Record<string, string | number>) =>
    (labels[key] ?? key).replace(/\{(\w+)\}/g, (w, n: string) => (args && n in args ? String(args[n]) : w));

  type Layer = "zones" | "bosses" | "portals" | "quests" | "npcs" | "gather";
  const LAYERS: Layer[] = ["zones", "bosses", "portals", "quests", "npcs", "gather"];
  const DEFAULT_ON: Layer[] = ["zones", "bosses", "portals", "npcs"];
  const LAYER_COLOR: Record<Layer, string> = { zones: "#e8c25a", bosses: "#e0503f", portals: "#4a8be8", quests: "#5fcf6b", npcs: "#e8c25a", gather: "#6fcf5a" };
  const KIND_RANK: Record<string, number> = { npc: 1, map: 2, cave: 3, area: 4, boss: 5, monster: 6, node: 7 };

  let data = $state<MapData | null>(null);
  let mapId = $state<string | null>(null); // null = world
  let selected = $state<string | null>(null); // svg element id (area-…, node-…)
  let layersOn = $state<Set<Layer>>(new Set(DEFAULT_ON));
  let counts = $state<Record<string, number>>({});
  let query = $state("");
  let searchOpen = $state(false);
  let sheet = $state<"closed" | "peek" | "full">("closed");
  let copied = $state(false);
  let loading = $state(false);
  let mobile = $state(false);
  // S44: the overlay stays hidden until hydrated (its layout depends on the screen width known only in the browser),
  // so it appears once instead of jumping from the desktop to the phone layout (CLS).
  let ready = $state(false);

  let stage: HTMLElement;
  let pan: HTMLElement;
  let pz: PanzoomObject | null = null;
  // loaded in the browser only (the package has no ESM default export for SSR)
  let Panzoom: typeof import("@panzoom/panzoom").default | null = null;
  // eslint-disable-next-line svelte/prefer-svelte-reactivity -- local value, not reactive state
  const svgCache = new Map<string, string>();
  let worldHtml = "";
  let pin: { x: number; z: number } | null = null;
  let urlTimer: ReturnType<typeof setTimeout> | undefined;

  const reduced = () => matchMedia("(prefers-reduced-motion: reduce)").matches;

  // ---- data helpers -------------------------------------------------------------------------------------------
  const index = $derived(data ? prepare(data.search.map((e) => ({ ...e, rank: KIND_RANK[e.kind] ?? 9 }))) : []);
  const results = $derived(data && query.trim() ? search(index, query, data.limit) : []);

  function levels(min: number, max: number): string {
    return min === max ? L("level", { level: min }) : L("levelRangeCap", { min, max });
  }
  function respawn(min: number, max: number): string {
    const m = (v: number) => v >= 120;
    const f = (v: number) => (m(v) ? `${Math.round(v / 60)} min` : `${v} s`);
    if (min === max) return f(min);
    return m(min) === m(max) ? (m(min) ? `${Math.round(min / 60)}–${Math.round(max / 60)} min` : `${min}–${max} s`) : `${f(min)} – ${f(max)}`;
  }
  const monsterName = (id: string, rank = 0) => data?.monsters[id]?.[rank] || data?.monsters[id]?.[0] || id;

  type Sel = { type: string; id: string };
  function parseSel(id: string | null): Sel | null {
    if (!id) return null;
    const m = /^(area|cave|portal|npc|boss|node|group)-(.+)$/.exec(id);
    return m ? { type: m[1], id: m[2] } : null;
  }
  const sel = $derived(parseSel(selected));

  // ---- svg / panzoom ------------------------------------------------------------------------------------------
  function svgEl(): SVGSVGElement | null {
    return pan?.querySelector("svg") ?? null;
  }
  function viewBox() {
    const vb = svgEl()?.viewBox.baseVal;
    return vb ? { x: vb.x, y: vb.y, w: vb.width, h: vb.height } : { x: 0, y: 0, w: 1, h: 1 };
  }
  // content box of the svg inside the stage (preserveAspectRatio meet)
  function content() {
    const vb = viewBox();
    const W = pan.clientWidth;
    const H = pan.clientHeight;
    const f = Math.min(W / vb.w, H / vb.h);
    return { f, ox: (W - vb.w * f) / 2, oy: (H - vb.h * f) / 2, W, H, vb };
  }
  let lastScale = -1;
  let frame = 0;
  function applyScale(scale: number) {
    if (scale === lastScale) return;
    lastScale = scale;
    cancelAnimationFrame(frame);
    frame = requestAnimationFrame(() => {
      const c = content();
      const world = mapId === null;
      // markers and labels a bit smaller on phones (the mock-up shows short labels there)
      const shrink = mobile ? (world ? 0.6 : 0.85) : 1;
      stage.style.setProperty("--k", String(shrink / (c.f * scale)));
      stage.dataset.lod = world ? (scale < 1.4 && mobile ? "1" : "2") : scale < 1.8 ? "1" : scale < 3.5 ? "2" : "3";
    });
  }

  function setupPanzoom() {
    pz?.destroy();
    if (!Panzoom) return;
    pz = Panzoom(pan, {
      maxScale: mapId === null ? 8 : 10,
      minScale: 0.4,
      startScale: 1,
      contain: undefined,
      animate: !reduced(),
      duration: 220,
      cursor: "grab",
      canvas: true,
    });

    lastScale = -1;
    applyScale(1);
  }

  const PANEL = 428; // desktop panel width + gaps (px)

  function centerOn(x: number, z: number, scale: number, animate = true, panelShift?: number) {
    if (!pz) return;
    const c = content();
    const px = c.ox + (x - c.vb.x) * c.f;
    const py = c.oy + (z - c.vb.y) * c.f;
    // keep the point in the free part right of the desktop panel
    const shift = panelShift ?? (!mobile ? PANEL / 2 : 0);
    const shiftY = mobile && sheet !== "closed" ? -c.H * 0.22 : 0;
    const toX = c.W / 2 - px + shift / scale;
    const toY = c.H / 2 - py + shiftY / scale;
    const instance = pz;
    instance.zoom(scale, { animate: false });
    // panzoom applies transforms in requestAnimationFrame: pan in the next frame so the zoom does not overwrite it
    requestAnimationFrame(() => instance.pan(toX, toY, { animate: animate && !reduced(), force: true }));
    applyScale(scale);
  }

  // Whole map in view; on desktop in the part not covered by the panel.
  function fit(animate = true) {
    if (!pz) return;
    if (mobile) {
      pz.reset({ animate: animate && !reduced() });
      applyScale(1);
      return;
    }
    const c = content();
    const s = Math.min(1, (c.W - PANEL - 24) / (c.vb.w * c.f), c.H / (c.vb.h * c.f));
    centerOn(c.vb.x + c.vb.w / 2, c.vb.y + c.vb.h / 2, s, animate, PANEL / 2 - 12);
  }

  function elementCentre(id: string): { x: number; z: number } | null {
    const el = svgEl()?.querySelector<SVGGraphicsElement>(`[id="${id}"]`);
    if (!el) return null;
    const t = el.getAttribute("transform");
    const m = t && /translate\((-?[\d.]+) (-?[\d.]+)\)/.exec(t);
    if (m) return { x: Number(m[1]), z: Number(m[2]) };
    const b = el.getBBox();
    return { x: b.x + b.width / 2, z: b.y + b.height / 2 };
  }

  // ---- highlight, layers --------------------------------------------------------------------------------------
  function mark() {
    const svg = svgEl();
    if (!svg) return;
    svg.querySelectorAll(".is-sel").forEach((e) => e.classList.remove("is-sel"));
    if (selected) {
      svg.querySelector(`[id="${selected}"]`)?.classList.add("is-sel");
      svg.querySelectorAll(`[data-for="${selected}"]`).forEach((e) => e.classList.add("is-sel"));
    }
    svg.querySelectorAll(".is-quest").forEach((e) => e.classList.remove("is-quest"));
    if (layersOn.has("quests") && data) {
      for (const id of questTargets()) svg.querySelector(`[id="${id}"]`)?.classList.add("is-quest");
    }
    svg.querySelector(".m-pin")?.remove();
    if (pin && mapId) {
      const g = document.createElementNS("http://www.w3.org/2000/svg", "g");
      g.setAttribute("class", "mk m-pin");
      g.setAttribute("transform", `translate(${pin.x} ${pin.z})`);
      g.innerHTML = `<g class="k"><text class="m-pinglyph" y="-2">⚑</text></g>`;
      svg.appendChild(g);
    }
  }

  // cave with the gate of a boss chamber map (dungeon_<region>)
  function gateCaveOf(dungeon: string): string | null {
    if (!data) return null;
    const entry = Object.entries(data.caves).find(([, c]) => c.boss && `dungeon_${c.region}` === dungeon);
    return entry ? entry[0] : null;
  }

  function questTargets(): string[] {
    if (!data) return [];
    // eslint-disable-next-line svelte/prefer-svelte-reactivity -- local value, not reactive state
    const out = new Set<string>();
    for (const q of data.quests) {
      for (const p of q.places) {
        if (mapId === null) {
          const m = data.maps[p.map];
          const node = m?.kind === "cave" || m?.kind === "region" || m?.kind === "city" ? p.map : m?.kind === "dungeon" ? gateCaveOf(p.map) : null;
          if (node) out.add(`node-${node}`);
        } else if (p.map === mapId) {
          if (p.area) out.add(`area-${p.area}`);
          if (p.npc) out.add(`npc-${p.npc}`);
        } else if (p.cave && data.caves[p.cave]?.region === mapId) {
          out.add(`cave-${p.cave}`);
        }
      }
      if (mapId && data.npcs[q.giver]?.map === mapId) out.add(`npc-${q.giver}`);
    }
    return [...out];
  }

  function updateCounts() {
    const svg = svgEl();
    if (!svg) return;
    const n = (sel: string) => svg.querySelectorAll(sel).length;
    counts = {
      zones: mapId === null ? n(".m-glow") : 1,
      bosses: n(".m-boss, .m-elite, .m-elite2"),
      portals: n("#layer-portals .mk, #layer-caves .mk"),
      quests: questTargets().length,
      npcs: n("#layer-npcs .mk"),
      gather: n("#layer-gather > *"),
    };
  }

  function syncLayers() {
    const off = LAYERS.filter((l) => !layersOn.has(l) && l !== "gather");
    stage.dataset.off = off.join(" ");
    stage.dataset.on = layersOn.has("gather") ? "gather" : "";
    try {
      localStorage.setItem("vw-map-layers", [...layersOn].join(","));
    } catch {
      /* private mode */
    }
    mark();
  }

  function toggleLayer(l: Layer) {
    // eslint-disable-next-line svelte/prefer-svelte-reactivity -- local value, not reactive state
    const next = new Set(layersOn);
    if (next.has(l)) next.delete(l);
    else next.add(l);
    layersOn = next;
    syncLayers();
    updateCounts();
  }

  // ---- maps ---------------------------------------------------------------------------------------------------
  async function loadSvg(id: string): Promise<string> {
    const cached = svgCache.get(id);
    if (cached) return cached;
    const response = await fetch(`/img/maps/${id}.svg`);
    const text = await response.text();
    svgCache.set(id, text);
    return text;
  }
  function prefetch(id: string) {
    if (data?.maps[id]?.svg && !svgCache.has(id)) loadSvg(id).catch(() => undefined);
  }

  async function openMap(id: string | null, opts: { select?: string | null; x?: number; z?: number; s?: number; push?: boolean } = {}) {
    if (id && !data?.maps[id]?.svg) {
      const m = data?.maps[id];
      const cave = m?.kind === "dungeon" ? gateCaveOf(id) : null;
      if (cave) return openMap(cave, { select: `boss-${data!.caves[cave].boss}`, push: opts.push });
      return;
    }
    if (id !== mapId) {
      loading = true;
      const html = id ? await loadSvg(id) : worldHtml;
      pan.innerHTML = html;
      mapId = id;
      loading = false;
      setupPanzoom();
    }
    selected = opts.select ?? null;
    pin = id && opts.x !== undefined && opts.z !== undefined ? { x: opts.x, z: opts.z } : null;
    syncLayers();
    updateCounts();
    await tick();
    const target = pin ?? (selected ? elementCentre(selected) : null);
    if (target) centerOn(target.x, target.z, opts.s ?? (mapId ? 2.5 : 1.6), false);
    else if (opts.s && opts.s > 1) {
      const vb = viewBox();
      centerOn(vb.x + vb.w / 2, vb.y + vb.h / 2, opts.s, false);
    } else {
      fit(false);
    }
    if (selected && mobile) sheet = "peek";
    writeUrl(opts.push ?? false);
  }

  function select(id: string | null, center = false) {
    selected = id;
    pin = null;
    mark();
    if (mobile) sheet = id ? "peek" : sheet === "full" ? "full" : "closed";
    if (id && center) {
      const p = elementCentre(id);
      if (p) centerOn(p.x, p.z, Math.max(pz?.getScale() ?? 1, mapId ? 2 : 1.3));
    } else if (id && !mobile) {
      // keep the selection visible next to the panel
      const p = elementCentre(id);
      const c = content();
      const s = pz?.getScale() ?? 1;
      const t = pz?.getPan() ?? { x: 0, y: 0 };
      if (p) {
        const sx = c.W / 2 + s * (c.ox + (p.x - c.vb.x) * c.f - c.W / 2 + t.x);
        if (sx < 440) centerOn(p.x, p.z, s);
      }
    }
    writeUrl(false);
  }

  // ---- url ----------------------------------------------------------------------------------------------------
  function currentLink(): MapLink {
    const s = pz ? Math.round(pz.getScale() * 10) / 10 : 1;
    const a = sel && sel.type !== "group" ? sel.id : undefined;
    return { m: mapId ?? undefined, a, x: pin?.x, z: pin?.z, s: s > 1 ? s : undefined };
  }
  function writeUrl(push: boolean) {
    clearTimeout(urlTimer);
    const write = () => {
      const url = `${location.pathname}${serialize(currentLink())}`;
      if (url === `${location.pathname}${location.search}`) return;
      if (push) history.pushState(null, "", url);
      else history.replaceState(null, "", url);
    };
    if (push) write();
    else urlTimer = setTimeout(write, 250);
  }

  function resolveSelection(m: string | null, a: string | undefined): string | null {
    if (!a || !data) return null;
    if (m === null) return data.maps[a] && data.maps[a].kind !== "dungeon" ? `node-${a}` : data.bosses[a] ? `boss-${a}` : null;
    for (const prefix of ["area", "cave", "npc", "portal", "boss"]) {
      const id = `${prefix}-${a}`;
      if (svgCache.get(m)?.includes(`id="${id}"`)) return id;
    }
    return null;
  }

  async function applyLink(search: string, push = false) {
    if (!data) return;
    const sizes: Record<string, { x: number; z: number }> = {};
    for (const [id, m] of Object.entries(data.maps)) if (m.svg) sizes[id] = { x: m.size[0], z: m.size[1] };
    const link = parse(search, sizes);
    const m = link.m ?? null;
    if (m) await loadSvg(m).catch(() => undefined);
    await openMap(m, { select: resolveSelection(m, link.a), x: link.x, z: link.z, s: link.s, push });
  }

  // ---- search ---------------------------------------------------------------------------------------------------
  async function pick(r: (typeof results)[number]) {
    query = "";
    searchOpen = false;
    if (!data) return;
    if (r.kind === "map") return openMap(data.maps[r.id]?.svg ? r.id : null, { select: data.maps[r.id]?.svg ? null : `node-${r.id}`, push: true });
    if (r.kind === "cave") {
      const cave = data.caves[r.id];
      return openMap(cave ? cave.region : null, { select: cave ? `cave-${r.id}` : null, push: true });
    }
    const prefix = r.kind === "monster" ? "" : r.kind;
    const target = prefix ? `${prefix}-${r.id}` : null;
    await openMap(r.map, { select: target, x: r.kind === "monster" ? Math.round(r.x) : undefined, z: r.kind === "monster" ? Math.round(r.z) : undefined, push: true });
  }

  // ---- events ---------------------------------------------------------------------------------------------------
  let down: { x: number; y: number } | null = null;
  function onPointerDown(e: PointerEvent) {
    down = { x: e.clientX, y: e.clientY };
  }
  function onClick(e: MouseEvent) {
    if (down && Math.hypot(e.clientX - down.x, e.clientY - down.y) > 6) return;
    const el = (e.target as Element).closest<SVGElement>("[id][data-id]");
    if (!el) return select(null);
    if (el.id.startsWith("group-") && !el.classList.contains("m-elite") && !el.classList.contains("m-elite2")) return;
    select(el.id);
  }
  function onDblClick(e: MouseEvent) {
    const el = (e.target as Element).closest<SVGElement>("[id][data-id]");
    if (mapId === null && el?.id.startsWith("node-")) {
      e.preventDefault();
      e.stopPropagation();
      openMap(el.id.slice(5), { push: true });
    }
  }
  function onHover(e: PointerEvent) {
    const el = (e.target as Element).closest<SVGElement>("[data-target], [id^='node-']");
    const id = el?.dataset.target ?? (el?.id.startsWith("node-") ? el.id.slice(5) : undefined);
    if (id) prefetch(id);
  }
  function onKey(e: KeyboardEvent) {
    if (!pz || (e.target as Element).closest("input")) return;
    const step = 80;
    const s = pz.getScale();
    const p = pz.getPan();
    if (e.key === "+" || e.key === "=") pz.zoomIn();
    else if (e.key === "-") pz.zoomOut();
    else if (e.key === "0") fit();
    else if (e.key === "ArrowLeft") pz.pan(p.x + step / s, p.y);
    else if (e.key === "ArrowRight") pz.pan(p.x - step / s, p.y);
    else if (e.key === "ArrowUp") pz.pan(p.x, p.y + step / s);
    else if (e.key === "ArrowDown") pz.pan(p.x, p.y - step / s);
    else if (e.key === "Escape") return select(null);
    else return;
    e.preventDefault();
  }

  // bottom sheet drag
  let dragY: number | null = null;
  function sheetDown(e: PointerEvent) {
    dragY = e.clientY;
    (e.currentTarget as Element).setPointerCapture(e.pointerId);
  }
  function sheetUp(e: PointerEvent) {
    if (dragY === null) return;
    const dy = e.clientY - dragY;
    dragY = null;
    if (dy > 50) {
      if (sheet === "full") sheet = "peek";
      else {
        sheet = "closed";
        if (selected) select(null);
      }
    } else if (dy < -50) sheet = "full";
    else if (Math.abs(dy) < 6) sheet = sheet === "full" ? "peek" : "full";
  }

  async function copyLink() {
    const url = `${location.origin}${location.pathname}${serialize(currentLink())}`;
    try {
      await navigator.clipboard.writeText(url);
      copied = true;
      setTimeout(() => (copied = false), 1600);
    } catch {
      /* no clipboard */
    }
  }

  onMount(() => {
    stage = document.getElementById("vw-stage")!;
    pan = document.getElementById("vw-pan")!;
    worldHtml = pan.innerHTML;
    const mq = matchMedia("(max-width: 1023px)");
    mobile = mq.matches;
    ready = true;
    mq.addEventListener("change", () => (mobile = mq.matches));
    try {
      const saved = localStorage.getItem("vw-map-layers");
      if (saved !== null) layersOn = new Set(saved.split(",").filter((l): l is Layer => (LAYERS as string[]).includes(l)));
    } catch {
      /* private mode */
    }
    stage.classList.add("is-live");
    pan.addEventListener("panzoomchange", (e) => applyScale((e as CustomEvent).detail.scale));
    pan.addEventListener("panzoomend", () => writeUrl(false));
    stage.addEventListener("wheel", (e) => pz?.zoomWithWheel(e), { passive: false });
    stage.addEventListener("pointerdown", onPointerDown);
    stage.addEventListener("click", onClick);
    stage.addEventListener("dblclick", onDblClick, true);
    stage.addEventListener("pointerover", onHover);
    stage.addEventListener("keydown", onKey);
    const onResize = () => {
      lastScale = -1;
      applyScale(pz?.getScale() ?? 1);
    };
    addEventListener("resize", onResize);
    const onPop = () => applyLink(location.search);
    addEventListener("popstate", onPop);
    const onEsc = (e: KeyboardEvent) => {
      if (e.key === "Escape" && (sheet !== "closed" || selected)) {
        sheet = "closed";
        select(null);
      }
    };
    addEventListener("keydown", onEsc);
    Promise.all([import("@panzoom/panzoom"), fetch(`/${lang}/map-data.json`).then((r) => r.json())])
      .then(async ([module, d]: [{ default: typeof import("@panzoom/panzoom").default }, MapData]) => {
        Panzoom = module.default;
        setupPanzoom();
        data = d;
        await applyLink(location.search);
      })
      .catch(() => undefined);
    return () => {
      removeEventListener("resize", onResize);
      removeEventListener("popstate", onPop);
      removeEventListener("keydown", onEsc);
      pz?.destroy();
    };
  });

  // ---- view model of the card -----------------------------------------------------------------------------------
  const card = $derived.by(() => {
    if (!data || !sel) return null;
    const d = data;
    if (sel.type === "node") {
      const m = d.maps[sel.id];
      if (!m) return null;
      if (m.kind === "cave") return { kind: "cave" as const, id: sel.id, cave: d.caves[sel.id], map: m };
      return { kind: "map" as const, id: sel.id, map: m };
    }
    if (sel.type === "area" && d.areas[sel.id]) return { kind: "area" as const, id: sel.id, area: d.areas[sel.id] };
    if (sel.type === "cave" && d.caves[sel.id]) return { kind: "cave" as const, id: sel.id, cave: d.caves[sel.id], map: d.maps[sel.id] };
    if (sel.type === "portal" && d.portals[sel.id]) return { kind: "portal" as const, id: sel.id, portal: d.portals[sel.id] };
    if (sel.type === "npc" && d.npcs[sel.id]) return { kind: "npc" as const, id: sel.id, npc: d.npcs[sel.id] };
    if (sel.type === "boss" && d.bosses[sel.id]) return { kind: "boss" as const, id: sel.id, boss: d.bosses[sel.id] };
    return null;
  });
  const current = $derived(data && mapId ? data.maps[mapId] : null);
  const listItems = $derived.by(() => {
    if (!data) return [] as { id: string; name: string; line: string; sel: string; kind: string; zone: string }[];
    if (mapId && current) {
      const areas = Object.entries(data.areas)
        .filter(([, a]) => a.map === mapId)
        .sort((a, b) => a[1].min - b[1].min || a[1].max - b[1].max || (a[0] < b[0] ? -1 : 1))
        .map(([id, a]) => ({ id, name: a.name, line: levels(a.min, a.max), sel: `area-${id}`, kind: "area", zone: current.zone }));
      const caves = Object.entries(data.caves)
        .filter(([, c]) => c.region === mapId)
        .map(([id, c]) => ({ id, name: c.name, line: levels(c.min, c.max), sel: `cave-${id}`, kind: "cave", zone: "red" }));
      const people = Object.entries(data.npcs)
        .filter(([, n]) => n.map === mapId)
        .map(([id, n]) => ({ id, name: n.name, line: n.role, sel: `npc-${id}`, kind: "npc", zone: "" }));
      return [...areas, ...caves, ...people];
    }
    return data.order.map((id) => ({ id, name: data!.maps[id].name, line: levels(data!.maps[id].min, data!.maps[id].max), sel: `node-${id}`, kind: data!.maps[id].kind, zone: data!.maps[id].zone }));
  });
  const questList = $derived.by(() => {
    if (!data || !layersOn.has("quests")) return [];
    return data.quests.filter((q) => q.places.some((p) => (mapId ? p.map === mapId || (p.cave && data!.caves[p.cave]?.region === mapId) : true))).slice(0, 40);
  });
  const rankOf = (r: string) => data?.ranks[r] ?? r;
  const rankIndex: Record<string, number> = { normal: 0, elite: 1, elite2: 2 };
</script>

<!-- Overlay UI over the stage -->
<div class="ui" class:mobile class:ready class:has-card={!!card} data-pagefind-ignore>
  {#if mapId}
    <button type="button" class="back" onclick={() => openMap(null, { select: mapId ? `node-${data?.maps[mapId]?.region ?? mapId}` : null, push: true })}>‹ {L("map.world")}</button>
  {/if}

  <!-- search + layers (desktop: top right; mobile: chip row) -->
  <div class="top">
    <div class="search" class:open={searchOpen || !mobile}>
      {#if mobile && !searchOpen}
        <button type="button" class="chip icon" aria-label={L("map.search")} onclick={async () => { searchOpen = true; await tick(); document.getElementById("vw-map-q")?.focus(); }}>⌕</button>
      {:else}
        <input id="vw-map-q" type="search" placeholder={L("map.search")} aria-label={L("map.search")} bind:value={query} autocomplete="off"
          onkeydown={(e) => { if (e.key === "Enter" && results[0]) pick(results[0]); if (e.key === "Escape") { query = ""; searchOpen = false; } }} />
        {#if query.trim()}
          <ul class="results" role="listbox" aria-label={L("map.search")}>
            {#each results as r (r.kind + r.id)}
              <li><button type="button" onclick={() => pick(r)}><span class="rname">{r.texts[0]}</span><span class="rmeta">{L(`map.kind.${r.kind}`)} · {data?.maps[r.map]?.name ?? ""}</span></button></li>
            {:else}
              <li class="none">{L("map.searchNone")}</li>
            {/each}
          </ul>
        {/if}
      {/if}
    </div>
    {#if !(mobile && searchOpen)}
      <fieldset class="layers">
        <legend class="vw-label">{L("map.layers")}</legend>
        {#each LAYERS as l (l)}
          <button type="button" class="layer" aria-pressed={layersOn.has(l)} onclick={() => toggleLayer(l)}>
            <span class="box" aria-hidden="true"></span><span class="dia" style={`--c:${LAYER_COLOR[l]}`} aria-hidden="true"></span>
            <span class="lname">{L(`map.layer.${l}`)}</span><span class="count">{counts[l] ?? ""}</span>
          </button>
        {/each}
      </fieldset>
    {/if}
  </div>

  <!-- zoom -->
  <div class="zoom">
    <button type="button" aria-label={L("map.zoomIn")} onclick={() => pz?.zoomIn()}>+</button>
    <button type="button" aria-label={L("map.zoomOut")} onclick={() => pz?.zoomOut()}>−</button>
    <button type="button" class="fit" aria-label={L("map.fit")} onclick={() => fit()}>⤢</button>
  </div>

  {#if !mobile}
    <div class="legend">
      <p class="vw-label">{L("map.legend")}</p>
      <ul>
        {#if mapId === null}
          <li><span class="dia" style="--c:var(--vw-zone-green)"></span>{data?.zones.green?.name}</li>
          <li><span class="dia" style="--c:var(--vw-zone-yellow)"></span>{data?.zones.yellow?.name}</li>
          <li><span class="dia" style="--c:var(--vw-zone-red)"></span>{data?.zones.red?.name}</li>
          <li><span class="dia" style="--c:#e0503f"></span>{L("map.legend.boss")}</li>
        {:else}
          <li><span class="sq dash"></span>{L("map.kind.area")}</li>
          <li><span class="dia" style="--c:#e0503f"></span>{L("map.legend.cave")}</li>
          <li><span class="sq" style="--c:#4a8be8"></span>{L("map.legend.portal")}</li>
          <li><span class="dot" style="--c:#e8c25a"></span>{L("map.legend.npc")}</li>
          <li><span class="dot sm" style="--c:#f0ece2"></span>{L("map.legend.group")}</li>
          <li><span class="dia" style="--c:#e8c25a"></span>{L("map.legend.elite")}</li>
          {#if layersOn.has("quests")}<li><span class="sq" style="--c:transparent;border:2px solid #5fcf6b"></span>{L("map.legend.quest")}</li>{/if}
          {#if layersOn.has("gather")}<li><span class="dot" style="--c:#6fcf5a"></span>{L("map.legend.gather")}</li>{/if}
        {/if}
      </ul>
    </div>
  {/if}

  <!-- panel / bottom sheet -->
  <aside class="panel" class:sheet={mobile} data-state={mobile ? (card ? (sheet === "closed" ? "peek" : sheet) : sheet) : "open"}
    style={`--zc:var(--vw-zone-${card?.kind === "map" ? card.map.zone : card?.kind === "area" ? (current?.zone ?? "yellow") : card ? "red" : (current?.zone ?? "yellow")})`}
    aria-label={card ? undefined : L("map.list")}>
    {#if mobile}
      <div class="handle" role="button" tabindex="0" aria-label={L("map.listShort")} onpointerdown={sheetDown} onpointerup={sheetUp}
        onkeydown={(e) => { if (e.key === "Enter" || e.key === " ") sheet = sheet === "full" ? "peek" : "full"; }}><span></span></div>
    {/if}
    <div class="scroll">
      {#if loading}
        <p class="muted">{L("map.loading")}</p>
      {:else if card?.kind === "map"}
        {@const m = card.map}
        {#if m.svg}<img class="thumb" src={`/img/maps/${card.id}.svg`} alt="" loading="lazy" />{/if}
        <h2 class="title">{m.name}</h2>
        <div class="badges"><span class="vw-rank">{levels(m.min, m.max)}</span><span class={`vw-zone vw-zone--${m.zone}`}>{data?.zones[m.zone]?.name}</span></div>
        <p class="desc">{m.desc} <strong>{data?.zones[m.zone]?.rule}</strong></p>
        {#if m.mons.length}
          <p class="vw-label">{L("map.monsters", { n: m.mons.length })}</p>
          <ul class="rows">
            {#each m.mons.slice(0, 12) as [id, rank, min, max] (id + rank)}
              <li class={`r-${rank}`}><span class="dia"></span><span class="nm">{monsterName(id, rankIndex[rank])}</span><span class="lv">{levels(min, max)}</span><span class="rk">{rankOf(rank)}</span></li>
            {/each}
          </ul>
        {/if}
        <div class="actions">
          {#if m.svg && mapId !== card.id}<button type="button" class="vw-btn vw-btn--primary wide" onclick={() => openMap(card.id, { push: true })}>{L("map.show")}</button>{/if}
          {#if m.href}<a class="vw-btn" class:vw-btn--primary={mapId === card.id} href={m.href}>{L("map.openRegion")}</a>{/if}
          {#if data?.bestiary}<a class="vw-btn vw-btn--ghost" href={`${data.bestiary}?region=${card.id}`}>{L("map.bestiary")}</a>{/if}
        </div>
      {:else if card?.kind === "area"}
        {@const a = card.area}
        <h2 class="title">{a.name}</h2>
        <div class="badges">
          <span class="vw-rank">{levels(a.min, a.max)}</span>
          {#if current}<span class={`vw-zone vw-zone--${current.zone}`}>{data?.zones[current.zone]?.name}</span>{/if}
          {#if a.profile && data?.profiles[a.profile]}<span class="vw-rank" style={`color:${data.profiles[a.profile].color}`}>{data.profiles[a.profile].icon} {data.profiles[a.profile].name}</span>{/if}
        </div>
        <dl class="facts">
          <div><dt>{L("map.groups")}</dt><dd>{a.groups}</dd></div>
          <div><dt>{L("map.count")}</dt><dd>{a.count}</dd></div>
          <div><dt>{L("map.respawn")}</dt><dd>{respawn(a.respawn[0], a.respawn[1])}</dd></div>
        </dl>
        <p class="vw-label">{L("map.monsters", { n: a.mons.length })}</p>
        <ul class="rows">
          {#each a.mons as [id, min, max] (id)}
            <li class="r-normal"><span class="dia"></span><span class="nm">{monsterName(id)}</span><span class="lv">{levels(min, max)}</span><span class="rk">{rankOf("normal")}</span></li>
          {/each}
        </ul>
        {#if current}
          <p class="vw-label">{L("map.route")}</p>
          <p class="route">{#each current.route as r, i (r)}<span class="vw-chip">{data?.maps[r]?.name}</span>{#if i < current.route.length - 1}<span class="arrow">›</span>{/if}{/each}</p>
        {/if}
        <div class="actions">{#if a.href}<a class="vw-btn vw-btn--primary wide" href={a.href}>{L("map.openArea")}</a>{/if}</div>
      {:else if card?.kind === "cave"}
        {@const c = card.cave}
        <h2 class="title">{c?.name ?? card.map?.name}</h2>
        {#if c}
          <div class="badges"><span class="vw-rank">{levels(c.min, c.max)}</span><span class="vw-zone vw-zone--red">{data?.zones.red?.name}</span></div>
          <p class="desc">{card.map?.desc} <strong>{data?.zones.red?.rule}</strong></p>
          <p class="vw-label">{L("map.monsters", { n: c.normal.length + c.elites.length + c.elite2.length })}</p>
          <ul class="rows">
            {#each c.elite2 as id (id)}<li class="r-elite2"><span class="dia"></span><span class="nm">{monsterName(id, 2)}</span><span class="lv">{L("map.elite2one")}</span><span class="rk">{rankOf("elite2")}</span></li>{/each}
            {#each c.elites as id (id)}<li class="r-elite"><span class="dia"></span><span class="nm">{monsterName(id, 1)}</span><span class="lv"></span><span class="rk">{rankOf("elite")}</span></li>{/each}
            {#each c.normal as id (id)}<li class="r-normal"><span class="dia"></span><span class="nm">{monsterName(id)}</span><span class="lv"></span><span class="rk">{rankOf("normal")}</span></li>{/each}
          </ul>
          {#if c.ores.length}<p class="small"><span class="vw-label">{L("map.ores")}</span> {c.ores.join(", ")} · {c.oreCount}</p>{/if}
          {#if c.boss && data?.bosses[c.boss]}<p class="boss">☠ {data.bosses[c.boss].name} · {L("level", { level: data.bosses[c.boss].level })}</p>{/if}
          <div class="actions">
            {#if mapId !== card.id}<button type="button" class="vw-btn vw-btn--primary wide" onclick={() => openMap(card.id, { push: true })}>{mapId ? L("map.go") : L("map.show")}</button>{/if}
            {#if c.href}<a class="vw-btn" href={c.href}>{L("map.openCave")}</a>{/if}
          </div>
        {/if}
      {:else if card?.kind === "portal"}
        {@const p = card.portal}
        {@const target = data?.maps[p.target]}
        <p class="vw-label">{L(`map.kind.${p.kind}`)}</p>
        <h2 class="title">{target?.name}</h2>
        {#if target}<div class="badges"><span class="vw-rank">{levels(target.min, target.max)}</span><span class={`vw-zone vw-zone--${target.zone}`}>{data?.zones[target.zone]?.name}</span></div>
          <p class="desc">{target.desc}</p>{/if}
        <div class="actions">
          <button type="button" class="vw-btn vw-btn--primary wide" onclick={() => openMap(p.target, { push: true })}>{L("map.go")}</button>
          {#if target?.href}<a class="vw-btn" href={target.href}>{L("map.openRegion")}</a>{/if}
        </div>
      {:else if card?.kind === "npc"}
        {@const n = card.npc}
        <h2 class="title">{n.name}</h2>
        {#if n.role}<p class="desc">{n.role}</p>{/if}
        {#if n.services.length}<p class="vw-label">{L("map.services")}</p><p class="chips">{#each n.services as s (s)}<span class="vw-chip">{s}</span>{/each}</p>{/if}
        {#if n.quests.length}
          <p class="vw-label">{L("map.quests")}</p>
          <ul class="rows">{#each n.quests.slice(0, 10) as qid (qid)}{@const q = data?.quests.find((x) => x.id === qid)}{#if q}<li class="r-quest"><span class="dia"></span><a class="nm" href={q.href}>{q.title}</a><span class="lv">{L("level", { level: q.level })}</span></li>{/if}{/each}</ul>
        {/if}
      {:else if card?.kind === "boss"}
        {@const b = card.boss}
        <p class="vw-label">{rankOf("boss")}</p>
        <h2 class="title">{b.name}</h2>
        <div class="badges"><span class="vw-rank vw-rank--boss">{L("level", { level: b.level })}</span><span class="vw-zone vw-zone--red">{data?.zones.red?.name}</span></div>
        <div class="actions">
          <a class="vw-btn vw-btn--primary wide" href={b.href}>{L("map.openBoss")}</a>
          {#if mapId !== b.cave}<button type="button" class="vw-btn" onclick={() => openMap(b.cave, { select: `boss-${card.id}`, push: true })}>{L("map.show")}</button>{/if}
        </div>
      {:else}
        <h2 class="title sm">{current ? current.name : L("map.list")}</h2>
        {#if current}<p class="desc">{current.desc} <strong>{data?.zones[current.zone]?.rule}</strong></p>{/if}
        {#if questList.length}
          <p class="vw-label">{L("map.quests")}</p>
          <ul class="rows">{#each questList as q (q.id)}<li class="r-quest"><span class="dia"></span><a class="nm" href={q.href}>{q.title}</a><span class="lv">{L("level", { level: q.level })}</span></li>{/each}</ul>
        {/if}
        <ul class="list">
          {#each listItems as item (item.sel)}
            <li class={`k-${item.kind}`}>
              <button type="button" onclick={() => select(item.sel, true)} onpointerenter={() => prefetch(item.id)}>
                <span class="dia" style={`--c:var(--vw-zone-${item.zone || "yellow"})`}></span><span class="nm">{item.name}</span><span class="lv">{item.line}</span>
              </button>
            </li>
          {/each}
        </ul>
      {/if}
      {#if card}
        <div class="foot">
          <button type="button" class="vw-btn vw-btn--ghost" onclick={copyLink}>{copied ? L("map.copied") : L("map.copy")}</button>
          <button type="button" class="vw-btn vw-btn--ghost" onclick={() => select(null)}>{L("map.close")}</button>
        </div>
      {/if}
    </div>
  </aside>
</div>

<style>
  .ui { position: absolute; inset: 0; pointer-events: none; font-family: var(--vw-font-ui); }
  .ui > * { pointer-events: auto; }
  .back {
    position: absolute; left: 428px; top: 24px; z-index: 3; min-height: 44px; padding: 0 16px; font: 800 15px/1 var(--vw-font-ui);
    color: var(--vw-gold-bright); background: var(--vw-panel); border: 1px solid var(--vw-gold-dark); cursor: pointer;
  }
  .top { position: absolute; right: 24px; top: 24px; width: 260px; display: flex; flex-direction: column; gap: 10px; pointer-events: none; }
  .top > * { pointer-events: auto; }
  .search { position: relative; }
  .search input {
    width: 100%; height: 44px; padding: 0 12px; font: 500 15px/1 var(--vw-font-ui); color: var(--vw-text);
    background: var(--vw-bg); border: 1px solid var(--vw-border); box-shadow: var(--vw-well);
  }
  .search input:focus { outline: none; border-color: var(--vw-gold); box-shadow: var(--vw-well), var(--vw-focus); }
  .results { position: absolute; top: 48px; left: 0; right: 0; z-index: 5; margin: 0; padding: 4px 0; list-style: none; background: var(--vw-panel); border: 1px solid var(--vw-gold-dark); box-shadow: var(--vw-elev-3); max-height: 60vh; overflow: auto; }
  .results button { display: flex; flex-direction: column; gap: 2px; width: 100%; padding: 8px 12px; text-align: left; background: none; border: 0; color: var(--vw-text); cursor: pointer; min-height: 44px; }
  .results button:hover, .results button:focus-visible { background: var(--vw-panel-raised); }
  .rname { font-weight: 800; }
  .rmeta { font-size: 13px; color: var(--vw-text-muted); }
  .results .none { padding: 10px 12px; color: var(--vw-text-muted); }
  .layers { margin: 0; padding: 14px 16px; background: var(--vw-panel); border: 1px solid var(--vw-border); display: flex; flex-direction: column; gap: 2px; }
  .layers legend { float: left; width: 100%; margin-bottom: 8px; }
  .layer { display: grid; grid-template-columns: 18px 12px 1fr auto; align-items: center; gap: 10px; min-height: 40px; padding: 0; background: none; border: 0; color: var(--vw-text); font: 700 16px/1 var(--vw-font-ui); cursor: pointer; text-align: left; }
  .layer .box { width: 18px; height: 18px; border: 1.5px solid var(--vw-border); background: var(--vw-bg); }
  .layer[aria-pressed="true"] .box { background: var(--vw-gold-bright); border-color: var(--vw-gold-bright); box-shadow: inset 0 0 0 3px var(--vw-panel); }
  .layer[aria-pressed="false"] .lname { color: var(--vw-text-muted); }
  .count { font-size: 13px; color: var(--vw-text-muted); }
  .dia { width: 10px; height: 10px; transform: rotate(45deg); background: var(--c, #f0ece2); flex: none; }
  .zoom { position: absolute; right: 24px; bottom: 24px; display: flex; flex-direction: column; border: 1px solid var(--vw-border); background: var(--vw-panel); }
  .zoom button { width: 48px; height: 48px; font: 400 24px/1 var(--vw-font-ui); color: var(--vw-text); background: none; border: 0; border-bottom: 1px solid var(--vw-border); cursor: pointer; }
  .zoom button:last-child { border-bottom: 0; }
  .zoom button:hover { color: var(--vw-gold-bright); }
  .zoom .fit { font-size: 18px; }
  .legend { position: absolute; right: 90px; bottom: 24px; padding: 14px 16px; background: var(--vw-panel); border: 1px solid var(--vw-border); pointer-events: none; }
  .legend .vw-label { margin: 0 0 8px; }
  .legend ul { margin: 0; padding: 0; list-style: none; display: flex; flex-direction: column; gap: 8px; font-size: 14px; color: var(--vw-text-soft); }
  .legend li { display: flex; align-items: center; gap: 10px; }
  .sq { width: 10px; height: 10px; background: var(--c); }
  .sq.dash { background: none; border: 1.5px dashed var(--vw-text-soft); width: 12px; }
  .dot { width: 10px; height: 10px; border-radius: 50%; background: var(--c); }
  .dot.sm { width: 6px; height: 6px; margin: 0 2px; }

  .panel {
    position: absolute; left: 24px; top: 24px; bottom: 24px; width: 380px; z-index: 2; display: flex; flex-direction: column;
    background: var(--vw-panel); border: 1px solid var(--vw-border); border-top: 2px solid var(--zc); box-shadow: var(--vw-elev-3);
  }
  .scroll { flex: 1; overflow: auto; padding: 22px 22px 18px; display: flex; flex-direction: column; gap: 14px; overscroll-behavior: contain; }
  .thumb { width: 100%; height: 150px; object-fit: cover; border: 1px solid var(--vw-border); background: #15171c; }
  .title { margin: 0; font: 700 44px/1 var(--vw-font-display); color: var(--vw-text); overflow-wrap: anywhere; }
  .title.sm { font-size: 32px; }
  .badges { display: flex; flex-wrap: wrap; gap: 8px; }
  .desc { margin: 0; color: var(--vw-text-soft); line-height: 1.5; }
  .desc strong { color: var(--vw-text); }
  .muted { color: var(--vw-text-muted); }
  .small { margin: 0; font-size: 14px; color: var(--vw-text-soft); }
  .scroll :global(.vw-label) { margin: 6px 0 0; }
  .rows { margin: 0; padding: 0; list-style: none; }
  .rows li { display: grid; grid-template-columns: 12px minmax(0, 1fr) auto auto; gap: 12px; align-items: center; min-height: 40px; border-bottom: 1px solid var(--vw-border-subtle); }
  .rows .nm { font-weight: 800; color: var(--vw-text); }
  .rows a.nm:hover { color: var(--vw-gold-bright); }
  .rows .lv { font-size: 14px; color: var(--vw-text-muted); }
  .rows .rk { font: 800 14px/1 var(--vw-font-ui); color: var(--vw-text-soft); }
  .r-normal .dia { --c: #f0ece2; }
  .r-elite .dia { --c: #e8c25a; } .r-elite .rk { color: var(--vw-gold-bright); }
  .r-elite2 .dia { --c: #ff9f1c; } .r-elite2 .rk { color: #ff9f1c; }
  .r-quest .dia { --c: #5fcf6b; } .r-quest { grid-template-columns: 12px minmax(0, 1fr) auto !important; }
  .facts { margin: 0; display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; }
  .facts div { padding: 8px 10px; background: var(--vw-bg); border: 1px solid var(--vw-border-subtle); }
  .facts dt { font: 800 11px/1.3 var(--vw-font-ui); letter-spacing: .1em; text-transform: uppercase; color: var(--vw-gold); }
  .facts dd { margin: 4px 0 0; font-weight: 800; color: var(--vw-text); }
  .route, .chips { display: flex; flex-wrap: wrap; align-items: center; gap: 6px; margin: 0; }
  .arrow { color: var(--vw-gold); font-weight: 800; }
  .boss { margin: 0; color: var(--vw-zone-red-text); font-weight: 800; }
  .actions { display: flex; flex-wrap: wrap; gap: 10px; margin-top: auto; padding-top: 8px; }
  .actions .wide { flex: 1 1 60%; }
  .actions :global(.vw-btn) { min-height: 48px; justify-content: center; }
  .foot { display: flex; gap: 8px; justify-content: space-between; }
  .foot :global(.vw-btn) { min-height: 40px; font-size: 13px; }
  .list { margin: 0; padding: 0; list-style: none; }
  .list button { display: grid; grid-template-columns: 12px minmax(0, 1fr) auto; gap: 12px; align-items: center; width: 100%; min-height: 44px; padding: 0 4px; background: none; border: 0; border-bottom: 1px solid var(--vw-border-subtle); color: var(--vw-text); cursor: pointer; text-align: left; font: 700 16px/1.2 var(--vw-font-ui); }
  .list button:hover { background: var(--vw-panel-raised); }
  .list .k-cave button, .list .k-npc button { padding-left: 22px; font-weight: 500; }
  .list .k-region .nm, .list .k-city .nm { font: 700 20px/1.1 var(--vw-font-display); }
  .list .k-npc .dia { border-radius: 50%; transform: none; --c: #e8c25a !important; }
  .list .lv { font-size: 13px; color: var(--vw-text-muted); }

  .ui:not(.ready) { visibility: hidden; }
  /* mobile */
  .mobile .top { left: 0; right: 0; top: 0; width: auto; flex-direction: row; gap: 8px; padding: 8px 10px; overflow-x: auto; scrollbar-width: none; background: linear-gradient(var(--vw-bg), transparent); }
  .mobile .search.open { flex: 1; }
  .mobile .layers { flex-direction: row; padding: 0; background: none; border: 0; gap: 8px; }
  .mobile .layers legend { position: absolute; width: 1px; height: 1px; overflow: hidden; clip: rect(0 0 0 0); }
  .mobile .layer, .chip {
    grid-template-columns: 10px auto; min-height: 40px; padding: 0 12px; gap: 8px; white-space: nowrap; font-size: 14px;
    background: var(--vw-panel); border: 1px solid var(--vw-border);
  }
  .mobile .layer .box, .mobile .layer .count { display: none; }
  .mobile .layer[aria-pressed="true"] { border-color: var(--vw-gold); }
  .chip { display: inline-flex; align-items: center; color: var(--vw-text); cursor: pointer; font-size: 20px; min-width: 44px; justify-content: center; }
  .mobile .zoom { right: 10px; top: 60px; bottom: auto; }
  .mobile .zoom button { width: 44px; height: 44px; }
  .mobile .back { left: 10px; top: 60px; }
  .panel.sheet {
    left: 0; right: 0; top: auto; bottom: 0; width: auto; height: 85%; transform: translateY(100%); transition: transform var(--vw-dur-base, .2s) var(--vw-ease-out, ease-out);
    border-left: 0; border-right: 0; border-bottom: 0;
  }
  .panel.sheet[data-state="peek"] { transform: translateY(47%); }
  .panel.sheet[data-state="full"] { transform: translateY(0); }
  .panel.sheet[data-state="closed"] { transform: translateY(calc(100% - 44px)); }
  .handle { display: flex; justify-content: center; align-items: center; height: 44px; flex: none; cursor: grab; touch-action: none; }
  .handle span { width: 44px; height: 4px; background: var(--vw-border); }
  .sheet .scroll { padding-top: 0; }
  .sheet .title { font-size: 36px; }
  .sheet .rows li { min-height: 44px; }
  .sheet .thumb { display: none; }
  .sheet .actions .wide { flex-basis: 100%; }
  @media (prefers-reduced-motion: reduce) { .panel.sheet { transition: none; } }
</style>
