// Monster page behaviour (S39): variant tabs (arrows, ?v=), level chips swapping the stat cells from #monster-data,
// loot rows previewing their tooltip (hover / focus swap, click pins) and closed detail blocks on phones.
import { tabs } from "./tabs";

type Cells = Record<string, string | number | undefined>;

const page = document.querySelector<HTMLElement>("[data-monster]");
if (page) init(page);

function init(root: HTMLElement) {
  const data = JSON.parse(document.getElementById("monster-data")?.textContent ?? "{}") as Record<string, Cells[]>;
  const sections = [...root.querySelectorAll<HTMLElement>("[data-variant]")];
  const show = (v: string) => {
    for (const s of sections) s.toggleAttribute("data-active", s.dataset.variant === v);
    const url = new URL(location.href);
    if (v === sections[0]?.dataset.variant) url.searchParams.delete("v");
    else url.searchParams.set("v", v);
    history.replaceState(null, "", url);
    const glow = sections.find((s) => s.dataset.variant === v)?.style.getPropertyValue("--glow");
    if (glow) root.style.setProperty("--glow", glow);
  };
  const tablist = root.querySelector<HTMLElement>("[role=tablist]");
  if (tablist) {
    const wanted = new URLSearchParams(location.search).get("v");
    const select = tabs(tablist, (tab) => show(tab.dataset.tab ?? ""));
    const tab = tablist.querySelector<HTMLElement>(`[data-tab="${CSS.escape(wanted ?? "")}"]`);
    if (tab) select(tab);
  }

  if (matchMedia("(max-width: 767px)").matches) {
    for (const d of root.querySelectorAll<HTMLDetailsElement>("details.alllv, details.combat")) d.open = false;
  }

  for (const section of sections) {
    const cells = data[section.dataset.variant ?? ""] ?? [];
    const chips = [...section.querySelectorAll<HTMLButtonElement>("[data-level]")];
    for (const chip of chips) {
      chip.addEventListener("click", () => {
        const c = cells[Number(chip.dataset.level)];
        if (!c) return;
        for (const b of chips) b.setAttribute("aria-pressed", String(b === chip));
        for (const el of section.querySelectorAll<HTMLElement>("[data-cell]")) {
          const key = el.dataset.cell ?? "";
          if (key === "bar") {
            const bar = el.querySelector<HTMLElement>(".vw-bar");
            const label = `${c.hpText} / ${c.hpText}`;
            bar?.setAttribute("aria-valuenow", String(c.hp));
            bar?.setAttribute("aria-valuemax", String(c.hp));
            bar?.setAttribute("aria-label", label);
            const span = bar?.querySelector("span");
            if (span) span.textContent = label;
          } else if (c[key] !== undefined) {
            el.textContent = String(c[key]);
          }
        }
      });
    }

    const rows = [...section.querySelectorAll<HTMLElement>("tr[data-row]")];
    const tips = [...section.querySelectorAll<HTMLElement>("[data-tip]")];
    let pinned = rows.find((r) => r.getAttribute("aria-selected") === "true") ?? null;
    const preview = (row: HTMLElement) => {
      for (const t of tips) t.hidden = t.dataset.tip !== row.dataset.row;
      for (const r of rows) r.setAttribute("aria-selected", String(r === row));
    };
    for (const row of rows) {
      row.addEventListener("mouseenter", () => preview(row));
      row.addEventListener("focus", () => preview(row));
      row.addEventListener("mouseleave", () => pinned && preview(pinned));
      row.addEventListener("click", (ev) => {
        if ((ev.target as Element).closest("a")) return;
        pinned = row;
        preview(row);
      });
      row.addEventListener("keydown", (ev) => {
        if (ev.key === "Enter" || ev.key === " ") {
          if ((ev.target as Element).closest("a, summary")) return;
          ev.preventDefault();
          pinned = row;
          preview(row);
        }
      });
    }
  }
}
