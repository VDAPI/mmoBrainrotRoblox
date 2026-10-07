// Bestiary page behaviour (S39): filters, search, sort, cards / table and paging over the statically rendered entries
// (data-* attributes), with the state in the URL (replaceState; popstate restores it). Never imports the data JSON;
// the page passes its labels in #bestiary-config.
import {
  DEFAULT_FILTERS,
  isFiltered,
  matches,
  nextSort,
  parseFilters,
  serializeFilters,
  sortEntries,
  type FilterEntry,
  type Filters,
  type Rank,
  type Sort,
} from "../lib/bestiary-filters";
import { pluralForm } from "../lib/format";

interface Config {
  lang: "pl" | "en";
  perPage: number;
  perPageMobile: number;
  regions: Record<string, string>;
  bands: [number, number][];
  ranks: Record<string, string>;
  text: Record<"one" | "few" | "many" | "range" | "more" | "remove" | "prev" | "next" | "page", string> & { sort: Record<Sort, string> };
}

interface Row extends FilterEntry {
  card: HTMLElement;
  row: HTMLElement | null;
}

const root = document.querySelector<HTMLElement>("[data-bestiary]");
const configEl = document.getElementById("bestiary-config");
if (root && configEl) init(root, JSON.parse(configEl.textContent ?? "{}") as Config);

function fill(text: string, args: Record<string, string | number>): string {
  return text.replace(/\{(\w+)\}/g, (w, k: string) => (k in args ? String(args[k]) : w));
}

function init(page: HTMLElement, cfg: Config) {
  const $ = <T extends Element = HTMLElement>(sel: string) => page.querySelector<T>(sel);
  const $$ = <T extends Element = HTMLElement>(sel: string) => [...page.querySelectorAll<T>(sel)];
  const grid = $("[data-list=cards]")!;
  const table = $<HTMLTableElement>("[data-list=table]")!;
  const tbody = table.tBodies[0];
  const rows = new Map($$("tr[data-entry]").map((tr) => [tr.dataset.order, tr]));
  const all: Row[] = $$("li[data-entry]").map((li) => ({
    rank: li.dataset.rank as Rank,
    levelMin: Number(li.dataset.min),
    levelMax: Number(li.dataset.max),
    places: (li.dataset.places ?? "").split(" ").filter(Boolean),
    regions: (li.dataset.regions ?? "").split(" ").filter(Boolean),
    key: li.dataset.key ?? "",
    name: li.dataset.name ?? "",
    order: Number(li.dataset.order),
    card: li,
    row: rows.get(li.dataset.order) ?? null,
  }));
  const known = { regions: Object.keys(cfg.regions), bands: cfg.bands };
  const mobile = matchMedia("(max-width: 1023px)");
  const q = $<HTMLInputElement>("[data-q]")!;
  let state: Filters = read();

  function read(): Filters {
    const f = parseFilters(location.search, known);
    if (!new URLSearchParams(location.search).has("view")) {
      try {
        if (localStorage.getItem("vw-bestiary-view") === "table") f.view = "table";
      } catch {
        /* storage blocked */
      }
    }
    return f;
  }

  function set(patch: Partial<Filters>, keepPage = false) {
    state = { ...state, ...patch, page: keepPage ? (patch.page ?? state.page) : 1 };
    render();
  }

  function render() {
    const found = sortEntries(all.filter((e) => matches(e, state)), state.sort, cfg.lang);
    const shown = new Set<Row>();
    const per = mobile.matches ? cfg.perPageMobile : cfg.perPage;
    const pages = Math.max(1, Math.ceil(found.length / per));
    const pageNo = Math.min(state.page, pages);
    const from = mobile.matches ? 0 : (pageNo - 1) * per;
    const to = Math.min(found.length, mobile.matches ? pageNo * per : from + per);
    found.slice(from, to).forEach((e) => shown.add(e));
    for (const e of found) {
      grid.append(e.card);
      if (e.row) tbody.append(e.row);
    }
    for (const e of all) {
      e.card.hidden = !shown.has(e);
      if (e.row) e.row.hidden = !shown.has(e);
    }
    const tableView = state.view === "table" && !mobile.matches;
    grid.hidden = tableView || found.length === 0;
    table.hidden = !tableView || found.length === 0;
    $("[data-empty]")!.hidden = found.length > 0;
    $("[data-count]")!.textContent = `${found.length} ${cfg.text[pluralForm(found.length, cfg.lang)]}`;
    $("[data-range]")!.textContent = found.length ? fill(cfg.text.range, { from: from + 1, to, total: found.length }) : "";
    const more = $<HTMLButtonElement>("[data-more]")!;
    more.hidden = !mobile.matches || to >= found.length;
    more.textContent = fill(cfg.text.more, { n: Math.min(per, found.length - to) });
    pager(pageNo, mobile.matches ? 1 : pages);
    controls();
    const url = `${location.pathname}${serializeFilters({ ...state, page: pageNo })}${location.hash}`;
    if (url !== `${location.pathname}${location.search}${location.hash}`) history.replaceState(null, "", url);
  }

  function pager(current: number, pages: number) {
    const nav = $("[data-pager]")!;
    nav.replaceChildren();
    if (pages <= 1) return;
    const button = (label: string, page: number, opts: { aria?: string; current?: boolean; disabled?: boolean } = {}) => {
      const b = document.createElement("button");
      b.type = "button";
      b.className = `vw-btn${opts.current ? " vw-btn--primary" : ""}`;
      b.textContent = label;
      b.disabled = !!opts.disabled;
      b.setAttribute("aria-label", opts.aria ?? fill(cfg.text.page, { n: page }));
      if (opts.current) b.setAttribute("aria-current", "page");
      b.addEventListener("click", () => {
        set({ page }, true);
        grid.parentElement?.scrollIntoView({ block: "start" });
      });
      nav.append(b);
    };
    button("‹", current - 1, { aria: cfg.text.prev, disabled: current === 1 });
    for (let n = 1; n <= pages; n++) {
      if (pages > 7 && n !== 1 && n !== pages && Math.abs(n - current) > 1) {
        if (n === 2 || n === pages - 1) nav.append(Object.assign(document.createElement("span"), { textContent: "…", className: "gap" }));
        continue;
      }
      button(String(n), n, { current: n === current });
    }
    button("›", current + 1, { aria: cfg.text.next, disabled: current === pages });
  }

  function controls() {
    for (const b of $$("[data-region]")) {
      const on = (b.dataset.region || null) === state.region;
      b.setAttribute("aria-pressed", String(on));
      // phones: the region row scrolls sideways; keep the chosen region in view
      if (on && mobile.matches && b.parentElement) b.parentElement.scrollLeft = Math.max(0, b.offsetLeft - b.parentElement.offsetLeft - 16);
    }
    const lv = state.lv ? `${state.lv[0]}-${state.lv[1]}` : "";
    for (const b of $$("[data-lv]")) b.setAttribute("aria-pressed", String(b.dataset.lv === lv));
    for (const c of $$<HTMLInputElement>("[data-type]")) c.checked = state.types.includes(c.value as Rank);
    for (const b of $$("[data-view]")) b.setAttribute("aria-pressed", String(b.dataset.view === state.view));
    $("[data-sort-label]")!.textContent = cfg.text.sort[state.sort];
    if (document.activeElement !== q) q.value = state.q;
    const chips: [string, Partial<Filters>][] = [];
    if (state.region) chips.push([cfg.regions[state.region] ?? state.region, { region: null }]);
    if (state.lv) chips.push([`${state.lv[0]}–${state.lv[1]}`, { lv: null }]);
    for (const r of state.types) chips.push([cfg.ranks[r] ?? r, { types: state.types.filter((x) => x !== r) }]);
    if (state.q.trim()) chips.push([`„${state.q.trim()}”`, { q: "" }]);
    const box = $("[data-active-chips]")!;
    box.replaceChildren(
      ...chips.map(([label, patch]) => {
        const b = document.createElement("button");
        b.type = "button";
        b.className = "vw-chip";
        b.textContent = `${label} ×`;
        b.setAttribute("aria-label", fill(cfg.text.remove, { label }));
        b.addEventListener("click", () => set(patch));
        return b;
      }),
    );
    $("[data-active]")!.hidden = !isFiltered(state);
  }

  for (const b of $$("[data-region]")) b.addEventListener("click", () => set({ region: b.dataset.region || null }));
  for (const b of $$("[data-lv]")) {
    b.addEventListener("click", () => {
      const m = /^(\d+)-(\d+)$/.exec(b.dataset.lv ?? "");
      set({ lv: m ? [Number(m[1]), Number(m[2])] : null });
    });
  }
  for (const c of $$<HTMLInputElement>("[data-type]")) {
    c.addEventListener("change", () => set({ types: $$<HTMLInputElement>("[data-type]").filter((x) => x.checked).map((x) => x.value as Rank) }));
  }
  let timer = 0;
  q.addEventListener("input", () => {
    clearTimeout(timer);
    timer = window.setTimeout(() => set({ q: q.value }), 150);
  });
  $("[data-sort]")!.addEventListener("click", () => set({ sort: nextSort(state.sort) }));
  for (const b of $$("[data-view]")) {
    b.addEventListener("click", () => {
      const view = b.dataset.view === "table" ? "table" : "cards";
      try {
        localStorage.setItem("vw-bestiary-view", view);
      } catch {
        /* storage blocked */
      }
      set({ view }, true);
    });
  }
  for (const b of $$("[data-clear]")) b.addEventListener("click", () => set({ ...DEFAULT_FILTERS, types: [], sort: state.sort, view: state.view }));
  $("[data-more]")!.addEventListener("click", () => set({ page: state.page + 1 }, true));
  tbody.addEventListener("click", (ev) => {
    const tr = (ev.target as Element).closest<HTMLElement>("tr[data-href]");
    if (tr && !(ev.target as Element).closest("a") && tr.dataset.href) location.href = tr.dataset.href;
  });
  mobile.addEventListener("change", render);
  addEventListener("popstate", () => {
    state = read();
    render();
  });
  render();
}
